# VCD Categorical Analysis Pipeline (v2.1)
# 2-pass mode: --profile (Pass 1) or --render --config <path> (Pass 2)
# Outputs under ./skill_out/vcd_categorical/

# --- Packages ---
if (!base::requireNamespace("pacman", quietly = TRUE)) utils::install.packages("pacman", repos = "https://cloud.r-project.org")
pacman::p_load(vcd, gt, DT, htmlwidgets, ggplot2, jsonlite)

# run_scope.R の読み込み
find_agent_repo <- function() {
  d <- base::normalizePath(base::getwd(), winslash = "/", mustWork = FALSE)
  for (i in base::seq_len(20L)) {
    p <- base::file.path(d, ".agent", "shared", "run_scope.R")
    if (base::file.exists(p)) {
      return(d)
    }
    parent <- base::dirname(d)
    if (parent == d) break
    d <- parent
  }
  base::getwd()
}
base::source(base::file.path(find_agent_repo(), ".agent", "shared", "run_scope.R"))

args <- base::commandArgs(trailingOnly = TRUE)
mode <- if ("--profile" %in% args) "profile" else "render"

# Extract argument value helper
get_arg_val <- function(arg_name, default = NULL) {
  if (arg_name %in% args) {
    idx <- base::which(args == arg_name)
    if (idx < base::length(args)) {
      return(args[idx + 1])
    }
  }
  return(default)
}

config_path <- get_arg_val("--config")

# デフォルト値の設定
data_path <- NULL
vars_arg <- "Hair,Eye,Sex"
freq_col <- "Freq"
data_label <- "data"
output_dir <- "./skill_out/vcd_categorical/"
run_id_raw <- get_arg_val("--run-id")

# JSON 設定の読み込み (Pass 0 連携用)
if (!base::is.null(config_path) && base::file.exists(config_path)) {
  base::message("[INFO] 設定ファイルを読み込み中: ", config_path)
  config_data <- jsonlite::fromJSON(config_path)

  # マッピング: JSONキー -> スクリプト内部変数/引数名
  if (!base::is.null(config_data$input)) data_path <- config_data$input
  if (!base::is.null(config_data$vars)) vars_arg <- base::paste(config_data$vars, collapse = ",")
  if (!base::is.null(config_data$freq)) freq_col <- config_data$freq
  if (!base::is.null(config_data$output_dir)) output_dir <- config_data$output_dir
  if (!base::is.null(config_data$run_id)) run_id_raw <- config_data$run_id

  # vcd-categorical 特有の引数
  if (!base::is.null(config_data$row_var)) row_var_json <- config_data$row_var
  if (!base::is.null(config_data$col_var)) col_var_json <- config_data$col_var
  if (!base::is.null(config_data$layer_var)) layer_var_json <- config_data$layer_var
}

# CLI 引数による上書き（CLI 優先）
data_path <- get_arg_val("--data", data_path)
vars_arg <- get_arg_val("--vars", vars_arg)
freq_col <- get_arg_val("--freq", freq_col)
data_label <- get_arg_val("--label", data_label)
output_dir <- get_arg_val("--out", output_dir)
run_id_raw <- get_arg_val("--run-id", run_id_raw)

sanitize_run_slug <- function(x) {
  if (base::is.null(x) || !base::nzchar(base::trimws(base::as.character(x)[1]))) {
    return(NULL)
  }
  x <- base::trimws(base::as.character(x)[1])
  if (base::tolower(x) == "auto") {
    return(base::format(base::Sys.time(), "%Y%m%d_%H%M%S", tz = "Asia/Tokyo"))
  }
  x <- base::gsub("[/\\\\]", "_", x)
  x <- base::gsub("^\\.+|\\.+$", "", x)
  if (!base::nzchar(x)) {
    base::stop("無効な --run-id です")
  }
  x
}
out_root_for_meta <- base::sub("/+$", "", output_dir)
run_slug <- sanitize_run_slug(run_id_raw)
if (base::is.null(run_slug)) {
  run_slug <- base::format(base::Sys.time(), "%Y%m%d_%H%M%S", tz = "Asia/Tokyo")
}
output_dir <- run_output_dir_from_root(out_root_for_meta, run_slug)
prefix16 <- run_id_short16(run_slug)
candidate <- output_dir
collision <- 2L
while (base::dir.exists(candidate)) {
  candidate <- base::file.path(out_root_for_meta, base::sprintf("run_%s_%d", prefix16, collision))
  collision <- collision + 1L
}
if (collision > 2L) {
  run_slug <- base::sprintf("%s_%d", run_slug, collision - 1L)
}
output_dir <- candidate
base::message("[INFO] run 出力先: ", output_dir)

# ディレクトリ作成
if (!base::dir.exists(output_dir)) {
  base::dir.create(output_dir, recursive = TRUE)
}

# run_meta.json の書き出し
write_run_meta(
  out_root = out_root_for_meta,
  run_output_dir = output_dir,
  skill = "vcd-categorical-analysis",
  run_id = run_slug,
  input_data_path = data_path
)

vars <- base::trimws(base::unlist(base::strsplit(vars_arg, ",")))

# ============================================================
# validate_config
# ============================================================
validate_config <- function(raw) {
  cfg <- base::list(
    collapse_below_n = 0L,
    max_levels_per_var = 999L,
    strata_to_render = base::character(0),
    gt_matrix_vars = c(1L, 2L),
    plot_mode = "auto"
  )
  if (base::is.null(raw) || base::length(raw) == 0) {
    return(cfg)
  }

  if (!base::is.null(raw$collapse_below_n) && base::is.numeric(raw$collapse_below_n)) {
    cfg$collapse_below_n <- base::as.integer(raw$collapse_below_n)
  }
  if (!base::is.null(raw$max_levels_per_var) && base::is.numeric(raw$max_levels_per_var)) {
    cfg$max_levels_per_var <- base::as.integer(raw$max_levels_per_var)
  }
  if (!base::is.null(raw$strata_to_render) && base::is.vector(raw$strata_to_render)) {
    cfg$strata_to_render <- base::as.character(raw$strata_to_render)
  }
  if (!base::is.null(raw$gt_matrix_vars) && base::length(raw$gt_matrix_vars) >= 2) {
    cfg$gt_matrix_vars <- base::as.integer(raw$gt_matrix_vars[1:2])
  }
  if (!base::is.null(raw$plot_mode) && raw$plot_mode %in% c("auto", "always", "residual_only")) {
    cfg$plot_mode <- raw$plot_mode
  }

  unknown_keys <- base::setdiff(base::names(raw), base::names(cfg))
  if (base::length(unknown_keys) > 0) {
    base::message("[WARNING] Unknown config keys ignored: ", base::paste(unknown_keys, collapse = ", "))
  }

  return(cfg)
}

# ============================================================
# load_input_data & automatically aggregate if raw
# ============================================================
load_input_data <- function() {
  if (!base::is.null(data_path) && base::file.exists(data_path)) {
    df <- utils::read.csv(data_path, fileEncoding = "UTF-8", stringsAsFactors = FALSE)
    base::names(df) <- base::trimws(base::names(df))

    missing_vars <- base::setdiff(vars, base::names(df))
    if (base::length(missing_vars) > 0) {
      base::stop("Variables not found in data: ", base::paste(missing_vars, collapse = ", "))
    }

    for (v in vars) {
      if (base::is.character(df[[v]])) {
        df[[v]] <- base::trimws(df[[v]])
      }
    }

    if (!(freq_col %in% base::names(df))) {
      base::message("[INFO] Frequency column '", freq_col, "' not found. Automatically aggregating raw data...")
      tab <- base::table(df[, vars, drop = FALSE])
      df <- base::as.data.frame(tab)
      freq_col <<- "Freq"
      for (v in vars) df[[v]] <- base::as.character(df[[v]])
    } else {
      if (!base::is.numeric(df[[freq_col]])) {
        base::message("[WARNING] Frequency column is not numeric. Attempting conversion.")
        df[[freq_col]] <- base::as.numeric(base::as.character(df[[freq_col]]))
      }
    }
  } else {
    base::message("[INFO] No data provided or file not found. Using built-in HairEyeColor.")
    utils::data("HairEyeColor", package = "datasets")
    df <- base::as.data.frame(HairEyeColor)
    vars <<- c("Hair", "Eye", "Sex")
    freq_col <<- "Freq"
    data_label <<- "haireye"
  }

  for (v in vars) {
    df[[v]] <- base::droplevels(base::factor(df[[v]]))
  }

  return(df)
}

# ============================================================
# apply_aggregation
# ============================================================
apply_aggregation <- function(df, vars, freq_col, config) {
  if (base::is.null(config)) {
    return(df)
  }

  if (config$collapse_below_n > 0) {
    for (v in vars) {
      freq_by_level <- base::tapply(df[[freq_col]], df[[v]], base::sum, na.rm = TRUE)
      minor_levels <- base::names(freq_by_level[freq_by_level <= config$collapse_below_n])
      if (base::length(minor_levels) > 0) {
        df[[v]] <- base::ifelse(df[[v]] %in% minor_levels, "Other", base::as.character(df[[v]]))
      }
    }
  }

  if (config$max_levels_per_var < 999) {
    for (v in vars) {
      freq_by_level <- base::tapply(df[[freq_col]], df[[v]], base::sum, na.rm = TRUE)
      if (base::length(freq_by_level) > config$max_levels_per_var) {
        sorted_levels <- base::names(base::sort(freq_by_level, decreasing = TRUE))
        keep_levels <- utils::head(sorted_levels, config$max_levels_per_var)
        df[[v]] <- base::ifelse(df[[v]] %in% keep_levels, base::as.character(df[[v]]), "Other")
      }
    }
  }

  agg_fml <- stats::as.formula(base::paste(freq_col, "~", base::paste(vars, collapse = " + ")))
  df <- stats::aggregate(agg_fml, data = df, FUN = base::sum, na.rm = TRUE)

  for (v in vars) {
    df[[v]] <- base::droplevels(base::factor(df[[v]]))
  }
  return(df)
}

# ============================================================
# generate_profile
# ============================================================
generate_profile <- function(df, vars, freq_col, output_dir, config = NULL, out_filename = "data_profile.json") {
  if (!base::is.null(config)) {
    df <- apply_aggregation(df, vars, freq_col, config)
  }

  var_info <- base::lapply(vars, function(v) {
    lvls <- base::levels(df[[v]])
    base::list(n_levels = base::length(lvls), levels = lvls)
  })
  base::names(var_info) <- vars

  tab <- stats::xtabs(stats::as.formula(
    base::paste(freq_col, "~", base::paste(vars, collapse = " + "))
  ), data = df)

  total_cells <- base::prod(base::dim(tab))
  n_nonzero <- base::sum(base::as.vector(tab) > 0)

  marginal_cells <- if (base::length(vars) >= 2) {
    base::prod(base::dim(tab)[1:2])
  } else {
    total_cells
  }

  warning_msg <- if (n_nonzero < total_cells) {
    "Data contains zero-frequency cells."
  } else {
    NULL
  }

  profile <- base::list(
    n_dimensions = base::length(vars),
    variables = var_info,
    total_cells = total_cells,
    total_cells_2way_marginal = marginal_cells,
    n_nonzero_cells = n_nonzero,
    sparsity_ratio = base::round(n_nonzero / total_cells, 3),
    warning = warning_msg
  )

  jsonlite::write_json(profile, base::file.path(output_dir, out_filename),
    auto_unbox = TRUE, pretty = TRUE, null = "null"
  )
  base::message("[PROFILE] ", out_filename, " written to ", output_dir)
  return(base::invisible(profile))
}

# ============================================================
# generate_data
# ============================================================
generate_data <- function(df, vars, freq_col, output_dir, config, data_label) {
  df <- apply_aggregation(df, vars, freq_col, config)

  fml_main <- stats::as.formula(base::paste(freq_col, "~", base::paste(vars, collapse = " + ")))
  fml_2way <- stats::as.formula(base::paste(freq_col, "~ (", base::paste(vars, collapse = " + "), ")^2"))
  fml_sat <- stats::as.formula(base::paste(freq_col, "~", base::paste(vars, collapse = " * ")))

  fit_main <- base::tryCatch(stats::glm(fml_main, family = stats::poisson, data = df),
    error = function(e) {
      base::message("[ERROR] fit_main: ", base::conditionMessage(e))
      NULL
    }
  )
  fit_2way <- base::tryCatch(stats::glm(fml_2way, family = stats::poisson, data = df),
    error = function(e) {
      base::message("[ERROR] fit_2way: ", base::conditionMessage(e))
      NULL
    }
  )
  fit_sat <- base::tryCatch(stats::glm(fml_sat, family = stats::poisson, data = df),
    error = function(e) {
      base::message("[ERROR] fit_sat: ", base::conditionMessage(e))
      NULL
    }
  )

  anova_res <- base::tryCatch(stats::anova(fit_main, fit_2way, fit_sat, test = "Chisq"),
    error = function(e) {
      base::message("[WARNING] anova: ", base::conditionMessage(e))
      NULL
    }
  )

  collect_res <- function(fit, label) {
    if (base::is.null(fit)) {
      return(NULL)
    }
    res_df <- df
    res_df$model_type <- label
    res_df$pearson_res <- stats::residuals(fit, type = "pearson")
    res_df$abs_pearson_res <- base::abs(res_df$pearson_res)
    res_df$cell_label <- base::apply(res_df[, vars, drop = FALSE], 1, base::paste, collapse = ":")
    return(res_df)
  }

  res_main <- collect_res(fit_main, "Main Effects (A+B[+C])")
  res_2way <- collect_res(fit_2way, "2-way ((A+B[+C])^2)")
  res_combined <- base::rbind(res_main, res_2way)
  utils::write.csv(res_combined, base::file.path(
    output_dir,
    base::paste0("residuals_", data_label, ".csv")
  ), row.names = FALSE)

  top_n <- 20
  sig_compact <- base::rbind(
    if (!base::is.null(res_main)) utils::head(res_main[base::order(-res_main$abs_pearson_res), ], top_n) else NULL,
    if (!base::is.null(res_2way)) utils::head(res_2way[base::order(-res_2way$abs_pearson_res), ], top_n) else NULL
  )
  if (!base::is.null(sig_compact) && base::nrow(sig_compact) > 0) {
    sig_compact <- sig_compact[!base::duplicated(
      base::paste(sig_compact$model_type, sig_compact$cell_label)
    ), ]
    utils::write.csv(sig_compact, base::file.path(
      output_dir,
      base::paste0("residuals_", data_label, "_significant.csv")
    ), row.names = FALSE)
  }

  tab <- stats::xtabs(stats::as.formula(
    base::paste(freq_col, "~", base::paste(vars, collapse = " + "))
  ), data = df)

  anova_p <- if (!base::is.null(anova_res) && base::nrow(anova_res) >= 2) anova_res$`Pr(>Chi)`[2] else NA

  strata_info <- NULL
  if (base::length(vars) >= 3) {
    strata_var <- vars[3]
    strata_levels <- base::levels(df[[strata_var]])
    max_res_per <- base::sapply(strata_levels, function(lv) {
      sub <- res_main[res_main[[strata_var]] == lv, ]
      if (base::nrow(sub) == 0) {
        return(NA)
      }
      base::max(sub$abs_pearson_res, na.rm = TRUE)
    }, USE.NAMES = TRUE)

    cv_per <- base::sapply(strata_levels, function(lv) {
      sub_tab <- stats::xtabs(
        stats::as.formula(
          base::paste(freq_col, "~", base::paste(vars[1:2], collapse = " + "))
        ),
        data = df[df[[strata_var]] == lv, ]
      )
      base::tryCatch(vcd::assocstats(sub_tab)$cramer, error = function(e) NA)
    }, USE.NAMES = TRUE)

    n_sig_5 <- base::sum(res_combined$abs_pearson_res >= 1.96, na.rm = TRUE)
    n_sig_1 <- base::sum(res_combined$abs_pearson_res >= 2.58, na.rm = TRUE)
    strata_info <- base::list(
      strata_var = strata_var,
      n_strata = base::length(strata_levels),
      max_abs_res_per_stratum = as.list(max_res_per),
      cramers_v_per_stratum = as.list(cv_per),
      n_significant_cells_5pct = n_sig_5,
      n_significant_cells_1pct = n_sig_1,
      total_cells = base::nrow(res_combined)
    )
  }

  summary_obj <- base::list(
    interface_version = "2.1",
    test_used = "stats::anova (Poisson GLM)",
    models_tested = c("Main Effects (A+B[+C])", "2-way ((A+B[+C])^2)"),
    deviance_main = if (!base::is.null(fit_main)) fit_main$deviance else NA,
    df_main = if (!base::is.null(fit_main)) fit_main$df.residual else NA,
    deviance_2way = if (!base::is.null(fit_2way)) fit_2way$deviance else NA,
    df_2way = if (!base::is.null(fit_2way)) fit_2way$df.residual else NA,
    p_value_main_vs_2way = anova_p,
    cramers_v_marginal = base::tryCatch(
      vcd::assocstats(base::margin.table(tab, c(1, 2)))$cramer,
      error = function(e) NA
    ),
    top_residuals_main = if (!base::is.null(res_main)) {
      idx <- utils::head(base::order(-res_main$abs_pearson_res), 5)
      base::lapply(idx, function(i) base::list(cell = res_main$cell_label[i], res = res_main$pearson_res[i]))
    } else {
      NULL
    },
    top_residuals_2way = if (!base::is.null(res_2way)) {
      idx <- utils::head(base::order(-res_2way$abs_pearson_res), 5)
      base::lapply(idx, function(i) base::list(cell = res_2way$cell_label[i], res = res_2way$pearson_res[i]))
    } else {
      NULL
    },
    strata_summary = strata_info
  )

  jsonlite::write_json(summary_obj, base::file.path(
    output_dir,
    base::paste0("summary_", data_label, ".json")
  ), auto_unbox = TRUE, pretty = TRUE, null = "null")

  base::message("[DATA] JSON/CSV written for: ", data_label)
  return(base::list(df = df, tab = tab, res_combined = res_combined))
}

# ============================================================
# generate_gt_matrix
# ============================================================
generate_gt_matrix <- function(res_df, vars, freq_col, output_dir, config, data_label) {
  if (base::is.null(res_df) || base::nrow(res_df) == 0) {
    return()
  }

  v1_idx <- base::max(1, base::min(base::length(vars), config$gt_matrix_vars[1]))
  v2_idx <- base::max(1, base::min(base::length(vars), config$gt_matrix_vars[2]))

  row_var <- vars[v1_idx]
  col_var <- vars[v2_idx]

  build_matrix <- function(sub_df, suffix) {
    agg <- stats::aggregate(
      stats::as.formula(base::paste("pearson_res ~", row_var, "+", col_var)),
      data = sub_df, FUN = base::mean, na.rm = TRUE
    )
    wide <- stats::reshape(agg, idvar = row_var, timevar = col_var, direction = "wide")
    base::names(wide) <- base::gsub("^pearson_res\\.", "", base::names(wide))
    row_names <- wide[[row_var]]
    wide[[row_var]] <- NULL

    mx <- base::max(base::abs(base::unlist(wide)), na.rm = TRUE)
    if (!base::is.finite(mx) || mx < 1e-12) mx <- 1

    tbl <- gt::gt(base::cbind(data.frame(V1 = row_names), wide), rowname_col = "V1") |>
      gt::fmt_number(decimals = 3) |>
      gt::data_color(
        columns = base::names(wide),
        domain = c(-mx, mx), palette = c("#D73027", "#FFFFFF", "#4575B4")
      ) |>
      gt::tab_header(title = base::paste("Pearson Residuals:", suffix)) |>
      gt::tab_stubhead(label = row_var) |>
      gt::tab_style(
        style = gt::cell_borders(sides = "all", weight = gt::px(2), color = "#333333"),
        locations = gt::cells_body(
          columns = base::names(wide),
          rows = base::apply(wide, 1, function(r) base::any(base::abs(r) >= 1.96, na.rm = TRUE))
        )
      )
    fname <- base::paste0("matrix_", suffix, ".html")
    gt::gtsave(tbl, base::file.path(output_dir, fname))
    base::message("[GT] ", fname)
  }

  main_df <- res_df[res_df$model_type == "Main Effects (A+B[+C])", ]
  if (base::nrow(main_df) == 0) {
    return()
  }

  # Marginal gt matrix is built using variables 1 and 2 normally
  build_matrix(main_df, base::paste0("marginal_", data_label))

  if (base::length(vars) >= 3) {
    strata_var <- vars[3]
    strata_to_render <- if (base::length(config$strata_to_render) > 0) {
      config$strata_to_render
    } else {
      base::levels(base::factor(main_df[[strata_var]]))
    }
    for (lv in strata_to_render) {
      sub <- main_df[main_df[[strata_var]] == lv, ]
      if (base::nrow(sub) > 0) {
        build_matrix(sub, base::paste0(data_label, "_", lv))
      }
    }
  }
}

# ============================================================
# generate_dt_table
# ============================================================
generate_dt_table <- function(res_df, vars, output_dir, config, data_label) {
  if (base::is.null(res_df) || base::nrow(res_df) == 0) {
    return()
  }

  display_cols <- base::intersect(c(vars, freq_col, "pearson_res", "abs_pearson_res", "model_type"), base::names(res_df))
  dt_df <- res_df[, display_cols, drop = FALSE]
  dt_df <- dt_df[base::order(-dt_df$abs_pearson_res), ]

  for (v in vars) {
    if (v %in% base::names(dt_df)) {
      dt_df[[v]] <- base::factor(dt_df[[v]], levels = base::sort(base::unique(base::as.character(dt_df[[v]]))))
    }
  }
  if ("model_type" %in% base::names(dt_df)) {
    dt_df[["model_type"]] <- base::factor(
      dt_df[["model_type"]],
      levels = base::sort(base::unique(base::as.character(dt_df[["model_type"]])))
    )
  }

  mx <- base::max(dt_df$abs_pearson_res, na.rm = TRUE)
  if (!base::is.finite(mx) || mx < 1e-12) mx <- 1

  brks <- base::seq(-mx, mx, length.out = 100)
  clrs <- grDevices::colorRampPalette(c("#D73027", "#FFFFFF", "#4575B4"))(100)

  widget <- DT::datatable(dt_df,
    filter = "top",
    options = base::list(
      pageLength = 50,
      order = base::list(base::list(base::which(base::names(dt_df) == "abs_pearson_res") - 1, "desc")),
      dom = "lftipr"
    ),
    caption = base::paste("Pearson Residuals:", data_label)
  ) |>
    DT::formatRound(columns = c("pearson_res", "abs_pearson_res"), digits = 3) |>
    DT::formatStyle("pearson_res", backgroundColor = DT::styleInterval(brks[-1], clrs))

  fname <- base::paste0("dt_residuals_", data_label, ".html")
  htmlwidgets::saveWidget(widget, base::file.path(base::normalizePath(output_dir), fname), selfcontained = TRUE)
  base::message("[DT] ", fname)
}

# ============================================================
# generate_plots
# ============================================================
generate_plots <- function(tab, vars, output_dir, config, data_label) {
  if (config$plot_mode == "residual_only") {
    base::message("[PLOTS] plot_mode is 'residual_only'. Skipping PNG generation.")
    return()
  }

  if (config$plot_mode == "auto") {
    total_cells <- base::prod(base::dim(tab))
    threshold <- if (base::length(vars) >= 3) 36 else 16
    max_label_len <- base::max(base::nchar(base::unlist(base::dimnames(tab))))

    if (total_cells > threshold || max_label_len > 24) {
      base::message(
        "[PLOTS] plot_mode 'auto' threshold exceeded (cells=", total_cells,
        ", max_label_len=", max_label_len, "). Skipping PNG generation."
      )
      return()
    }
  }

  grDevices::png(base::file.path(output_dir, base::paste0("mosaic_", data_label, ".png")), width = 1000, height = 800)
  vcd::mosaic(tab, shade = TRUE, main = base::paste("Mosaic:", base::paste(vars, collapse = " x ")))
  grDevices::dev.off()

  if (base::length(vars) == 2) {
    grDevices::png(base::file.path(output_dir, base::paste0("assoc_", data_label, ".png")), width = 1000, height = 800)
    vcd::assoc(tab, residuals_type = "Pearson", shade = TRUE, main = base::paste("Association:", base::paste(vars, collapse = " x ")))
    grDevices::dev.off()
  }

  if (base::length(vars) >= 3) {
    grDevices::png(base::file.path(output_dir, base::paste0("cotab_", data_label, ".png")), width = 1000, height = 800)
    vcd::cotabplot(tab, panel = vcd::cotab_mosaic, shade = TRUE)
    grDevices::dev.off()
  }
  base::message("[PLOTS] PNG files written for: ", data_label)
}

# ============================================================
# generate_categorical_results_json (for Pass 3 Dashboard)
# ============================================================
generate_categorical_results_json <- function(df, vars, freq_col, output_dir, res_combined, data_label) {
  # dashboard.Rmd が期待する構造
  output <- list(
    interface_version = "1.0",
    dataset_name = data_label,
    dimensions = vars,
    n_total = sum(df[[freq_col]], na.rm = TRUE),
    cramers_v = tryCatch(vcd::assocstats(xtabs(as.formula(paste(freq_col, "~", paste(vars[1:2], collapse = " + "))), data = df))$cramer, error = function(e) NA),
    full_data = res_combined
  )

  jsonlite::write_json(output, file.path(output_dir, "categorical_results.json"), auto_unbox = TRUE, pretty = TRUE)
  base::message("[JSON] categorical_results.json written for dashboard integration")
}

# ============================================================
# Main dispatcher
# ============================================================
base::dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# 1. Load data and auto-aggregate if needed
df <- load_input_data()

if (mode == "profile") {
  generate_profile(df, vars, freq_col, output_dir, config = NULL, out_filename = "data_profile.json")
} else {
  raw_config <- if (!base::is.null(config_path) && base::file.exists(config_path)) {
    jsonlite::read_json(config_path)
  } else {
    base::list()
  }
  config <- validate_config(raw_config)

  # Pass 2: Apply aggregation first, then generate post-profile from aggregated data
  df_agg <- apply_aggregation(df, vars, freq_col, config)
  generate_profile(df_agg, vars, freq_col, output_dir, config = NULL, out_filename = "data_profile_post.json")

  # Generate data, tables, plots (generate_data applies aggregation internally)
  res <- generate_data(df, vars, freq_col, output_dir, config, data_label)
  generate_gt_matrix(res$res_combined, vars, freq_col, output_dir, config, data_label)
  generate_dt_table(res$res_combined, vars, output_dir, config, data_label)
  generate_plots(res$tab, vars, output_dir, config, data_label)

  # 追加: ダッシュボード連携用 JSON
  generate_categorical_results_json(df_agg, vars, freq_col, output_dir, res$res_combined, data_label)

  base::message("[DONE] All outputs generated for: ", data_label)
}
