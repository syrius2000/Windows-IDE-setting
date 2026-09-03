#!/usr/bin/env python3
"""
scripts/check_health.py
環境セルフヘルスチェック & 自動復旧 (L1: 案内, L2: uv sync 自動修復) スクリプト
"""

import sys
import os
import shutil
import subprocess
import importlib
from pathlib import Path

def print_ok(name: str):
    print(f"  [✓] {name}: OK")

def print_fail(name: str, err: str):
    print(f"  [✗] {name}: FAILED - {err}")

def run_diagnostics(skill_dir: Path) -> list[str]:
    sys.path.insert(0, str(skill_dir / "src"))
    required_modules = [
        ("numpy", "NumPy"),
        ("pandas", "Pandas"),
        ("pydantic", "Pydantic"),
        ("yaml", "PyYAML"),
        ("sklearn", "scikit-learn"),
        ("scipy", "SciPy"),
        ("statsmodels", "statsmodels"),
        ("jsonschema", "jsonschema"),
        ("anomaly_detection", "anomaly_detection (Package)"),
    ]

    failures = []
    print("--- 依存ライブラリ動作チェック ---")
    for mod_name, label in required_modules:
        try:
            importlib.import_module(mod_name)
            print_ok(label)
        except Exception as e:
            print_fail(label, str(e))
            failures.append(label)

    print("\n--- 設定ファイル読み込みチェック ---")
    config_path = skill_dir / "configs" / "default.yaml"
    if config_path.exists():
        try:
            import yaml
            with open(config_path, "r", encoding="utf-8") as f:
                cfg = yaml.safe_load(f)
            if "score_fusion" in cfg:
                print_ok(f"default.yaml ({config_path.name})")
            else:
                print_fail("default.yaml", "score_fusion キーが見つかりません")
                failures.append("default.yaml")
        except Exception as e:
            print_fail("default.yaml", str(e))
            failures.append("default.yaml")
    else:
        print_fail("default.yaml", "ファイルが存在しません")
        failures.append("default.yaml")

    return failures

def main():
    skill_dir = Path(__file__).resolve().parent.parent
    failures = run_diagnostics(skill_dir)

    if not failures:
        print("\n\033[32m[SUCCESS]\033[0m 全てのヘルスチェックをパスしました！\n")
        sys.exit(0)

    # L2 リカバリ: 自動修復の試行 (uv sync --extra dev)
    print("\n\033[33m[WARNING] ヘルスチェックで不整合を検出しました。L2 自動同期修復 (uv sync --extra dev) を試みます...\033[0m")
    uv_path = shutil.which("uv")
    if uv_path:
        try:
            subprocess.run([uv_path, "sync", "--extra", "dev"], check=True, cwd=skill_dir)
            print("\033[36m[INFO] uv パッケージ同期完了。再診断を実行します...\033[0m\n")
            retry_failures = run_diagnostics(skill_dir)
            if not retry_failures:
                print("\n\033[32m[SUCCESS] L2 自動修復に成功しました！環境は正常です。\033[0m\n")
                sys.exit(0)
        except Exception as e:
            print(f"\033[31m[ERROR] L2 自動修復失敗: {e}\033[0m")

    # L1 案内
    print("\n\033[31m[ヘルスチェック失敗]\033[0m 手動で以下のリカバリコマンドを実行してください:")
    print("  1. uv sync --refresh")
    print("  2. python3 scripts/setup_env.py\n")
    sys.exit(1)

if __name__ == "__main__":
    main()
