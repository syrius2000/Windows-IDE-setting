#!/usr/bin/env python3
"""Step3: 完成版 SQL を実行し、件数比較レポートを出力。"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path


def _load_run_scope():
    shared = _find_repo_root(Path(__file__).resolve().parent) / ".agent" / "shared"
    if str(shared) not in sys.path:
        sys.path.insert(0, str(shared))
    import run_scope

    return run_scope


def _find_repo_root(start: Path, *, max_levels: int = 15) -> Path:
    """`.agent` が見つかる上位を repo root として推定する。"""
    current = start.resolve()
    for _ in range(max_levels):
        if (current / ".agent").is_dir():
            return current
        if current.parent == current:
            break
        current = current.parent
    return Path.cwd()


def run_sql_file(
    sql_path: Path,
    database: str,
    *,
    host: str = "localhost",
    port: int = 3306,
    user: str = "root",
    password: str = "",
) -> tuple[bool, str]:
    try:
        content = sql_path.read_text(encoding="utf-8")
    except Exception as e:
        return False, f"ファイル読み込み: {e}"
    cmd = ["mysql", "-h", host, "-P", str(port), "-u", user, database]
    env = os.environ.copy()
    if password:
        env["MYSQL_PWD"] = password
    try:
        proc = subprocess.run(
            cmd, input=content, text=True, capture_output=True, check=False, env=env
        )
    except FileNotFoundError:
        return False, "mysql コマンドが見つかりません（PATH を確認してください）"
    except Exception as e:
        return False, f"実行失敗: {e}"
    if proc.returncode != 0:
        return False, (proc.stderr or proc.stdout or "mysql 実行エラー").strip()
    return True, ""


def get_table_count(
    database: str,
    table: str,
    *,
    host: str = "localhost",
    port: int = 3306,
    user: str = "root",
    password: str = "",
) -> tuple[int | None, str]:
    if "." in table:
        db, tbl = table.split(".", 1)
        database, table = db, tbl
    safe = "`" + table.replace("`", "``") + "`"
    query = f"SELECT COUNT(*) FROM {safe};"
    cmd = [
        "mysql",
        "-h",
        host,
        "-P",
        str(port),
        "-u",
        user,
        "-N",
        "-B",
        "-e",
        query,
        database,
    ]
    env = os.environ.copy()
    if password:
        env["MYSQL_PWD"] = password
    try:
        proc = subprocess.run(cmd, text=True, capture_output=True, check=False, env=env)
    except FileNotFoundError:
        return None, "mysql コマンドが見つかりません（PATH を確認してください）"
    except Exception as e:
        return None, str(e)
    if proc.returncode != 0:
        return None, (proc.stderr or proc.stdout or "mysql 実行エラー").strip()
    rows = proc.stdout.strip().splitlines()
    if not rows:
        return None, "count 取得結果が空です"
    try:
        return int(rows[0].strip()), ""
    except ValueError:
        return None, f"count のパース失敗: {rows[0].strip()}"


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Step3: execute SQL and validate row count"
    )
    parser.add_argument("sql_file", type=Path, help="完成版 SQL ファイル")
    parser.add_argument("-d", "--database", required=True, help="対象 DB 名")
    repo_root = _find_repo_root(Path(__file__).resolve().parent)
    default_report_dir = repo_root / "skill_out" / "step3_report"
    parser.add_argument("--host", default="localhost", help="MySQL host")
    parser.add_argument("--port", type=int, default=3306, help="MySQL port")
    parser.add_argument("-u", "--user", default="root", help="MySQL user")
    parser.add_argument(
        "-p", "--password", default="", help="MySQL password (or MYSQL_PASSWORD)"
    )
    parser.add_argument(
        "--table", help="投入後件数取得用テーブル名 (例: tbl または db.tbl)"
    )
    parser.add_argument(
        "--expected-count", type=int, help="期待投入件数（不一致で exit 1）"
    )
    parser.add_argument(
        "--report-dir",
        type=Path,
        default=default_report_dir,
        help="レポート出力先の親ディレクトリ（既定: ./skill_out/step3_report）",
    )
    parser.add_argument(
        "--run-id",
        default=None,
        help="run 識別子（未指定時は JST タイムスタンプ。auto も可）",
    )
    args = parser.parse_args()

    rs = _load_run_scope()
    run_dir, rid = rs.prepare_run_output_dir(
        args.report_dir,
        "flat-file-mysql-load-validation",
        run_id=args.run_id,
        input_path=args.sql_file,
    )

    password = args.password or os.environ.get("MYSQL_PASSWORD", "")
    ok, err = run_sql_file(
        args.sql_file,
        args.database,
        host=args.host,
        port=args.port,
        user=args.user,
        password=password,
    )
    report = {
        "timestamp": datetime.now().isoformat(timespec="seconds"),
        "run_id": rid.run_id,
        "run_output_dir": str(run_dir),
        "sql_file": str(args.sql_file),
        "database": args.database,
        "host": args.host,
        "port": args.port,
        "user": args.user,
        "table": args.table,
        "expected_count": args.expected_count,
        "run_sql_ok": ok,
        "run_sql_error": err if not ok else "",
    }
    if not ok:
        print(f"Error: {err}")
        report_path = run_dir / "step3_report.json"
        report_path.write_text(
            json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8"
        )
        print(f"report: {report_path}")
        return 1

    print(f"OK: {args.sql_file} -> {args.database}")
    if args.table:
        cnt, err2 = get_table_count(
            args.database,
            args.table,
            host=args.host,
            port=args.port,
            user=args.user,
            password=password,
        )
        if err2:
            print(f"Warning: 件数取得失敗 ({args.table}): {err2}")
            report["table_count_ok"] = False
            report["table_count_error"] = err2
        else:
            print(f"投入件数: {cnt}")
            report["table_count_ok"] = True
            report["table_count"] = cnt
            if args.expected_count is not None:
                matched = cnt == args.expected_count
                report["expected_match"] = matched
                if not matched:
                    print(f"Error: 期待値={args.expected_count}, 実際={cnt}")
                    report["run_sql_ok"] = False
    report_path = run_dir / "step3_report.json"
    report_path.write_text(
        json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(f"report: {report_path}")
    return 0 if report.get("run_sql_ok") else 1


if __name__ == "__main__":
    raise SystemExit(main())
