#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  if (!requireNamespace("pacman", quietly = TRUE)) install.packages("pacman")
  pacman::p_load(optparse, jsonlite, ggplot2)
})

option_list <- list(
  optparse::make_option("--data", type = "character"),
  optparse::make_option("--config", type = "character", help = "Path to analysis_config.json (Pass 0)"),
  optparse::make_option("--question-config", type = "character", help = "Path to question config CSV"),
  optparse::make_option("--out", type = "character", default = "./skill_out/questionnaire"),
  optparse::make_option("--run-id", type = "character", default = "run")
)
opt <- optparse::parse_args(optparse::OptionParser(option_list = option_list))

# JSON 設定の読み込み (Pass 0 連携用)
if (!is.null(opt$config) && file.exists(opt$config)) {
  message("[INFO] 共通設定ファイルを読み込み中: ", opt$config)
  cfg_json <- jsonlite::fromJSON(opt$config)
  if (!is.null(cfg_json$input)) opt$data <- cfg_json$input
  if (!is.null(cfg_json$question_config)) opt$`question-config` <- cfg_json$question_config
  if (!is.null(cfg_json$output_dir)) opt$out <- cfg_json$output_dir
  if (!is.null(cfg_json$run_id)) opt$`run-id` <- cfg_json$run_id
}

stopifnot(!is.null(opt$data), file.exists(opt$data))
stopifnot(!is.null(opt$`question-config`), file.exists(opt$`question-config`))

base_out <- opt$out
dir.create(base_out, recursive = TRUE, showWarnings = FALSE)

rid <- trimws(as.character(opt$`run-id`))
if (tolower(rid) == "auto") {
  rid <- format(Sys.time(), "%Y%m%d_%H%M%S", tz = "Asia/Tokyo")
} else {
  rid <- gsub("[/\\\\]", "_", rid)
  rid <- gsub("^\\.+|\\.+$", "", rid)
}
# summary.csv の run_id は out_dir の runs/<id>/ と一致させる（auto やサニタイズ後の値）
run_id_record <- rid
out_dir <- base_out
if (nzchar(rid) && rid != "run") {
  out_dir <- file.path(base_out, "runs", rid)
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  message("[INFO] --run-id により出力先: ", out_dir)
}

detect_jp_font <- function() {
  os <- Sys.info()[["sysname"]]
  candidates <- switch(os,
    "Darwin"  = c("Hiragino Sans", "HiraginoSans-W3", "Hiragino Kaku Gothic Pro"),
    "Windows" = c("Yu Gothic", "Meiryo", "MS Gothic"),
    "Linux"   = c("Noto Sans CJK JP", "IPAexGothic", "IPAGothic"),
    character(0)
  )
  if (requireNamespace("systemfonts", quietly = TRUE)) {
    avail <- unique(systemfonts::system_fonts()$family)
    for (f in candidates) {
      if (f %in% avail) {
        return(f)
      }
    }
  }
  if (length(candidates) > 0L) {
    return(candidates[1L])
  }
  ""
}

cramer_v_2way <- function(tab) {
  tab <- as.matrix(tab)
  if (length(dim(tab)) != 2L) {
    return(NA_real_)
  }
  n <- sum(tab)
  if (!is.finite(n) || n <= 0) {
    return(NA_real_)
  }
  suppressWarnings({
    ct <- chisq.test(tab, correct = FALSE)
  })
  chi2 <- as.numeric(ct$statistic)
  r <- nrow(tab)
  c <- ncol(tab)
  df_star <- min(r - 1L, c - 1L)
  if (df_star <= 0) {
    return(NA_real_)
  }
  v <- sqrt(chi2 / (n * df_star))
  v
}

MARGINAL_STRATA_DELTA <- 0.05

effect_label <- function(v) {
  if (!is.finite(v)) {
    return(NA_character_)
  }
  if (v < 0.1) {
    return("small")
  }
  if (v < 0.3) {
    return("medium")
  }
  if (v < 0.5) {
    return("large")
  }
  "very_large"
}

max_residual_cell <- function(tab, dimnames_list) {
  suppressWarnings({
    ct <- chisq.test(tab, correct = FALSE)
  })
  r <- ct$residuals
  idx <- which(abs(r) == max(abs(r), na.rm = TRUE), arr.ind = TRUE)[1L, ]
  rn <- rownames(r)[idx[1]]
  cn <- colnames(r)[idx[2]]
  paste(rn, cn, sep = ":")
}

make_residual_plot <- function(residual_vec, out_path, jp_font) {
  plot_df <- data.frame(
    idx = seq_along(residual_vec),
    res = as.numeric(residual_vec)
  )
  plot_df$idx_f <- factor(plot_df$idx, levels = plot_df$idx)
  p <- ggplot2::ggplot(plot_df, ggplot2::aes(idx_f, res)) +
    ggplot2::geom_hline(yintercept = c(-1.96, 0, 1.96), linetype = c("dashed", "solid", "dashed"), linewidth = 0.3) +
    ggplot2::geom_point(size = 1.8) +
    ggplot2::labs(x = "Index (cell order)", y = "Pearson residuals vs index") +
    ggplot2::theme_minimal(base_size = 13, base_family = jp_font)
  ggplot2::ggsave(out_path, plot = p, width = 7, height = 4, dpi = 72)
}

df <- utils::read.csv(opt$data, stringsAsFactors = FALSE, na.strings = c("", "NA"))
cfg <- utils::read.csv(opt$`question-config`, stringsAsFactors = FALSE, na.strings = c("", "NA"))

sanitize_cfg_var <- function(x) {
  if (length(x) != 1L) {
    return("")
  }
  if (is.na(x)) {
    return("")
  }
  s <- trimws(as.character(x))
  if (!nzchar(s)) {
    return("")
  }
  s
}

required_cols <- c("survey_id", "question_id", "analysis_type", "var1", "var2", "var3", "output_slug", "question_label", "subset_expr", "na_policy", "ordered_levels", "reference_note")
stopifnot(all(required_cols %in% names(cfg)))

# 同一実行内で output_slug が重複すると、後の行が先の行の report.html /
# questionnaire_results.json / figures/residual_plot.png を無言で上書きし、
# 成果物が失われる。重複は設定ミスとみなして明示的に停止する。
slugs <- trimws(as.character(cfg$output_slug))
dup_slugs <- unique(slugs[duplicated(slugs)])
if (length(dup_slugs) > 0L) {
  stop(
    "output_slug が重複しています（成果物が上書きされます）: ",
    paste(dup_slugs, collapse = ", "),
    "。各設問に一意な output_slug を設定してください。"
  )
}

jp_font <- detect_jp_font()
if (!nzchar(jp_font)) jp_font <- ""

rows <- list()

for (i in seq_len(nrow(cfg))) {
  row <- cfg[i, , drop = FALSE]
  survey_id <- as.character(row$survey_id)
  question_id <- as.character(row$question_id)
  analysis_type <- as.character(row$analysis_type)
  var1 <- sanitize_cfg_var(row$var1)
  var2 <- sanitize_cfg_var(row$var2)
  var3 <- sanitize_cfg_var(row$var3)
  output_slug <- as.character(row$output_slug)
  subset_expr <- if (is.na(row$subset_expr)) "" else trimws(as.character(row$subset_expr))
  na_policy <- as.character(row$na_policy)

  status <- "pending"
  error_message <- NA_character_
  skip_reason <- NA_character_

  q_df <- df
  if (isTRUE(nzchar(subset_expr))) {
    keep <- tryCatch(with(q_df, eval(parse(text = subset_expr))), error = function(e) rep(TRUE, nrow(q_df)))
    if (length(keep) == nrow(q_df) && is.logical(keep)) {
      q_df <- q_df[!is.na(keep) & keep, , drop = FALSE]
    }
  }

  vars <- c(var1, var2)
  if (isTRUE(nzchar(var3))) vars <- c(vars, var3)

  missing_vars <- setdiff(vars, names(q_df))
  if (length(missing_vars) > 0L) {
    stop("Variables not found in data: ", paste(missing_vars, collapse = ", "))
  }

  q_df <- q_df[, vars, drop = FALSE]
  n_total <- nrow(q_df)
  if (identical(na_policy, "drop")) {
    q_df <- q_df[stats::complete.cases(q_df), , drop = FALSE]
  }
  n_used <- nrow(q_df)
  n_missing <- n_total - n_used

  q_out <- file.path(out_dir, output_slug)
  fig_dir <- file.path(q_out, "figures")
  dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)

  status <- "success"
  skip_reason <- ""
  error_message <- ""

  statistic_value <- NA_real_
  p_value <- NA_real_
  effect_value <- NA_real_
  cramer_v_marginal <- NA_real_
  cramer_v_df_star <- NA_real_
  cramer_v_effect_label <- NA_character_
  cramer_v_strata_json <- NA_character_
  cramer_v_strata_mean <- NA_real_
  cramer_v_strata_max <- NA_real_
  cramer_v_strata_max_level <- NA_character_
  marginal_strata_signal <- "none"
  marginal_strata_note <- ""
  max_abs_pearson_res <- NA_real_
  max_residual_cell_val <- NA_character_
  mosaic_rendered <- FALSE
  assoc_rendered <- FALSE
  residual_plot_mode <- "dotplot"

  report_path <- file.path(q_out, "report.html")
  plot_path <- file.path(fig_dir, "residual_plot.png")

  tryCatch(
    {
      if (n_used <= 1L) stop("Not enough rows after filtering.")

      if (analysis_type %in% c("nominal_2way", "likert_2way")) {
        tab <- table(q_df[[var1]], q_df[[var2]])
        ct <- suppressWarnings(chisq.test(tab, correct = FALSE))
        statistic_value <- as.numeric(ct$statistic)
        p_value <- as.numeric(ct$p.value)

        r <- nrow(tab)
        c <- ncol(tab)
        cramer_v_df_star <- min(r - 1L, c - 1L)
        cramer_v_marginal <- cramer_v_2way(tab)
        effect_value <- cramer_v_marginal
        cramer_v_effect_label <- effect_label(cramer_v_marginal)

        max_abs_pearson_res <- max(abs(ct$residuals), na.rm = TRUE)
        max_residual_cell_val <- max_residual_cell(tab)

        n_cells <- prod(dim(tab))
        mosaic_rendered <- isTRUE(n_cells <= 16L)
        assoc_rendered <- isTRUE(n_cells <= 16L)

        make_residual_plot(as.numeric(ct$residuals), plot_path, jp_font)
      } else if (analysis_type == "nominal_3way") {
        tab3 <- table(q_df[[var1]], q_df[[var2]], q_df[[var3]])
        tab_m <- margin.table(tab3, c(1L, 2L))
        ct <- suppressWarnings(chisq.test(tab_m, correct = FALSE))
        statistic_value <- as.numeric(ct$statistic)
        p_value <- as.numeric(ct$p.value)

        r <- nrow(tab_m)
        c <- ncol(tab_m)
        cramer_v_df_star <- min(r - 1L, c - 1L)
        cramer_v_marginal <- cramer_v_2way(tab_m)
        effect_value <- cramer_v_marginal
        cramer_v_effect_label <- effect_label(cramer_v_marginal)

        max_abs_pearson_res <- max(abs(ct$residuals), na.rm = TRUE)
        max_residual_cell_val <- max_residual_cell(tab_m)

        strata_levels <- dimnames(tab3)[[3]]
        strata_v <- setNames(rep(NA_real_, length(strata_levels)), strata_levels)
        for (lv in strata_levels) {
          tab_s <- tab3[, , lv, drop = TRUE]
          strata_v[[lv]] <- cramer_v_2way(tab_s)
        }
        cramer_v_strata_json <- jsonlite::toJSON(as.list(strata_v), auto_unbox = TRUE)
        cramer_v_strata_mean <- mean(strata_v, na.rm = TRUE)
        cramer_v_strata_max <- max(strata_v, na.rm = TRUE)
        if (is.finite(cramer_v_strata_max)) {
          cramer_v_strata_max_level <- names(which.max(strata_v))[1L]
        }

        ddiff <- abs(cramer_v_marginal - cramer_v_strata_mean)
        if (!is.finite(ddiff) || !any(is.finite(strata_v))) {
          marginal_strata_note <- "insufficient_strata_or_na"
        } else if (ddiff >= MARGINAL_STRATA_DELTA) {
          marginal_strata_signal <- "review_stratified"
          marginal_strata_note <- sprintf(
            "|V_marginal - mean(V_strata)|=%.4f >= %.2f",
            ddiff, MARGINAL_STRATA_DELTA
          )
        } else {
          marginal_strata_note <- "within_threshold"
        }

        n_cells <- prod(dim(tab3))
        mosaic_rendered <- isTRUE(n_cells <= 36L)
        assoc_rendered <- isTRUE(n_cells <= 36L)

        make_residual_plot(as.numeric(ct$residuals), plot_path, jp_font)
      } else {
        stop("Unsupported analysis_type: ", analysis_type)
      }

      # 統計結果の JSON 保存
      results_json <- list(
        survey_id = survey_id,
        question_id = question_id,
        analysis_type = analysis_type,
        n_total = n_total,
        n_used = n_used,
        statistic = list(
          method = "chisq",
          value = statistic_value,
          p_value = p_value
        ),
        residuals = list(
          max_abs = max_abs_pearson_res,
          max_cell = max_residual_cell_val
        ),
        plots = list(
          mosaic_rendered = mosaic_rendered,
          assoc_rendered = assoc_rendered
        )
      )
      jsonlite::write_json(results_json, file.path(q_out, "questionnaire_results.json"), auto_unbox = TRUE, pretty = TRUE)

      html <- c(
        "<!doctype html>",
        "<html><head><meta charset=\"utf-8\"><title>Report</title></head><body>",
        sprintf("<h1>%s</h1>", ifelse(is.na(row$question_label), "Report", row$question_label)),
        "<h2>Residual plot</h2>",
        "<p>Pearson residuals vs index</p>",
        "<img src=\"figures/residual_plot.png\" alt=\"residual plot\">",
        "</body></html>"
      )
      writeLines(html, report_path, useBytes = TRUE)
      status <- "success"
    },
    error = function(e) {
      status <- "error"
      error_message <- conditionMessage(e)
      skip_reason <- conditionMessage(e)
    }
  )

  rows[[length(rows) + 1L]] <- data.frame(
    run_id = run_id_record,
    survey_id = survey_id,
    question_id = question_id,
    analysis_type = analysis_type,
    n_total = n_total,
    n_used = n_used,
    n_missing = n_missing,
    model_name = "chisq",
    statistic_value = statistic_value,
    p_value = p_value,
    effect_value = effect_value,
    cramer_v_marginal = cramer_v_marginal,
    cramer_v_df_star = cramer_v_df_star,
    cramer_v_effect_label = cramer_v_effect_label,
    cramer_v_strata_json = cramer_v_strata_json,
    cramer_v_strata_mean = cramer_v_strata_mean,
    cramer_v_strata_max = cramer_v_strata_max,
    cramer_v_strata_max_level = cramer_v_strata_max_level,
    marginal_strata_signal = marginal_strata_signal,
    marginal_strata_note = marginal_strata_note,
    max_abs_pearson_res = max_abs_pearson_res,
    max_residual_cell = max_residual_cell_val,
    mosaic_rendered = mosaic_rendered,
    assoc_rendered = assoc_rendered,
    skip_reason = skip_reason,
    residual_plot_mode = residual_plot_mode,
    report_path = report_path,
    status = ifelse(status == "success", "success", "error"),
    error_message = ifelse(status == "success", "", error_message),
    stringsAsFactors = FALSE
  )
}

summary_df <- do.call(rbind, rows)
summary_path <- file.path(out_dir, "summary.csv")
utils::write.csv(summary_df, summary_path, row.names = FALSE, na = "")
quit(status = 0L)
