`%||%` <- function(x, y) if (is.null(x)) y else x
safe_num <- function(x) if (is.null(x) || length(x) == 0 || is.na(x)) NA_real_ else as.numeric(x)
safe_round <- function(x, digits = 4) ifelse(is.na(x), NA_real_, round(as.numeric(x), digits))

sanitize_run_slug <- function(x) {
  if (is.null(x)) {
    return(NULL)
  }
  if (length(x) < 1L) {
    stop("[ERROR] 無効な --run-id です")
  }
  x <- as.character(x)[1]
  if (is.na(x) || !nzchar(trimws(x))) {
    stop("[ERROR] 無効な --run-id です")
  }
  x <- trimws(x)
  if (tolower(x) == "auto") {
    return(format(Sys.time(), "%Y%m%d_%H%M%S", tz = "Asia/Tokyo"))
  }
  x <- gsub("[/\\\\]", "_", x)
  x <- gsub("^\\.+|\\.+$", "", x)
  if (!nzchar(x)) {
    stop("[ERROR] 無効な --run-id です")
  }
  x
}

interpret_bf <- function(bf) {
  if (is.infinite(bf) || bf > 100) {
    return("決定的エビデンス (decisive)")
  }
  if (bf > 30) {
    return("非常に強いエビデンス (very strong)")
  }
  if (bf > 10) {
    return("強いエビデンス (strong)")
  }
  if (bf > 3) {
    return("中程度のエビデンス (moderate)")
  }
  if (bf > 1) {
    return("弱いエビデンス (anecdotal)")
  }
  "関連なし / 独立仮説を支持"
}

compute_ebic <- function(model, n_total, p_total, gamma) {
  ll <- as.numeric(stats::logLik(model))
  k <- attr(stats::logLik(model), "df")
  p_for_choose <- max(as.integer(round(p_total)), as.integer(k))
  comb_term <- if (p_for_choose <= 0 || k <= 0 || p_for_choose == k) 0 else lchoose(p_for_choose, k)
  -2 * ll + k * log(n_total) + 2 * gamma * comb_term
}

compute_arm_rules <- function(df_items, weight_col, cat_vars, top_n, min_support, min_conf) {
  if (length(cat_vars) < 2L) {
    return(list(eligible = FALSE, reason = "分析変数が1つのためARM対象外", top_rules = data.frame()))
  }

  dt <- df_items
  dt[cat_vars] <- lapply(dt[cat_vars], as.character)
  dt[[weight_col]] <- as.numeric(dt[[weight_col]])
  dt <- dt[!is.na(dt[[weight_col]]) & dt[[weight_col]] > 0, , drop = FALSE]
  total_w <- sum(dt[[weight_col]])
  if (!is.finite(total_w) || total_w <= 0) {
    return(list(eligible = FALSE, reason = "ARM重み総和が0以下", top_rules = data.frame()))
  }

  out <- list()
  idx <- 1L
  for (lhs_var in cat_vars) {
    for (rhs_var in setdiff(cat_vars, lhs_var)) {
      lhs_vals <- unique(dt[[lhs_var]])
      rhs_vals <- unique(dt[[rhs_var]])
      for (lv in lhs_vals) {
        lhs_mask <- dt[[lhs_var]] == lv
        lhs_w <- sum(dt[[weight_col]][lhs_mask])
        if (lhs_w <= 0) next
        for (rv in rhs_vals) {
          rhs_mask <- dt[[rhs_var]] == rv
          pair_w <- sum(dt[[weight_col]][lhs_mask & rhs_mask])
          if (pair_w <= 0) next
          support <- pair_w / total_w
          confidence <- pair_w / lhs_w
          rhs_w <- sum(dt[[weight_col]][rhs_mask])
          rhs_prob <- rhs_w / total_w
          lift <- if (rhs_prob <= 0) NA_real_ else confidence / rhs_prob
          if (!is.na(support) && !is.na(confidence) &&
            support >= min_support && confidence >= min_conf) {
            out[[idx]] <- data.frame(
              lhs = paste0(lhs_var, "=", lv),
              rhs = paste0(rhs_var, "=", rv),
              support = support,
              confidence = confidence,
              lift = lift,
              weighted_count = pair_w,
              stringsAsFactors = FALSE
            )
            idx <- idx + 1L
          }
        }
      }
    }
  }

  if (length(out) == 0L) {
    return(list(
      eligible = TRUE,
      reason = "条件を満たすルールなし",
      top_rules = data.frame(
        lhs = character(), rhs = character(),
        support = numeric(), confidence = numeric(),
        lift = numeric(), weighted_count = numeric()
      )
    ))
  }

  rules <- dplyr::bind_rows(out) %>%
    dplyr::arrange(dplyr::desc(lift), dplyr::desc(confidence), dplyr::desc(support)) %>%
    dplyr::mutate(
      support = safe_round(support, 4),
      confidence = safe_round(confidence, 4),
      lift = safe_round(lift, 4),
      weighted_count = safe_round(weighted_count, 4)
    )

  list(
    eligible = TRUE,
    reason = "OK",
    top_rules = head(rules, top_n)
  )
}
