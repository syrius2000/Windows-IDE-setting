#!/usr/bin/env bash
# new-analysis-project.sh - Case Project Factory for macOS / Linux
# Creates an independent, standardized RWD Case Project Git repository using Copier.

set -euo pipefail

NAME="${1:-}"
PROFILE="${2:-mac-rwd-expert}"
DATA_CLASS="${3:-deidentified}"
PRIMARY_LANG="${4:-python}"
SAS_ENCODING="${5:-none}"
DESTINATION_ROOT="${6:-$HOME/Programing/RWD-Projects}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLATFORM_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEMPLATE_DIR="$PLATFORM_ROOT/templates/analysis-project"

if [[ -z "$NAME" ]]; then
    echo "========================================================"
    echo "  新規 RWD 解析プロジェクト (Case Project) 作成ガイド (macOS)"
    echo "========================================================"
    echo ""
    echo "【1】プロジェクト名を入力してください（小文字英数字・ハイフン）"
    read -p "  プロジェクト名 [既定: urology]: " RAW_NAME
    RAW_NAME="${RAW_NAME:-urology}"
    
    CLEAN_NAME=$(echo "$RAW_NAME" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9-]+/-/g')
    if [[ ! "$CLEAN_NAME" =~ ^case- ]]; then
        CLEAN_NAME="case-$CLEAN_NAME"
    fi
    NAME="$CLEAN_NAME"
    echo "  -> 設定された名前: $NAME"
    echo ""

    echo "【2】主に使用する解析言語を選択してください"
    echo "  1) Python (推奨・標準環境)"
    echo "  2) R      (推奨・統計環境)"
    echo "  3) SAS    (CP932文字コード・既存SAS資産併用)"
    read -p "  選択 [1-3] (既定: 1): " LANG_CHOICE
    case "$LANG_CHOICE" in
        2) PRIMARY_LANG="r"; SAS_ENCODING="none" ;;
        3) PRIMARY_LANG="sas"; SAS_ENCODING="cp932" ;;
        *) PRIMARY_LANG="python"; SAS_ENCODING="none" ;;
    esac
    echo "  -> 解析言語: $PRIMARY_LANG"
    echo ""

    echo "【3】扱うデータのセキュリティ区分を選択してください"
    echo "  1) deidentified (匿名化データ・標準)"
    echo "  2) synthetic    (テスト用合成データ)"
    echo "  3) sensitive    (高セキュリティ機微データ)"
    read -p "  選択 [1-3] (既定: 1): " DATA_CHOICE
    case "$DATA_CHOICE" in
        2) DATA_CLASS="synthetic" ;;
        3) DATA_CLASS="sensitive" ;;
        *) DATA_CLASS="deidentified" ;;
    esac
    echo "  -> データ区分: $DATA_CLASS"
    echo ""
else
    CLEAN_NAME=$(echo "$NAME" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9-]+/-/g')
    if [[ ! "$CLEAN_NAME" =~ ^case- ]]; then
        CLEAN_NAME="case-$CLEAN_NAME"
    fi
    NAME="$CLEAN_NAME"
fi

if [[ ! "$NAME" =~ ^case-[a-z0-9-]+$ ]]; then
    echo "[ERROR] Project name must match pattern: ^case-[a-z0-9-]+$ (e.g. case-pompe-disease)"
    exit 1
fi

echo "========================================================"
echo "  RWD Case Project Factory (Copier Generator - macOS)"
echo "========================================================"
echo "  Project Name:        $NAME"
echo "  Profile:             $PROFILE"
echo "  Data Classification: $DATA_CLASS"
echo "  Primary Language:    $PRIMARY_LANG (SAS Encoding: $SAS_ENCODING)"
echo "  Destination Root:    $DESTINATION_ROOT"
echo "========================================================"

# 1. Validation of Prerequisites
if [[ ! -d "$TEMPLATE_DIR" ]]; then
    echo "[ERROR] Template directory not found at: $TEMPLATE_DIR"
    exit 1
fi

# 2. Destination Directory Checks & Conflict Prevention
mkdir -p "$DESTINATION_ROOT"
TARGET_DIR="$DESTINATION_ROOT/$NAME"

if [[ -d "$TARGET_DIR" && "$(ls -A "$TARGET_DIR")" ]]; then
    echo "[ERROR] Target directory already exists and is not empty: $TARGET_DIR"
    exit 1
fi
mkdir -p "$TARGET_DIR"

cleanup() {
    if [[ -d "$TARGET_DIR" ]]; then
        echo -e "\n[ROLLBACK] Cleaning up failed generation directory: $TARGET_DIR"
        rm -rf "$TARGET_DIR"
    fi
}
trap cleanup ERR

# 3. Execute Copier Generation
echo -e "\n[1/6] Generating project scaffold with Copier..."
if command -v copier >/dev/null 2>&1; then
    copier copy "$TEMPLATE_DIR" "$TARGET_DIR" \
        --defaults \
        --trust \
        -d "project_id=$NAME" \
        -d "project_title=$NAME" \
        -d "profile=$PROFILE" \
        -d "data_classification=$DATA_CLASS" \
        -d "primary_language=$PRIMARY_LANG" \
        -d "sas_encoding=$SAS_ENCODING"
elif command -v uvx >/dev/null 2>&1; then
    uvx --from "copier==9.4.1" copier copy "$TEMPLATE_DIR" "$TARGET_DIR" \
        --defaults \
        --trust \
        -d "project_id=$NAME" \
        -d "project_title=$NAME" \
        -d "profile=$PROFILE" \
        -d "data_classification=$DATA_CLASS" \
        -d "primary_language=$PRIMARY_LANG" \
        -d "sas_encoding=$SAS_ENCODING"
else
    echo "[ERROR] Neither 'copier' nor 'uvx' found in PATH. Please run setup first."
    exit 1
fi

# 4. Copy validation & wrapper scripts to Case Project
mkdir -p "$TARGET_DIR/scripts"
cp "$PLATFORM_ROOT/scripts/project/validate-project.py" "$TARGET_DIR/scripts/validate-project.py"
chmod +x "$TARGET_DIR/scripts/validate-project.py"

# Copy repository-managed skills; .agents/skills is canonical.
if [[ -d "$PLATFORM_ROOT/.agents/skills" ]]; then
    mkdir -p "$TARGET_DIR/.agents/skills"
    cp -R "$PLATFORM_ROOT/.agents/skills/." "$TARGET_DIR/.agents/skills/"
    echo "[OK] Repository skills automatically deployed to .agents/skills."
else
    echo "[INFO] No repository-managed .agents/skills found; skipping skill copy."
fi

# 5. Integrity & Governance Validation (via uv run python or fallback)
echo "[2/6] Validating Project Schema & Directory Governance..."
SCHEMA_PATH="$PLATFORM_ROOT/schemas/project.schema.json"
if command -v uv >/dev/null 2>&1; then
    uv run --with jsonschema --with pyyaml python "$TARGET_DIR/scripts/validate-project.py" --project-dir "$TARGET_DIR" --schema "$SCHEMA_PATH"
else
    python3 "$TARGET_DIR/scripts/validate-project.py" --project-dir "$TARGET_DIR" --schema "$SCHEMA_PATH"
fi

# 6. Preview Summary
echo -e "\n[3/6] Project Generated Successfully:"
echo "  - Root: $TARGET_DIR"
echo "  - Structure: src/, sql/, reports/, outputs/private/, outputs/release/"
echo "  - Governance: PROJECT.yml, .cursor/rules/, .agents/skills/, .pre-commit-config.yaml, .gitignore, tasks.json"

# 7. User Confirmation for Git Initialization
read -r -p "Do you want to initialize Git and open in Cursor? (Y/n): " response || response="y"
response="${response,,}" # tolower

if [[ "$response" != "n" ]]; then
    echo -e "\n[4/6] Initializing local Git repository..."
    cd "$TARGET_DIR"
    git init >/dev/null
    
    GIT_USER=$(git config user.name || true)
    GIT_EMAIL=$(git config user.email || true)

    if [[ -z "$GIT_USER" || -z "$GIT_EMAIL" ]]; then
        echo "[WARN] Git user.name or user.email is not configured."
        echo "       Run: git config --global user.name 'Your Name'"
        echo "            git config --global user.email 'you@example.com'"
        echo "       Skipping automatic initial commit."
    else
        git add .gitignore .pre-commit-config.yaml .cursor .agents .vscode config data reports schemas sql src pyproject.toml package.json PROJECT.yml README.md AGENTS.md scripts >/dev/null 2>&1 || true
        git commit -m "feat: initialize case project from template ($NAME)" >/dev/null
        echo "[5/6] Initial Git commit created."

        if command -v pre-commit >/dev/null 2>&1 && [[ -f ".pre-commit-config.yaml" ]]; then
            pre-commit install >/dev/null 2>&1 || true
            echo "[INFO] pre-commit hooks installed for secret scanning."
        fi
    fi

    # 8. Launch Cursor
    echo -e "\n[6/6] Launching Cursor IDE..."
    if command -v cursor >/dev/null 2>&1; then
        cursor "$TARGET_DIR"
    else
        echo "[INFO] 'cursor' command not in PATH. Please open '$TARGET_DIR' in Cursor."
    fi
else
    echo -e "\n[INFO] Git initialization skipped by user."
fi

# Disable trap on success
trap - ERR

echo -e "\n========================================================"
echo "  Case Project Ready: $TARGET_DIR"
echo "========================================================\n"
exit 0
