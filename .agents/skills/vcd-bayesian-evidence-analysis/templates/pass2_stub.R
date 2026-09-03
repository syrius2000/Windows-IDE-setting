#!/usr/bin/env Rscript
# pass2_stub.R - LLM未使用でexecutive_summary.mdの骨子（スタブ）を生成する
suppressPackageStartupMessages(library(jsonlite))

args <- commandArgs(trailingOnly = TRUE)
json_path <- "evidence_results.json"
out_path <- NULL
run_dir <- NULL

i <- 1
while (i <= length(args)) {
  if (args[i] == "--json" && i < length(args)) {
    json_path <- args[i + 1]
    i <- i + 2
  } else if (args[i] == "--output" && i < length(args)) {
    out_path <- args[i + 1]
    i <- i + 2
  } else if (args[i] == "--run-dir" && i < length(args)) {
    run_dir <- args[i + 1]
    i <- i + 2
  } else {
    i <- i + 1
  }
}

if (!is.null(run_dir) && !file.exists(json_path)) {
  json_path <- file.path(run_dir, "evidence_results.json")
}

if (!file.exists(json_path)) {
  stop("Error: JSON file not found: ", json_path, " (Pass1 の run_output_dir か --run-dir を確認してください)")
}

if (is.null(out_path) || !nzchar(out_path)) {
  out_path <- file.path(dirname(normalizePath(json_path, winslash = "/", mustWork = TRUE)), "executive_summary.md")
}

res <- jsonlite::fromJSON(json_path)

md_lines <- c(
  "### エグゼクティブ・サマリー（スタブ生成：LLM未使用）",
  "",
  "> **注意**: 本レポートはCIまたはローカルテスト用のスタブ（プレースホルダー）です。LLMによる考察は含まれていません。",
  "",
  "#### 1. データ概要",
  sprintf("- **データセット名**: %s", ifelse(is.null(res$dataset_name), "Unknown", res$dataset_name)),
  sprintf("- **分析次元**: %s", paste(res$dimensions, collapse = " × ")),
  sprintf("- **総度数 (N)**: %s", format(res$n_total, big.mark = ",")),
  ""
)

if (!is.null(res$bf_independence)) {
  md_lines <- c(md_lines,
    "#### 2. 全体的な関連性（ベイズファクター）",
    sprintf("- **BF10**: %s", res$bf_independence),
    ""
  )
}

if (!is.null(res$cramers_v)) {
  effect_status <- if (!is.null(res$effect_status)) res$effect_status else res$effects$effect_status
  effect_reason <- if (!is.null(res$effect_reason)) res$effect_reason else res$effects$effect_reason
  if (!is.na(res$cramers_v)) {
    cram_str <- sprintf("- **Cramér's V（全体効果量）**: %.4f", res$cramers_v)
    if (!is.null(res$cramers_v_ci_low) && !is.null(res$cramers_v_ci_high) &&
      !is.na(res$cramers_v_ci_low) && !is.na(res$cramers_v_ci_high)) {
      cram_str <- paste0(cram_str, sprintf(" (95%% CI: %.4f - %.4f)", res$cramers_v_ci_low, res$cramers_v_ci_high))
    }
  } else {
    cram_str <- sprintf("- **Cramér's V（全体効果量）**: 未算出（%s: %s）", effect_status, effect_reason)
  }
  md_lines <- c(md_lines,
    "#### 3. 効果量 (Dual-Filter)",
    cram_str,
    "- **注**: Cramér's V はセル単位ではなく表全体の効果量です。セル単位の偏りは Residual / Evidence Score で確認します。",
    ""
  )
}

if (!is.null(res$warnings) && length(res$warnings) > 0) {
  md_lines <- c(md_lines,
    "**警告事項**:",
    paste("-", res$warnings),
    ""
  )
}

if (!is.null(res$top_k_data) && is.data.frame(res$top_k_data) && nrow(res$top_k_data) > 0) {
  md_lines <- c(md_lines,
    "#### 4. 主要な偏りセル (Top-K)",
    "以下のセルが強い偏り（Evidence Score > 0）を示しました："
  )
  for (i in seq_len(nrow(res$top_k_data))) {
    row <- res$top_k_data[i, ]
    cell_desc <- paste(sapply(res$dimensions, function(d) paste0(d, "=", row[[d]])), collapse = ", ")
    md_lines <- c(md_lines, sprintf("- %d. %s (Score: %.2f, Residual: %.2f)", i, cell_desc, row$Evidence_Score, row$Residual))
  }
  md_lines <- c(md_lines, "")
}

writeLines(enc2utf8(md_lines), out_path, useBytes = FALSE)
cat(sprintf("Stub summary written to %s\n", out_path))
