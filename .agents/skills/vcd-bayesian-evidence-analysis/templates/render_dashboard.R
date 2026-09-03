#!/usr/bin/env Rscript
# Pass 3: dashboard.html を evidence_results.json と同じ run_<prefix>/ に出力する（run_output_dir_from_root と同規則）。
# params$output_dir は Pass 1 と同じ out_root（run の親）を渡すこと。

suppressPackageStartupMessages({
  if (!requireNamespace("pacman", quietly = TRUE)) {
    utils::install.packages("pacman", repos = "https://cloud.r-project.org")
  }
  pacman::p_load(rmarkdown)
})

args <- commandArgs(trailingOnly = TRUE)

if (any(args %in% c("-h", "--help"))) {
  cat("Usage: Rscript render_dashboard.R --output_dir <Pass1 の out_root> [OPTIONS]

Options:
  --output_dir <path>   Pass 1 で --output_dir に指定したディレクトリ（必須）
  --rmd <path>          dashboard.Rmd（省略時は本スクリプトと同じ templates/ 内）
  --no-require-pass2    executive_summary.md なしでもレンダー（プレビュー専用）
")
  quit(status = 0L)
}

require_pass2 <- !("--no-require-pass2" %in% args)
args <- args[!args %in% "--no-require-pass2"]

out_root_arg <- NULL
rmd_arg <- NULL
i <- 1L
while (i <= length(args)) {
  if (identical(args[i], "--output_dir") && i < length(args)) {
    out_root_arg <- args[i + 1L]
    i <- i + 2L
  } else if (identical(args[i], "--rmd") && i < length(args)) {
    rmd_arg <- args[i + 1L]
    i <- i + 2L
  } else {
    i <- i + 1L
  }
}

if (is.null(out_root_arg) || !nzchar(out_root_arg)) {
  stop("必須: --output_dir <Pass1 の out_root>", call. = FALSE)
}

caf <- grep("^--file=", commandArgs(), value = TRUE)
if (length(caf)) {
  sp <- sub("^--file=", "", caf[[length(caf)]])
  script_dir <- normalizePath(dirname(sp), winslash = "/", mustWork = TRUE)
} else {
  script_dir <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
}

find_repo_root <- function() {
  d <- script_dir
  for (k in seq_len(24L)) {
    if (file.exists(file.path(d, ".agent", "shared", "run_scope.R"))) {
      return(normalizePath(d, winslash = "/", mustWork = TRUE))
    }
    if (identical(basename(d), ".agent") && file.exists(file.path(d, "shared", "run_scope.R"))) {
      return(normalizePath(dirname(d), winslash = "/", mustWork = TRUE))
    }
    parent <- dirname(d)
    if (identical(parent, d)) {
      break
    }
    d <- parent
  }
  stop("リポジトリルートを特定できません（.agent/shared/run_scope.R が見つかりません）", call. = FALSE)
}

repo_root <- find_repo_root()
source(file.path(repo_root, ".agent", "shared", "run_scope.R"))

out_root <- normalizePath(out_root_arg, winslash = "/", mustWork = FALSE)
if (!dir.exists(out_root)) {
  stop("output_dir が存在しません: ", out_root, call. = FALSE)
}

rs <- resolve_pass3_run_dir(out_root, "evidence_results.json")
run_dir <- rs$run_dir

rmd_path <- if (!is.null(rmd_arg) && nzchar(rmd_arg)) {
  normalizePath(rmd_arg, winslash = "/", mustWork = TRUE)
} else {
  normalizePath(file.path(script_dir, "dashboard.Rmd"), winslash = "/", mustWork = TRUE)
}
if (!file.exists(rmd_path)) {
  stop("dashboard.Rmd が見つかりません: ", rmd_path, call. = FALSE)
}

message("[INFO] Pass 3 レンダリング: ", rmd_path)
message("[INFO] params$output_dir (out_root): ", out_root)
message("[INFO] HTML 出力先 (run_dir): ", run_dir)

rmarkdown::render(
  input = rmd_path,
  output_file = "dashboard.html",
  output_dir = run_dir,
  params = list(output_dir = out_root, require_pass2 = require_pass2),
  knit_root_dir = repo_root,
  quiet = FALSE
)

out_html <- file.path(run_dir, "dashboard.html")
if (!file.exists(out_html)) {
  stop("[ERROR] 期待パスに dashboard.html がありません: ", out_html, call. = FALSE)
}
message("[INFO] 生成: ", out_html)
