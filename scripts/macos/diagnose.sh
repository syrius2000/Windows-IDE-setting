#!/usr/bin/env bash
# ==============================================================================
# diagnose.sh - macOS Expert Environment & Hardware Diagnostic Script
# ==============================================================================
set -euo pipefail

TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLATFORM_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REPORT_DIR="$PLATFORM_ROOT/.run/reports"
mkdir -p "$REPORT_DIR"
REPORT_FILE="$REPORT_DIR/diagnose-mac-report.json"

echo "========================================================"
echo "  macOS Expert Environment Diagnostic"
echo "  Time: $TIMESTAMP"
echo "========================================================"

CHIP="$(sysctl -n machdep.cpu.brand_string 2>/dev/null || uname -m)"
TOTAL_RAM_BYTES="$(sysctl -n hw.memsize 2>/dev/null || echo 0)"
TOTAL_RAM_GB=$(( TOTAL_RAM_BYTES / 1024 / 1024 / 1024 ))
MACOS_VER="$(sw_vers -productVersion 2>/dev/null || echo "Unknown")"

echo "  [✓] Chip: $CHIP"
echo "  [✓] RAM: $TOTAL_RAM_GB GB Total"
echo "  [✓] macOS Version: $MACOS_VER"

CHECKS_JSON="[]"

add_check() {
    local id="$1"
    local name="$2"
    local status="$3"
    local msg="${4:-}"
    echo "  [$(if [[ "$status" == "PASS" ]]; then echo "✓"; elif [[ "$status" == "WARN" ]]; then echo "⚠️"; else echo "✗"; fi)] $name: $status $(if [[ -n "$msg" ]]; then echo "($msg)"; fi)"
}

# 1. Check Swift Compiler & Vision CLI
if command -v swift >/dev/null 2>&1; then
    SWIFT_VER="$(swift --version 2>&1 | head -n 1)"
    add_check "swift" "Swift Compiler" "PASS" "$SWIFT_VER"
else
    add_check "swift" "Swift Compiler" "WARN" "Xcode CLI tools required (xcode-select --install)"
fi

VISION_BIN="$SCRIPT_DIR/ocr/vision-ocr/vision-ocr"
if [[ -f "$VISION_BIN" ]]; then
    add_check "vision_cli" "Vision OCR Binary" "PASS" "$VISION_BIN"
elif [[ -f "$SCRIPT_DIR/ocr/vision-ocr/main.swift" ]]; then
    add_check "vision_cli" "Vision OCR Source" "PASS" "main.swift ready to compile"
else
    add_check "vision_cli" "Vision OCR Binary" "FAIL" "Not found"
fi

# 2. Check Ollama & Required Models
OLLAMA_STATUS="NOT_RUNNING"
if command -v ollama >/dev/null 2>&1; then
    if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
        OLLAMA_STATUS="RUNNING"
        add_check "ollama_server" "Ollama Local AI Server" "PASS" "Running on :11434"
        MODELS_LIST=$(curl -s http://localhost:11434/api/tags | grep -o '"name":"[^"]*"' | cut -d'"' -f4 || true)
        echo "      Available Local Models: $(echo $MODELS_LIST | tr '\n' ' ')"
    else
        OLLAMA_STATUS="STOPPED"
        add_check "ollama_server" "Ollama Local AI Server" "WARN" "Installed but not running (run: ollama serve)"
    fi
else
    add_check "ollama_server" "Ollama Local AI Server" "WARN" "Ollama CLI not found"
fi

# 3. Check Keychain MySQL Credential
KEYCHAIN_STATUS="NOT_SET"
if command -v python3 >/dev/null 2>&1; then
    if python3 "$SCRIPT_DIR/configure-keychain.py" check --username rwd_readonly_user >/dev/null 2>&1; then
        KEYCHAIN_STATUS="EXISTS"
        add_check "keychain_mysql" "macOS Keychain MySQL Password" "PASS" "Credential registered"
    else
        add_check "keychain_mysql" "macOS Keychain MySQL Password" "WARN" "Run configure-keychain.py set to register"
    fi
fi

# 4. Check MySQL LAN Port Reachability (3306)
MYSQL_HOST="${MYSQL_HOST:-192.168.0.50}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
if nc -z -w 2 "$MYSQL_HOST" "$MYSQL_PORT" >/dev/null 2>&1; then
    MYSQL_NET="REACHABLE"
    add_check "mysql_network" "MySQL LAN Port ($MYSQL_HOST:$MYSQL_PORT)" "PASS" "Port reachable"
else
    MYSQL_NET="UNREACHABLE"
    add_check "mysql_network" "MySQL LAN Port ($MYSQL_HOST:$MYSQL_PORT)" "WARN" "Unreachable (Normal if offline or off-campus)"
fi

# 5. Check Developer Tools (uv, quarto, duckdb, node, pnpm, gitleaks)
for tool in uv quarto duckdb node pnpm gitleaks; do
    if command -v "$tool" >/dev/null 2>&1; then
        add_check "tool_$tool" "$tool CLI" "PASS" "$($tool --version 2>&1 | head -n 1)"
    else
        add_check "tool_$tool" "$tool CLI" "WARN" "Not found"
    fi
done

# Output JSON Report
cat <<EOF > "$REPORT_FILE"
{
  "timestamp": "$TIMESTAMP",
  "environment": "mac-rwd-expert",
  "hardware": {
    "chip": "$CHIP",
    "ram_gb": $TOTAL_RAM_GB,
    "macos_version": "$MACOS_VER"
  },
  "ollama": {
    "status": "$OLLAMA_STATUS"
  },
  "keychain": {
    "mysql_credential": "$KEYCHAIN_STATUS"
  },
  "mysql_network": {
    "host": "$MYSQL_HOST",
    "port": $MYSQL_PORT,
    "status": "$MYSQL_NET"
  }
}
EOF

echo -e "\nDiagnostic report saved to: $REPORT_FILE"
echo "========================================================"
