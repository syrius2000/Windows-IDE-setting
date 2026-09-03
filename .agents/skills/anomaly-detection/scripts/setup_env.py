#!/usr/bin/env python3
"""
scripts/setup_env.py
初学者向け uv 自動環境構築スクリプト
"""

import sys
import os
import subprocess
import shutil
from pathlib import Path

def print_info(msg: str):
    print(f"\033[36m[INFO]\033[0m {msg}")

def print_success(msg: str):
    print(f"\033[32m[SUCCESS]\033[0m {msg}")

def print_warning(msg: str):
    print(f"\033[33m[WARNING]\033[0m {msg}")

def print_error(msg: str):
    print(f"\033[31m[ERROR]\033[0m {msg}")

def main():
    print("=" * 60)
    print("  EDC/RWD Anomaly Detection Skill - Environment Setup (uv)")
    print("=" * 60)
    
    skill_dir = Path(__file__).resolve().parent.parent
    os.chdir(skill_dir)
    print_info(f"作業ディレクトリ: {skill_dir}")

    # 1. uv の存在確認
    uv_path = shutil.which("uv")
    if not uv_path:
        print_error("uv コマンドが見つかりませんでした。")
        print("以下のコマンドで uv をインストールしてください:")
        if sys.platform == "win32":
            print("  powershell -c \"irm https://astral.sh/uv/install.ps1 | iex\"")
        else:
            print("  curl -LsSf https://astral.sh/uv/install.sh | sh")
        sys.exit(1)

    print_success(f"uv コマンドを検出しました: {uv_path}")

    # 2. .venv の作成
    venv_dir = skill_dir / ".venv"
    print_info("仮想環境 (.venv) を確認/構築しています...")
    try:
        if not venv_dir.exists():
            subprocess.run([uv_path, "venv", str(venv_dir)], check=True)
            print_success("仮想環境 (.venv) の作成が完了しました。")
        else:
            print_info("既存の仮想環境 (.venv) を利用します。")
    except subprocess.CalledProcessError as e:
        print_error(f"仮想環境の作成に失敗しました: {e}")
        sys.exit(1)

    # 3. 依存関係のインストール (uv pip install -e .[dev])
    print_info("依存パッケージを同期・インストールしています...")
    try:
        subprocess.run([uv_path, "pip", "install", "-e", ".[dev]"], check=True)
        print_success("全依存パッケージのインストールに成功しました。")
    except subprocess.CalledProcessError as e:
        print_error(f"パッケージのインストールに失敗しました: {e}")
        sys.exit(1)

    # 4. ヘルスチェックの呼び出し
    print_info("ヘルスチェックを実行しています...")
    check_script = skill_dir / "scripts" / "check_health.py"
    if check_script.exists():
        res = subprocess.run([uv_path, "run", "python", str(check_script)])
        if res.returncode != 0:
            print_warning("ヘルスチェックで警告が発生しましたが、セットアップは完了しています。")
    else:
        print_success("セットアップが正常に完了しました！")

    print("\n\033[32m[完了]\033[0m 次のコマンドでテストを実行できます:")
    print("  uv run pytest tests/")
    print("  uv run python scripts/infer.py --input data/synthetic_edc.csv\n")

if __name__ == "__main__":
    main()
