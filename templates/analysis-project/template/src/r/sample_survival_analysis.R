# ==============================================================================
# Sample R Survival & Statistical Analysis (UTF-8)
# ==============================================================================

suppressPackageStartupMessages({
  library(survival)
})

# プロジェクトルートパスの解決
find_project_root <- function() {
  curr <- getwd()
  while (!file.exists(file.path(curr, "PROJECT.yml")) && dirname(curr) != curr) {
    curr <- dirname(curr)
  }
  return(curr)
}

root_dir <- find_project_root()
synthetic_file <- file.path(root_dir, "data", "synthetic", "synthetic_cohort.csv")
out_private <- file.path(root_dir, "outputs", "private")
dir.create(out_private, recursive = TRUE, showWarnings = FALSE)

if (file.exists(synthetic_file)) {
  message(sprintf("[INFO] Reading synthetic data: %s", synthetic_file))
  cohort <- read.csv(synthetic_file, stringsAsFactors = FALSE)
} else {
  message("[WARN] Synthetic data not found. Creating sample dataset.")
  set.seed(42)
  n <- 100
  cohort <- data.frame(
    patient_id = sprintf("SYNTH_%04d", 1:n),
    age = round(rnorm(n, mean = 60, sd = 10)),
    sex = sample(c("M", "F"), n, replace = TRUE),
    treatment_arm = sample(c("Control", "Active"), n, replace = TRUE),
    followup_days = round(runif(n, min = 30, max = 730)),
    event_occurred = rbinom(n, size = 1, prob = 0.25)
  )
}

# 生存時間解析 (Kaplan-Meier & Log-rank test)
fit <- survfit(Surv(followup_days, event_occurred) ~ treatment_arm, data = cohort)
diff_test <- survdiff(Surv(followup_days, event_occurred) ~ treatment_arm, data = cohort)

message("\n=== Survival Analysis Summary ===")
print(summary(fit))
print(diff_test)

# 中間ログの保存
sink(file.path(out_private, "r_survival_summary.txt"))
cat("=== Survival Model Fit ===\n")
print(summary(fit))
cat("\n=== Log-rank Test ===\n")
print(diff_test)
sink()
message("[INFO] R analysis completed successfully.")
