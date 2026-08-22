#!/usr/bin/env bash
# ==============================================================================
# build.sh - Compile Apple Vision OCR Swift CLI
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if command -v swiftc >/dev/null 2>&1; then
    echo "[...] Compiling vision-ocr with swiftc..."
    swiftc -O main.swift -o vision-ocr
    chmod +x vision-ocr
    echo "[✓] vision-ocr binary created successfully at: $SCRIPT_DIR/vision-ocr"
else
    echo "[WARN] swiftc not found. Xcode Command Line Tools required (xcode-select --install)."
    exit 1
fi
