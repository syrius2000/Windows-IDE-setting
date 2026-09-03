#!/usr/bin/env Rscript
# =============================================================================
# vcd-bayesian-evidence-analysis: analysis.R
# Pass 1: Poisson GLM + EBIC近似ベイズファクター + Evidence Score 算出
# =============================================================================

suppressPackageStartupMessages({
  if (!base::requireNamespace("pacman", quietly = TRUE)) {
    utils::install.packages("pacman", repos = "https://cloud.r-project.org")
  }
  pacman::p_load(dplyr, tidyr, jsonlite, DT, htmlwidgets, htmltools, effectsize)
})

script_file_arg <- grep("^--file=", commandArgs(), value = TRUE)[1]
script_dir <- dirname(sub("^--file=", "", script_file_arg))
source(file.path(script_dir, "pass1_compute.R"))
source(file.path(script_dir, "config_validation.R"))

find_agent_repo <- function() {
  d <- normalizePath(getwd(), winslash = "/", mustWork = FALSE)
  for (i in seq_len(25L)) {
    if (file.exists(file.path(d, ".agent", "shared", "run_scope.R"))) {
      return(d)
    }
    parent <- dirname(d)
    if (parent == d) {
      break
    }
    d <- parent
  }
  getwd()
}
source(file.path(find_agent_repo(), ".agent", "shared", "run_scope.R"))

parse_args <- function(args) {
  result <- list(
    input = NULL,
    output_dir = "./skill_out/vcd_bayesian",
    run_id = NULL,
    dataset_name = "dataset",
    vars = NULL,
    freq = "Freq",
    response_var = NULL,
    top_k = 10L,
    threshold_k = 1,
    large_n_threshold = 1000,
    ebic_gamma = 0.5,
    ebic_p = NA_real_,
    level2_factor = 2,
    level3_factor = 3,
    arm_top_rules = 20L,
    arm_min_support = 0.01,
    arm_min_confidence = 0.10,
    show_help = FALSE,
    show_help_stats = FALSE
  )

  i <- 1L
  while (i <= length(args)) {
    switch(args[i],
      "--input" = {
        i <- i + 1L
        result$input <- args[i]
      },
      "--output_dir" = {
        i <- i + 1L
        result$output_dir <- args[i]
      },
      "--run-id" = {
        i <- i + 1L
        if (i > length(args) || startsWith(args[i], "--")) {
          result$run_id <- NA_character_
        } else {
          result$run_id <- args[i]
        }
      },
      "--dataset_name" = {
        i <- i + 1L
        result$dataset_name <- args[i]
      },
      "--config" = {
        i <- i + 1L
        result$config_path <- args[i]
      },
      "--vars" = {
        i <- i + 1L
        parsed_vars <- strsplit(args[i], ",")[[1]]
        parsed_vars <- trimws(parsed_vars)
        result$vars <- parsed_vars[nzchar(parsed_vars)]
      },
      "--freq" = {
        i <- i + 1L
        result$freq <- args[i]
      },
      "--response_var" = {
        i <- i + 1L
        result$response_var <- args[i]
      },
      "--response-var" = {
        i <- i + 1L
        result$response_var <- args[i]
      },
      "--top_k" = {
        i <- i + 1L
        result$top_k <- as.integer(args[i])
      },
      "--threshold_k" = {
        i <- i + 1L
        result$threshold_k <- as.numeric(args[i])
      },
      "--large_n_threshold" = {
        i <- i + 1L
        result$large_n_threshold <- as.numeric(args[i])
      },
      "--ebic_gamma" = {
        i <- i + 1L
        result$ebic_gamma <- as.numeric(args[i])
      },
      "--ebic_p" = {
        i <- i + 1L
        result$ebic_p <- as.numeric(args[i])
      },
      "--level2_factor" = {
        i <- i + 1L
        result$level2_factor <- as.numeric(args[i])
      },
      "--level3_factor" = {
        i <- i + 1L
        result$level3_factor <- as.numeric(args[i])
      },
      "--arm_top_rules" = {
        i <- i + 1L
        result$arm_top_rules <- as.integer(args[i])
      },
      "--arm_min_support" = {
        i <- i + 1L
        result$arm_min_support <- as.numeric(args[i])
      },
      "--arm_min_confidence" = {
        i <- i + 1L
        result$arm_min_confidence <- as.numeric(args[i])
      },
      "--help" = {
        result$show_help <- TRUE
      },
      "--help_stats" = {
        result$show_help_stats <- TRUE
      }
    )
    i <- i + 1L
  }

  # --run-id と --run_id の別名対応（正準化）
  if (is.null(result$run_id)) {
    rid_arg <- grep("^--run_id=", commandArgs(), value = TRUE)
    if (length(rid_arg) > 0) {
      result$run_id <- sub("^--run_id=", "", rid_arg[1])
    }
  }

  result
}

cfg <- parse_args(commandArgs(trailingOnly = TRUE))

# JSON 設定の読み込み (Pass 0 連携用)
if (!is.null(cfg$config_path)) {
  if (is.na(cfg$config_path) || !nzchar(cfg$config_path) || startsWith(cfg$config_path, "--")) {
    stop("[ERROR] --config には analysis_config.json のパスを指定してください。", call. = FALSE)
  }
  if (file.exists(cfg$config_path)) {
    if (!requireNamespace("jsonlite", quietly = TRUE)) {
      message("[WARN] jsonlite がインストールされていないため --config を無視します。")
    } else {
      config_data <- tryCatch(
        jsonlite::fromJSON(cfg$config_path),
        error = function(e) {
          stop("[ERROR] 設定ファイルを JSON として読めません: ", e$message, call. = FALSE)
        }
      )
      message("[INFO] 設定を読み込み中: ", cfg$config_path)
      resolved_config <- validate_analysis_config(config_data, cfg$config_path, find_agent_repo())
      if (!is.null(resolved_config$input)) {
        config_data$input <- resolved_config$input
      }
      # config_data の値を cfg に反映（JSON 優先）
      for (key in names(config_data)) {
        cfg[[key]] <- config_data[[key]]
      }
    }
  } else {
    stop("[ERROR] 設定ファイルが見つかりません: ", cfg$config_path, call. = FALSE)
  }
}

if (!is.null(cfg$run_id)) {
  rid0 <- as.character(cfg$run_id)[1L]
  if (is.na(rid0) || !nzchar(rid0)) {
    stop("[ERROR] 無効な --run-id: 空の値は指定できません。", call. = FALSE)
  }
}

if (isTRUE(cfg$show_help)) {
  cat("
Usage: Rscript analysis.R [OPTIONS]

Options:
  --input <file>              入力CSVファイル（省略時: HairEyeColor）
  --output_dir <dir>          出力ディレクトリ（既定: ./skill_out/vcd_bayesian）
  --run-id <slug>|auto        任意。指定時は <dir>/run_<slug先頭16文字>/ に隔離（auto=JST時刻）
  --dataset_name <name>       データセット名（既定: dataset）
  --vars <v1,v2,...>          分析変数（カンマ区切り、省略時: 全変数）
  --freq <col>                度数列名（既定: Freq）
  --response_var <col>        応答変数。3次元以上のCramér's V算出で使用
  --top_k <N>                 Top-K 表示件数（既定: 10）
  --threshold_k <k>           Evidence閾値係数（既定: 1）
  --large_n_threshold <N>     大規模データモード閾値（既定: 1000）
  --ebic_gamma <g>            EBIC追加ペナルティ係数γ（既定: 0.5）
  --ebic_p <p>                EBICの候補パラメータ数（省略時: 飽和モデル係数数）
  --level2_factor <x>         Level2倍率（既定: 2）
  --level3_factor <x>         Level3倍率（既定: 3）
  --arm_top_rules <N>         ARM上位ルール件数（既定: 20）
  --arm_min_support <x>       ARM最小support（既定: 0.01）
  --arm_min_confidence <x>    ARM最小confidence（既定: 0.10）
  --help                      このヘルプを表示
  --help_stats                統計指標ガイドを表示
")
  quit(status = 0L)
}

if (isTRUE(cfg$show_help_stats)) {
  cat("
=================================================================
 統計指標ガイド（vcd-bayesian-evidence-analysis）
=================================================================

 ■ Evidence Score = r² − k·log(N)
   正値: 実質的エビデンス  /  負値: ノイズ範囲

 ■ ベイズファクター（BF10, EBIC近似）
   logBF10 ≈ 0.5 * (EBIC_indep - EBIC_satur)
   BF > 100: 決定的  BF > 10: 強い  BF > 3: 中程度

 ■ 効果量
   - 多次元クロス表: Cramér's V
   - 1次元適合度: Fei

 ■ Dual-Filter
   効果量がSmall未満なら「統計的には強くても実務的には弱い」警告

 ■ ARM（行データのみ）
   support / confidence / lift を算出。Freq列がある場合は重みとして扱う。
=================================================================
")
  quit(status = 0L)
}

# run_id の解決と出力隔離はデータ読み込み後に行う

load_data <- function(cfg) {
  if (is.null(cfg$input)) {
    message("[INFO] --input 未指定。HairEyeColor データセットを使用します。")
    return(as.data.frame(HairEyeColor))
  }
  if (!file.exists(cfg$input)) {
    stop(paste("[ERROR] 入力ファイルが見つかりません:", cfg$input))
  }
  read.csv(cfg$input, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
}

df_input <- load_data(cfg)
message(paste("[INFO] データ読み込み完了:", nrow(df_input), "行,", ncol(df_input), "列"))

# run_id の解決と出力ディレクトリの準備
rid <- if (is.null(cfg$run_id)) {
  resolve_run_id(builtin_df = df_input)
} else {
  list(run_id = sanitize_run_slug(cfg$run_id), method = "manual")
}
out_root <- cfg$output_dir
if (!dir.exists(out_root)) {
  dir.create(out_root, recursive = TRUE)
}
artifact_dir <- run_output_dir_from_root(out_root, rid$run_id)
if (!dir.exists(artifact_dir)) {
  dir.create(artifact_dir, recursive = TRUE)
}
message(paste("[INFO] run_id:", rid$run_id, "(", rid$method %||% rid$source %||% "resolved", ")"))
message(paste("[INFO] 出力ディレクトリ:", artifact_dir))

# run_meta.json の書き出し
input_path_log <- if (is.null(cfg$input)) "builtin:HairEyeColor" else cfg$input
write_run_meta(out_root, artifact_dir, "vcd-bayesian-evidence-analysis", rid$run_id, input_path_log)

freq_col <- cfg$freq
freq_exists <- freq_col %in% names(df_input)

if (!is.null(cfg$vars)) {
  cat_vars <- cfg$vars
} else {
  cat_vars <- if (freq_exists) setdiff(names(df_input), freq_col) else names(df_input)
}

if (length(cat_vars) < 1L) {
  stop("[ERROR] 分析変数が見つかりません。--vars または入力列を確認してください。")
}
message(paste("[INFO] 分析変数:", paste(cat_vars, collapse = ", ")))

response_var <- cfg$response_var
if (!is.null(response_var)) {
  response_var <- as.character(response_var)[1L]
  if (is.na(response_var) || !nzchar(response_var)) {
    stop("[ERROR] response_var は空でない列名である必要があります。", call. = FALSE)
  }
  if (!(response_var %in% names(df_input))) {
    stop(paste("[ERROR] response_var が入力データに存在しません:", response_var), call. = FALSE)
  }
  if (!(response_var %in% cat_vars)) {
    stop(paste("[ERROR] response_var は分析変数 vars に含める必要があります:", response_var), call. = FALSE)
  }
  message(paste("[INFO] 応答変数 response_var:", response_var))
}

arm_df <- df_input
arm_weight_col <- if (freq_exists) freq_col else ".arm_weight"
if (!freq_exists) {
  arm_df[[arm_weight_col]] <- 1
}

if (!freq_exists) {
  message(paste("[INFO]", freq_col, "列が見つかりません。行数を度数として集計します。"))
  df_raw <- df_input %>%
    group_by(across(all_of(cat_vars))) %>%
    summarise(Freq = n(), .groups = "drop")
  freq_col <- "Freq"
} else {
  df_raw <- df_input
}

df_raw[cat_vars] <- lapply(df_raw[cat_vars], as.character)
df_raw[[freq_col]] <- as.numeric(df_raw[[freq_col]])
df <- df_raw %>% filter(!is.na(.data[[freq_col]]), .data[[freq_col]] >= 0)

n_total <- sum(df[[freq_col]])
log_n <- log(n_total)
message(paste("[INFO] 総度数 N =", n_total, "/ log(N) =", round(log_n, 4)))

formula_indep <- as.formula(paste(freq_col, "~", paste(cat_vars, collapse = " + ")))
formula_satur <- as.formula(paste(freq_col, "~", paste(cat_vars, collapse = " * ")))

message("[INFO] Poisson GLM 独立モデルを適合中...")
glm_indep <- glm(formula_indep, data = df, family = poisson(link = "log"))
message("[INFO] Poisson GLM 飽和モデルを適合中...")
glm_satur <- glm(formula_satur, data = df, family = poisson(link = "log"))

bic_indep <- BIC(glm_indep)
bic_satur <- BIC(glm_satur)
delta_bic <- bic_indep - bic_satur
log_bf_bic <- 0.5 * delta_bic
bf_bic <- exp(log_bf_bic)

k_indep <- attr(stats::logLik(glm_indep), "df")
k_satur <- attr(stats::logLik(glm_satur), "df")
p_total <- if (is.na(cfg$ebic_p)) k_satur else cfg$ebic_p

ebic_indep <- compute_ebic(glm_indep, n_total, p_total, cfg$ebic_gamma)
ebic_satur <- compute_ebic(glm_satur, n_total, p_total, cfg$ebic_gamma)
delta_ebic <- ebic_indep - ebic_satur
log_bf <- 0.5 * delta_ebic
bf_val <- exp(log_bf)

bf_str <- if (is.infinite(bf_val)) "Inf" else as.character(round(bf_val, 4))
bf_bic_str <- if (is.infinite(bf_bic)) "Inf" else as.character(round(bf_bic, 4))

message(paste("[INFO] EBIC(独立) =", round(ebic_indep, 2)))
message(paste("[INFO] EBIC(飽和) =", round(ebic_satur, 2)))
message(paste("[INFO] ΔEBIC =", round(delta_ebic, 2), "/ log BF(EBIC) =", round(log_bf, 4)))
message(paste("[INFO] BF10(EBIC) =", bf_str, "| BF10(BIC) =", bf_bic_str))
message(paste("[INFO] BF解釈:", interpret_bf(bf_val)))

drop_empty_margins <- function(tab) {
  if (length(dim(tab)) != 2L) {
    return(tab)
  }
  tab[rowSums(tab) > 0, colSums(tab) > 0, drop = FALSE]
}

ct <- xtabs(as.formula(paste(freq_col, "~", paste(cat_vars, collapse = " + "))), data = df)
effect_status <- "not_applicable"
effect_reason <- "Cramér's V は2次元表、または3次元以上では response_var 指定時のみ算出します。"
effect_scope <- "none"
effect_table_dimensions <- character()
cramers_v_val <- NA_real_
cramers_v_ci_low <- NA_real_
cramers_v_ci_high <- NA_real_

cv_input <- NULL
if (length(cat_vars) == 2L) {
  cv_input <- drop_empty_margins(ct)
  effect_scope <- "two_way_table"
  effect_table_dimensions <- cat_vars
  effect_reason <- "2次元分割表からCramér's Vを算出しました。"
} else if (length(cat_vars) > 2L && !is.null(response_var)) {
  predictor_vars <- setdiff(cat_vars, response_var)
  if (length(predictor_vars) >= 1L) {
    effect_df <- df
    effect_df$.predictor_profile <- interaction(effect_df[predictor_vars], drop = TRUE, sep = " | ")
    cv_input <- xtabs(as.formula(paste(freq_col, "~ .predictor_profile +", response_var)), data = effect_df)
    cv_input <- drop_empty_margins(cv_input)
    effect_scope <- "predictor_profile_by_response"
    effect_table_dimensions <- c(paste(predictor_vars, collapse = " + "), response_var)
    effect_reason <- paste0(
      "3次元以上の表を response_var=", response_var,
      " に対し、予測側水準の組み合わせ × 応答変数へ畳み込んでCramér's Vを算出しました。"
    )
  }
}

cv_result <- if (!is.null(cv_input)) {
  tryCatch(
    effectsize::cramers_v(cv_input, ci = 0.95),
    error = function(e) {
      effect_status <<- "failed"
      effect_reason <<- paste("Cramér's V 算出失敗:", e$message)
      message(paste("[WARN]", effect_reason))
      NULL
    }
  )
} else {
  message(paste("[INFO]", effect_reason))
  NULL
}

if (!is.null(cv_result)) {
  cramers_v_val <- if ("Cramers_v_adjusted" %in% names(cv_result)) {
    as.numeric(cv_result$Cramers_v_adjusted)
  } else if ("Cramers_v" %in% names(cv_result)) {
    as.numeric(cv_result$Cramers_v)
  } else {
    as.numeric(cv_result[[1L]])
  }
  cramers_v_ci_low <- safe_num(cv_result$CI_low)
  cramers_v_ci_high <- safe_num(cv_result$CI_high)
  effect_status <- if (!is.na(cramers_v_val)) "computed" else "failed"
  if (is.na(cramers_v_val)) {
    effect_reason <- "Cramér's Vの結果がNAでした。入力表の構造を確認してください。"
  }
}

fei_val <- NA_real_
fei_ci_low <- NA_real_
fei_ci_high <- NA_real_
if (length(cat_vars) == 1L) {
  counts <- df[[freq_col]]
  fei_result <- tryCatch(
    effectsize::fei(counts, ci = 0.95),
    error = function(e) {
      message(paste("[WARN] Fei 算出失敗:", e$message))
      NULL
    }
  )
  if (!is.null(fei_result)) {
    fei_val <- safe_num(fei_result$Fei)
    fei_ci_low <- safe_num(fei_result$CI_low)
    fei_ci_high <- safe_num(fei_result$CI_high)
  }
}

large_sample_mode <- n_total > cfg$large_n_threshold
if (large_sample_mode) {
  message(paste("[INFO] 大規模データモード: N =", n_total, ">", cfg$large_n_threshold))
  message("[INFO] → 効果量を優先して解釈します。")
}

threshold_l1 <- cfg$threshold_k * log_n
threshold_l2 <- cfg$level2_factor * threshold_l1
threshold_l3 <- cfg$level3_factor * threshold_l1

df$Expected <- fitted(glm_indep)
df$Residual <- residuals(glm_indep, type = "pearson")
df$Evidence_Score <- df$Residual^2 - threshold_l1
df$Intensity_Level <- ifelse(
  df$Evidence_Score > threshold_l3, 3L,
  ifelse(df$Evidence_Score > threshold_l2, 2L,
    ifelse(df$Evidence_Score > threshold_l1, 1L, 0L)
  )
)

n_positive <- sum(df$Evidence_Score > 0)
n_total_cells <- nrow(df)

full_data <- df %>%
  select(all_of(c(cat_vars, freq_col, "Expected", "Residual", "Evidence_Score", "Intensity_Level"))) %>%
  arrange(desc(Evidence_Score)) %>%
  mutate(across(where(is.numeric), ~ round(., 4)))
names(full_data)[names(full_data) == freq_col] <- "Freq"
names(full_data)[names(full_data) == "Intensity_Level"] <- "Intensity_Level"

abs_res <- abs(df$Residual)
abs_score <- abs(df$Evidence_Score)
viz_thresholds <- list(
  residual_abs_p90 = safe_round(stats::quantile(abs_res, 0.90, na.rm = TRUE), 4),
  residual_abs_p95 = safe_round(stats::quantile(abs_res, 0.95, na.rm = TRUE), 4),
  residual_abs_p99 = safe_round(stats::quantile(abs_res, 0.99, na.rm = TRUE), 4),
  score_abs_p90 = safe_round(stats::quantile(abs_score, 0.90, na.rm = TRUE), 4),
  score_abs_p95 = safe_round(stats::quantile(abs_score, 0.95, na.rm = TRUE), 4),
  score_abs_p99 = safe_round(stats::quantile(abs_score, 0.99, na.rm = TRUE), 4)
)

effect_metric <- if (length(cat_vars) == 1L) "fei" else "cramers_v"
effect_value <- if (effect_metric == "fei") fei_val else cramers_v_val
small_threshold <- 0.1
practical_low <- is.finite(effect_value) && !is.na(effect_value) && effect_value < small_threshold

arm_reason <- "入力要件を満たさないためスキップ"
arm_result <- list(eligible = FALSE, reason = arm_reason, top_rules = data.frame())
if (length(cat_vars) >= 2L) {
  if (freq_exists) {
    unique_combo_n <- nrow(dplyr::distinct(arm_df, across(all_of(cat_vars))))
    aggregated_like <- unique_combo_n == nrow(arm_df)
    if (aggregated_like) {
      arm_reason <- "Freq付き集計表と判定したためARMスキップ"
    } else {
      arm_result <- compute_arm_rules(
        arm_df, arm_weight_col, cat_vars,
        cfg$arm_top_rules, cfg$arm_min_support, cfg$arm_min_confidence
      )
      arm_reason <- arm_result$reason
    }
  } else {
    arm_result <- compute_arm_rules(
      arm_df, arm_weight_col, cat_vars,
      cfg$arm_top_rules, cfg$arm_min_support, cfg$arm_min_confidence
    )
    arm_reason <- arm_result$reason
  }
}

if (!dir.exists(cfg$output_dir)) {
  dir.create(cfg$output_dir, recursive = TRUE)
  message(paste("[INFO] 出力ディレクトリ作成:", cfg$output_dir))
}

warnings <- list()
if (large_sample_mode && isTRUE(practical_low)) {
  msg <- paste0("実用的有意性の欠如: 効果量 ", effect_metric, " = ", round(effect_value, 3), " (< 0.1)。統計的に有意であっても、この偏りは実務上の意味が薄い可能性があります。")
  message(paste("[WARN]", msg))
  warnings$practical_significance <- msg
}

core <- list(
  dimensions = cat_vars,
  n_total = n_total,
  log_n = safe_round(log_n, 4),
  top_k = cfg$top_k,
  n_cells = n_total_cells,
  n_evidence_cells = n_positive,
  large_sample_mode = large_sample_mode,
  large_n_threshold = cfg$large_n_threshold,
  top_k_data = head(full_data, cfg$top_k),
  full_data = full_data
)

model_selection <- list(
  method = "EBIC",
  ebic_gamma = cfg$ebic_gamma,
  ebic_p = p_total,
  ebic_indep = safe_round(ebic_indep, 4),
  ebic_satur = safe_round(ebic_satur, 4),
  delta_ebic = safe_round(delta_ebic, 4),
  log_bf10 = safe_round(log_bf, 4),
  bf10 = bf_str,
  bic_indep = safe_round(bic_indep, 4),
  bic_satur = safe_round(bic_satur, 4),
  delta_bic = safe_round(delta_bic, 4),
  bf10_bic = bf_bic_str
)

effects <- list(
  primary = effect_metric,
  response_var = response_var,
  effect_status = effect_status,
  effect_reason = effect_reason,
  effect_scope = effect_scope,
  effect_table_dimensions = effect_table_dimensions,
  cramers_v = safe_round(cramers_v_val, 4),
  cramers_v_ci_low = safe_round(cramers_v_ci_low, 4),
  cramers_v_ci_high = safe_round(cramers_v_ci_high, 4),
  fei = safe_round(fei_val, 4),
  fei_ci_low = safe_round(fei_ci_low, 4),
  fei_ci_high = safe_round(fei_ci_high, 4),
  effect_small_threshold = small_threshold
)

threshold_l1_out <- safe_round(threshold_l1, 4)
threshold_l2_out <- safe_round(threshold_l1_out * cfg$level2_factor, 4)
threshold_l3_out <- safe_round(threshold_l1_out * cfg$level3_factor, 4)

thresholds <- list(
  method = "BIC Approximation (M0 vs M1)",
  comparison = "M0 (Additive Main Effects) vs M1 (Single-cell Specific Effect)",
  penalty_per_cell = "log(N) (1 degree of freedom)",
  threshold_k = cfg$threshold_k,
  level1 = threshold_l1_out,
  level2 = threshold_l2_out,
  level3 = threshold_l3_out,
  level2_factor = cfg$level2_factor,
  level3_factor = cfg$level3_factor
)

warnings <- list(
  practical_significance_low = practical_low,
  practical_significance_message = if (large_sample_mode && isTRUE(practical_low)) {
    paste0("実用的有意性の欠如: 効果量 ", effect_metric, " = ", round(effect_value, 3), " (< 0.1)。統計的に有意であっても、この偏りは実務上の意味が薄い可能性があります。")
  } else {
    NULL
  }
)

extensions <- list(
  viz_thresholds = viz_thresholds,
  arm = list(
    eligible = arm_result$eligible,
    reason = arm_reason,
    min_support = cfg$arm_min_support,
    min_confidence = cfg$arm_min_confidence,
    top_rules = arm_result$top_rules
  )
)

result_list <- list(
  core = core,
  model_selection = model_selection,
  effects = effects,
  thresholds = thresholds,
  warnings = warnings,
  extensions = extensions,
  # backward compatibility
  dimensions = core$dimensions,
  n_total = core$n_total,
  bf_independence = model_selection$bf10,
  log_n = core$log_n,
  threshold = thresholds$level1,
  threshold_k = thresholds$threshold_k,
  bic_indep = model_selection$bic_indep,
  bic_satur = model_selection$bic_satur,
  delta_bic = model_selection$delta_bic,
  response_var = effects$response_var,
  effect_status = effects$effect_status,
  effect_reason = effects$effect_reason,
  cramers_v = effects$cramers_v,
  cramers_v_ci_low = effects$cramers_v_ci_low,
  cramers_v_ci_high = effects$cramers_v_ci_high,
  large_sample_mode = core$large_sample_mode,
  large_n_threshold = core$large_n_threshold,
  n_cells = core$n_cells,
  n_evidence_cells = core$n_evidence_cells,
  top_k = core$top_k,
  top_k_data = core$top_k_data,
  full_data = core$full_data
)

result_list$run_id <- rid$run_id

# 隔離ディレクトリ artifact_dir に保存
json_path <- file.path(artifact_dir, "evidence_results.json")
write_json(result_list, json_path, pretty = TRUE, auto_unbox = TRUE)
message(paste("[INFO] JSON出力:", json_path))

dt_data <- full_data
names(dt_data)[names(dt_data) == "Freq"] <- "度数"
names(dt_data)[names(dt_data) == "Expected"] <- "期待値"
names(dt_data)[names(dt_data) == "Residual"] <- "標準残差"
names(dt_data)[names(dt_data) == "Evidence_Score"] <- "エビデンス・スコア"
names(dt_data)[names(dt_data) == "Intensity_Level"] <- "強度レベル"
for (v in cat_vars) {
  if (v %in% names(dt_data)) {
    dt_data[[v]] <- factor(dt_data[[v]], levels = sort(unique(as.character(dt_data[[v]]))))
  }
}

primary_effect_caption <- if (!is.na(effects$cramers_v)) {
  paste0(" | Cramér's V = ", effects$cramers_v)
} else if (!is.na(effects$fei)) {
  paste0(" | Fei = ", effects$fei)
} else {
  paste0(" | 効果量: 未算出 (", effects$effect_status, ")")
}

dt_widget <- datatable(
  dt_data,
  filter = "top",
  rownames = FALSE,
  caption = htmltools::tags$caption(
    style = "caption-side: top; text-align: left; font-size: 14px; font-weight: bold;",
    paste0(
      "多次元エビデンス分析: ", paste(cat_vars, collapse = " × "),
      " (N = ", format(n_total, big.mark = ","), ")",
      " | BF10(EBIC) = ", bf_str,
      " | Level1 = ", safe_round(threshold_l1, 2),
      primary_effect_caption
    )
  ),
  options = list(
    pageLength = 20,
    scrollX = TRUE,
    language = list(url = "https://cdn.datatables.net/plug-ins/1.13.6/i18n/ja.json")
  )
) |>
  formatStyle(
    "エビデンス・スコア",
    backgroundColor = styleInterval(
      c(threshold_l1, threshold_l2, threshold_l3),
      c("#fff3cd", "#ffe0b2", "#ffd180", "#d4edda")
    ),
    fontWeight = "bold"
  ) |>
  formatStyle(
    "標準残差",
    color = styleInterval(0, c("#e74c3c", "#2980b9"))
  ) |>
  formatStyle(
    "強度レベル",
    backgroundColor = styleEqual(c(0, 1, 2, 3), c("#f8f9fa", "#fff3cd", "#ffe0b2", "#d4edda"))
  ) |>
  formatRound(c("期待値", "標準残差", "エビデンス・スコア"), digits = 4)

dt_path <- file.path(artifact_dir, "dt_table.html")
saveWidget(dt_widget, dt_path, selfcontained = TRUE, libdir = NULL)
message(paste("[INFO] DTテーブル出力:", dt_path))

cat("\n=================================================================\n")
cat(" vcd-bayesian-evidence-analysis: Pass 1 完了\n")
cat("=================================================================\n")
cat(paste0(" 分析変数           : ", paste(cat_vars, collapse = " × "), "\n"))
cat(paste0(" 総度数 N           : ", format(n_total, big.mark = ","), "\n"))
cat(paste0(" セル数             : ", n_total_cells, "\n"))
cat(paste0(" threshold(Level1)  : ", safe_round(threshold_l1, 4), " (k=", cfg$threshold_k, ")\n"))
cat(paste0(" BF10 (EBIC主計算)  : ", bf_str, "  (", interpret_bf(bf_val), ")\n"))
cat(paste0(" BF10 (BIC補助)     : ", bf_bic_str, "\n"))
if (!is.na(cramers_v_val)) {
  cat(paste0(
    " Cramér's V         : ", safe_round(cramers_v_val, 4),
    " [", safe_round(cramers_v_ci_low, 4), ", ", safe_round(cramers_v_ci_high, 4), "]\n"
  ))
} else if (effect_metric == "cramers_v") {
  cat(paste0(" Cramér's V         : 未算出 (", effect_reason, ")\n"))
}
if (!is.na(fei_val)) {
  cat(paste0(
    " Fei                : ", safe_round(fei_val, 4),
    " [", safe_round(fei_ci_low, 4), ", ", safe_round(fei_ci_high, 4), "]\n"
  ))
}
if (large_sample_mode) {
  cat(" ** 大規模データモード: 効果量を優先して解釈してください **\n")
}
cat(paste0(" 実務的有意性フラグ : ", if (practical_low) "LOW" else "OK", "\n"))
cat(paste0(" ARM                : ", if (arm_result$eligible) "enabled" else "skipped", " (", arm_reason, ")\n"))
cat(paste0(
  " 正値セル           : ", n_positive, " / ", n_total_cells,
  " (", round(n_positive / n_total_cells * 100, 1), "%)\n"
))
cat("\n [出力ファイル]\n")
cat(paste0("  - ", json_path, "\n"))
cat(paste0("  - ", dt_path, "\n"))
cat("=================================================================\n")
