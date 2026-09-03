#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SKILL_DIR=$(dirname "$SCRIPT_DIR")
PROJECT_ROOT=$(cd "$SKILL_DIR/../../.." && pwd)
ANALYSIS_R="$SKILL_DIR/templates/analysis.R"
TEST_OUT="$PROJECT_ROOT/skill_out/vcd_categorical_test"

echo "[TEST] Starting verification for vcd-categorical-analysis"
echo "[TEST] Skill directory: $SKILL_DIR"
echo "[TEST] Output directory: $TEST_OUT"

if ! command -v Rscript >/dev/null 2>&1; then
  echo "Error: Rscript not found in PATH"
  exit 1
fi

rm -rf "$TEST_OUT"
mkdir -p "$TEST_OUT"

echo "[TEST] Running Pass 1 profile"
Rscript "$ANALYSIS_R" --profile --out "$TEST_OUT"
test -f "$TEST_OUT/data_profile.json"

echo "[TEST] Running Pass 2 render"
Rscript "$ANALYSIS_R" --render --out "$TEST_OUT"

required_files=(
  "data_profile_post.json"
  "summary_haireye.json"
  "residuals_haireye.csv"
  "residuals_haireye_significant.csv"
  "dt_residuals_haireye.html"
  "categorical_results.json"
)

for f in "${required_files[@]}"; do
  if [ ! -f "$TEST_OUT/$f" ]; then
    echo "Error: required file $f not found in $TEST_OUT"
    exit 1
  fi
done

echo "[SUCCESS] vcd-categorical-analysis verification passed"
