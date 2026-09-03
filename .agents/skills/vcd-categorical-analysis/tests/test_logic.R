# test_logic.R - VCD categorical analysis logic tests (§2.13)
# Run from project root: Rscript .agent/skills/vcd-categorical-analysis/tests/test_logic.R

suppressMessages({
  if (!requireNamespace("pacman", quietly = TRUE)) install.packages("pacman", repos = "https://cloud.r-project.org")
  pacman::p_load(jsonlite)
})

PASS <- 0L
FAIL <- 0L

assert <- function(cond, msg) {
  if (isTRUE(cond)) {
    cat(sprintf("  [PASS] %s\n", msg))
    PASS <<- PASS + 1L
  } else {
    cat(sprintf("  [FAIL] %s\n", msg))
    FAIL <<- FAIL + 1L
  }
}

# ============================================================
# Source analysis.R in a local env so global state is isolated
# ============================================================
script_dir <- normalizePath(file.path(dirname(sys.frame(1)$ofile), ".."), mustWork = FALSE)
if (!nchar(script_dir)) script_dir <- normalizePath(file.path(getwd(), ".agent/skills/vcd-categorical-analysis"))
analysis_path <- file.path(script_dir, "templates", "analysis.R")

if (!file.exists(analysis_path)) {
  stop("[ERROR] analysis.R not found at: ", analysis_path,
       "\nRun from project root: Rscript .agent/skills/vcd-categorical-analysis/tests/test_logic.R")
}

# Source into a local environment to avoid polluting global
local_env <- new.env(parent = globalenv())
local_env$args <- character(0)  # suppress main dispatcher execution
suppressMessages(source(analysis_path, local = local_env))

validate_config <- local_env$validate_config
apply_aggregation <- local_env$apply_aggregation
generate_profile  <- local_env$generate_profile
generate_plots    <- local_env$generate_plots

# ============================================================
# Test 1: validate_config - 空 config のデフォルト値
# ============================================================
cat("[TEST 1] validate_config - empty config defaults\n")
cfg <- validate_config(list())
assert(cfg$collapse_below_n == 0L, "collapse_below_n default = 0")
assert(cfg$max_levels_per_var == 999L, "max_levels_per_var default = 999")
assert(cfg$plot_mode == "auto", "plot_mode default = 'auto'")
assert(identical(cfg$gt_matrix_vars, c(1L, 2L)), "gt_matrix_vars default = c(1,2)")
assert(identical(cfg$strata_to_render, character(0)), "strata_to_render default = character(0)")

# ============================================================
# Test 2: validate_config - 不正な型はデフォルト値にフォールバック
# ============================================================
cat("[TEST 2] validate_config - invalid type fallback\n")
cfg2 <- validate_config(list(collapse_below_n = "not_number", plot_mode = "invalid_mode"))
assert(cfg2$collapse_below_n == 0L, "non-numeric collapse_below_n falls back to 0")
assert(cfg2$plot_mode == "auto", "invalid plot_mode falls back to 'auto'")

# ============================================================
# Test 3: validate_config - 有効な値
# ============================================================
cat("[TEST 3] validate_config - valid values\n")
cfg3 <- validate_config(list(
  collapse_below_n = 5,
  max_levels_per_var = 8,
  plot_mode = "always",
  strata_to_render = list("A", "B"),
  gt_matrix_vars = list(1, 3)
))
assert(cfg3$collapse_below_n == 5L, "collapse_below_n = 5")
assert(cfg3$max_levels_per_var == 8L, "max_levels_per_var = 8")
assert(cfg3$plot_mode == "always", "plot_mode = 'always'")
assert(length(cfg3$strata_to_render) == 2, "strata_to_render length = 2")
assert(identical(cfg3$gt_matrix_vars, c(1L, 3L)), "gt_matrix_vars = c(1,3)")

# ============================================================
# Test 4: validate_config - 未知キーは警告して無視
# ============================================================
cat("[TEST 4] validate_config - unknown keys ignored\n")
msgs <- capture.output(cfg4 <- validate_config(list(unknown_key = 99, collapse_below_n = 3)), type = "message")
assert(cfg4$collapse_below_n == 3L, "known key is applied")
assert(any(grepl("Unknown config keys", msgs)), "WARNING for unknown key emitted")
assert(!("unknown_key" %in% names(cfg4)), "unknown_key not in cfg")

# ============================================================
# Test 5: apply_aggregation - collapse_below_n
# ============================================================
cat("[TEST 5] apply_aggregation - collapse_below_n\n")
df5 <- data.frame(
  A = c("x", "y", "z", "w", "x", "y", "z", "w"),
  B = c("1", "1", "1", "1", "2", "2", "2", "2"),
  Freq = c(10, 2, 1, 1, 10, 2, 1, 1),
  stringsAsFactors = FALSE
)
for (v in c("A", "B")) df5[[v]] <- factor(df5[[v]])
cfg5 <- list(collapse_below_n = 2L, max_levels_per_var = 999L)
df5_agg <- apply_aggregation(df5, c("A", "B"), "Freq", cfg5)
# z (合計2<=2) と w (合計2<=2) は "Other" にまとめられるはず
assert("Other" %in% levels(df5_agg$A), "minor levels collapsed to 'Other'")
assert(!("z" %in% levels(df5_agg$A)), "level 'z' removed")
assert(!("w" %in% levels(df5_agg$A)), "level 'w' removed")

# ============================================================
# Test 6: apply_aggregation - max_levels_per_var
# ============================================================
cat("[TEST 6] apply_aggregation - max_levels_per_var\n")
df6 <- data.frame(
  A = letters[1:6],
  B = rep("1", 6),
  Freq = c(100, 80, 60, 40, 3, 2),
  stringsAsFactors = FALSE
)
for (v in c("A", "B")) df6[[v]] <- factor(df6[[v]])
cfg6 <- list(collapse_below_n = 0L, max_levels_per_var = 4L)
df6_agg <- apply_aggregation(df6, c("A", "B"), "Freq", cfg6)
assert(nlevels(df6_agg$A) <= 5, "levels <= max_levels_per_var + 1 (Other)")
assert("Other" %in% levels(df6_agg$A), "'Other' added for excess levels")

# ============================================================
# Test 7: generate_profile Pass 1 - data_profile.json の生成
# ============================================================
cat("[TEST 7] generate_profile - Pass 1 (data_profile.json)\n")
tmp_dir7 <- tempfile()
dir.create(tmp_dir7, recursive = TRUE)

data("HairEyeColor", package = "datasets")
df7 <- as.data.frame(HairEyeColor)
for (v in c("Hair", "Eye", "Sex")) df7[[v]] <- factor(df7[[v]])

generate_profile(df7, c("Hair", "Eye", "Sex"), "Freq", tmp_dir7,
                 config = NULL, out_filename = "data_profile.json")
p7_path <- file.path(tmp_dir7, "data_profile.json")
assert(file.exists(p7_path), "data_profile.json exists")

p7 <- jsonlite::read_json(p7_path)
assert(!is.null(p7$n_dimensions), "n_dimensions present")
assert(!is.null(p7$variables), "variables present")
assert(!is.null(p7$sparsity_ratio), "sparsity_ratio present")
assert(p7$n_dimensions == 3, "n_dimensions = 3")

# ============================================================
# Test 8: generate_profile Pass 2 - data_profile_post.json の生成（集約後）
# ============================================================
cat("[TEST 8] generate_profile - Pass 2 (data_profile_post.json)\n")
tmp_dir8 <- tempfile()
dir.create(tmp_dir8, recursive = TRUE)

cfg8 <- list(collapse_below_n = 0L, max_levels_per_var = 999L)
df8_agg <- apply_aggregation(df7, c("Hair", "Eye", "Sex"), "Freq", cfg8)
generate_profile(df8_agg, c("Hair", "Eye", "Sex"), "Freq", tmp_dir8,
                 config = NULL, out_filename = "data_profile_post.json")
p8_path <- file.path(tmp_dir8, "data_profile_post.json")
assert(file.exists(p8_path), "data_profile_post.json exists")

# ============================================================
# Test 9: generate_plots - plot_mode = "residual_only" で PNG が出ない
# ============================================================
cat("[TEST 9] generate_plots - residual_only skips PNG\n")
tmp_dir9 <- tempfile()
dir.create(tmp_dir9, recursive = TRUE)

tab9 <- xtabs(Freq ~ Hair + Eye, data = df7)
cfg9 <- list(plot_mode = "residual_only")
suppressMessages(generate_plots(tab9, c("Hair", "Eye"), tmp_dir9, cfg9, "test9"))

png_files <- list.files(tmp_dir9, pattern = "\\.png$")
assert(length(png_files) == 0, "no PNG files generated for residual_only mode")

# ============================================================
# Test 10: generate_plots - plot_mode = "auto" でセル数オーバーなら PNG が出ない
# ============================================================
cat("[TEST 10] generate_plots - auto skips when cells > threshold\n")
tmp_dir10 <- tempfile()
dir.create(tmp_dir10, recursive = TRUE)

# HairEyeColor の 3-way: 4*4*2=32 < 36 なのでプロットされる可能性があるが、
# ラベル長は "Black"=5 等なので threshold_cells でのチェックのみ確認
# 人工的に大きな表を作る（5x5x2=50 > 36）
df10 <- expand.grid(A = letters[1:5], B = LETTERS[1:5], C = c("p", "q"))
df10$Freq <- sample(1:10, nrow(df10), replace = TRUE)
tab10 <- xtabs(Freq ~ A + B + C, data = df10)
cfg10 <- list(plot_mode = "auto")
suppressMessages(generate_plots(tab10, c("A", "B", "C"), tmp_dir10, cfg10, "test10"))

png_files10 <- list.files(tmp_dir10, pattern = "\\.png$")
assert(length(png_files10) == 0, "no PNG files for 3-way with cells > 36 in auto mode")

# ============================================================
# Summary
# ============================================================
cat(sprintf("\n==== Test Summary: %d passed, %d failed ====\n", PASS, FAIL))
if (FAIL > 0) quit(status = 1) else quit(status = 0)
