# analysis_config.json validation for vcd-bayesian-evidence-analysis.

analysis_config_allowed_keys <- c(
  "input", "vars", "freq", "output_dir", "run_id", "dataset_name",
  "response_var",
  "top_k", "threshold_k", "large_n_threshold", "ebic_gamma", "ebic_p",
  "level2_factor", "level3_factor", "arm_top_rules", "arm_min_support",
  "arm_min_confidence"
)

analysis_config_required_keys <- c("input", "vars", "freq", "output_dir", "run_id")

resolve_analysis_config_path <- function(path, config_path = NULL, repo_root = NULL) {
  candidates <- path
  if (!is.null(repo_root) && nzchar(repo_root)) {
    candidates <- c(candidates, file.path(repo_root, path))
  }
  if (!is.null(config_path) && nzchar(config_path)) {
    candidates <- c(candidates, file.path(dirname(config_path), path))
  }
  for (candidate in unique(candidates)) {
    if (file.exists(candidate)) {
      return(normalizePath(candidate, winslash = "/", mustWork = TRUE))
    }
  }
  path
}

is_nonempty_scalar_string <- function(value) {
  is.character(value) && length(value) == 1L && !is.na(value) && nzchar(value)
}

is_nonempty_string_vector <- function(value) {
  is.character(value) && length(value) >= 1L && all(!is.na(value)) && all(nzchar(value))
}

is_finite_number <- function(value) {
  is.numeric(value) && length(value) == 1L && is.finite(value)
}

is_positive_integerish <- function(value) {
  isTRUE(is_finite_number(value) && value >= 1 && floor(value) == value && value <= .Machine$integer.max)
}

validate_analysis_config <- function(config_data, config_path = NULL, repo_root = NULL) {
  errors <- character()

  if (!is.list(config_data) || is.data.frame(config_data)) {
    stop("[ERROR] analysis_config.json は JSON object である必要があります。", call. = FALSE)
  }

  missing_keys <- setdiff(analysis_config_required_keys, names(config_data))
  if (length(missing_keys) > 0L) {
    errors <- c(errors, paste0("必須キーがありません: ", paste(missing_keys, collapse = ", ")))
  }

  unknown_keys <- setdiff(names(config_data), analysis_config_allowed_keys)
  if (length(unknown_keys) > 0L) {
    message("[WARN] analysis_config.json の未知キーを無視せず読み込みます: ", paste(unknown_keys, collapse = ", "))
  }

  scalar_string_keys <- c("input", "freq", "output_dir", "run_id", "dataset_name", "response_var")
  for (key in intersect(scalar_string_keys, names(config_data))) {
    if (!is_nonempty_scalar_string(config_data[[key]])) {
      errors <- c(errors, paste0(key, " は空でない文字列である必要があります。"))
    }
  }

  if ("vars" %in% names(config_data) && !is_nonempty_string_vector(config_data$vars)) {
    errors <- c(errors, "vars は空でない文字列配列である必要があります。")
  }

  integer_keys <- c("top_k", "large_n_threshold", "arm_top_rules")
  for (key in intersect(integer_keys, names(config_data))) {
    if (!is_positive_integerish(config_data[[key]])) {
      errors <- c(errors, paste0(key, " は正の整数である必要があります。"))
    }
  }

  numeric_keys <- c(
    "threshold_k", "ebic_gamma", "ebic_p", "level2_factor", "level3_factor",
    "arm_min_support", "arm_min_confidence"
  )
  for (key in intersect(numeric_keys, names(config_data))) {
    if (!is_finite_number(config_data[[key]])) {
      errors <- c(errors, paste0(key, " は有限の数値である必要があります。"))
    }
  }

  resolved_input <- NULL
  if ("input" %in% names(config_data) && is_nonempty_scalar_string(config_data$input)) {
    resolved_input <- resolve_analysis_config_path(config_data$input, config_path, repo_root)
    if (!file.exists(resolved_input)) {
      errors <- c(errors, paste0("input が見つかりません: ", config_data$input))
    }
  }

  if (!is.null(resolved_input) && file.exists(resolved_input)) {
    header <- tryCatch(
      names(utils::read.csv(resolved_input, nrows = 0L, stringsAsFactors = FALSE, fileEncoding = "UTF-8")),
      error = function(e) {
        errors <<- c(errors, paste0("input CSV を読めません: ", e$message))
        NULL
      }
    )
    if (!is.null(header)) {
      if ("vars" %in% names(config_data) && is_nonempty_string_vector(config_data$vars)) {
        missing_vars <- setdiff(config_data$vars, header)
        if (length(missing_vars) > 0L) {
          errors <- c(errors, paste0("vars に input CSV に存在しない列があります: ", paste(missing_vars, collapse = ", ")))
        }
      }
      if ("freq" %in% names(config_data) && is_nonempty_scalar_string(config_data$freq) && !(config_data$freq %in% header)) {
        errors <- c(errors, paste0("freq が input CSV に存在しません: ", config_data$freq))
      }
      if ("response_var" %in% names(config_data) && is_nonempty_scalar_string(config_data$response_var)) {
        if (!(config_data$response_var %in% header)) {
          errors <- c(errors, paste0("response_var が input CSV に存在しません: ", config_data$response_var))
        }
        if ("vars" %in% names(config_data) && is_nonempty_string_vector(config_data$vars) &&
          !(config_data$response_var %in% config_data$vars)) {
          errors <- c(errors, paste0("response_var は vars に含める必要があります: ", config_data$response_var))
        }
      }
    }
  }

  if (length(errors) > 0L) {
    stop(
      paste(c("[ERROR] analysis_config.json の検証に失敗しました。", paste0("- ", errors)), collapse = "\n"),
      call. = FALSE
    )
  }

  invisible(list(input = resolved_input))
}
