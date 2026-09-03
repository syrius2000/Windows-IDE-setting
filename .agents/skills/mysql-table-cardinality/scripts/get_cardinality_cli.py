#!/usr/bin/env python3
"""指定 DB・テーブルからカラム一覧・総行数・濃度数を取得し CSV/JSON を出力。"""

from __future__ import annotations

import argparse
import csv
import json
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Any


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


def _escape_identifier(name: str) -> str:
    return "`" + name.replace("`", "``") + "`"


def _escape_string_literal(text: str) -> str:
    return text.replace("\\", "\\\\").replace("'", "''")


def _load_dotenv(env_path: Path, project_root: Path) -> dict[str, str]:
    if not env_path.exists():
        return {}
    try:
        st = env_path.stat()
        if (st.st_mode & 0o77) != 0:
            print(f"Warning: .env permissions should be 600, skipping: {env_path}")
            return {}
    except OSError:
        return {}
    result: dict[str, str] = {}
    for line in env_path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            continue
        key, _, value = line.partition("=")
        key = key.strip()
        value = value.strip().strip("'\"").strip()
        if key:
            result[key] = value
    return result


def _resolve_credentials(
    args: argparse.Namespace, project_root: Path
) -> tuple[str | None, int | None, str | None, str | None]:
    dotenv = _load_dotenv(project_root / ".env", project_root)
    host = (
        getattr(args, "host", None)
        or os.environ.get("MYSQL_HOST")
        or dotenv.get("MYSQL_HOST")
    )
    port = getattr(args, "port", None)
    if port is None:
        p = os.environ.get("MYSQL_PORT") or dotenv.get("MYSQL_PORT")
        port = int(p) if p else None
    user = (
        getattr(args, "user", None)
        or os.environ.get("MYSQL_USER")
        or dotenv.get("MYSQL_USER")
    )
    password = (
        getattr(args, "password", None)
        or os.environ.get("MYSQL_PASSWORD")
        or dotenv.get("MYSQL_PASSWORD")
    )
    return host, port, user, password


def _run_mysql(
    database: str,
    query: str,
    *,
    host: str | None = None,
    port: int | None = None,
    user: str | None = None,
    password: str | None = None,
) -> tuple[list[list[str]], str]:
    cmd = ["mysql", "-N", "-B", "-e", query]
    env = os.environ.copy()
    if password:
        env["MYSQL_PWD"] = password
    else:
        env.pop("MYSQL_PWD", None)
    if host is not None:
        cmd.extend(["-h", host])
    if port is not None:
        cmd.extend(["-P", str(port)])
    if user is not None:
        cmd.extend(["-u", user])
    cmd.extend(["--", database])
    try:
        proc = subprocess.run(cmd, text=True, capture_output=True, check=False, env=env)
    except FileNotFoundError:
        return [], "mysql コマンドが見つかりません（PATH を確認してください）"
    except Exception as e:
        return [], str(e)
    if proc.returncode != 0:
        return [], (proc.stderr or proc.stdout or "mysql 実行エラー").strip()
    rows: list[list[str]] = []
    for line in proc.stdout.strip().splitlines():
        rows.append([c for c in line.split("\t")])
    return rows, ""


def _get_tables(
    database: str,
    host: str | None,
    port: int | None,
    user: str | None,
    password: str | None,
) -> list[str]:
    # INFORMATION_SCHEMA ではリテラル（シングルクォート）を使用する必要がある
    db_lit = _escape_string_literal(database)
    q = f"SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='{db_lit}' AND TABLE_TYPE='BASE TABLE' ORDER BY TABLE_NAME"
    rows, err = _run_mysql(
        database, q, host=host, port=port, user=user, password=password
    )
    if err:
        return []
    return [r[0] for r in rows if r]


def _get_columns(
    database: str,
    table: str,
    host: str | None,
    port: int | None,
    user: str | None,
    password: str | None,
) -> list[tuple[str, int, str]]:
    # INFORMATION_SCHEMA ではリテラル（シングルクォート）を使用する必要がある
    db_lit = _escape_string_literal(database)
    tbl_lit = _escape_string_literal(table)
    q = (
        f"SELECT COLUMN_NAME, ORDINAL_POSITION, DATA_TYPE "
        f"FROM INFORMATION_SCHEMA.COLUMNS "
        f"WHERE TABLE_SCHEMA='{db_lit}' AND TABLE_NAME='{tbl_lit}' "
        f"ORDER BY ORDINAL_POSITION"
    )
    rows, err = _run_mysql(
        database, q, host=host, port=port, user=user, password=password
    )
    if err:
        return []
    result: list[tuple[str, int, str]] = []
    for r in rows:
        if len(r) >= 3:
            try:
                result.append((r[0], int(r[1]), r[2]))
            except ValueError:
                pass
    return result


def _get_count(
    database: str,
    table: str,
    host: str | None,
    port: int | None,
    user: str | None,
    password: str | None,
) -> int | None:
    db_esc = _escape_identifier(database)
    tbl_esc = _escape_identifier(table)
    q = f"SELECT COUNT(*) FROM {db_esc}.{tbl_esc}"
    rows, err = _run_mysql(
        database, q, host=host, port=port, user=user, password=password
    )
    if err or not rows:
        return None
    try:
        return int(rows[0][0].strip())
    except (ValueError, IndexError):
        return None


def _get_cardinality(
    database: str,
    table: str,
    column: str,
    host: str | None,
    port: int | None,
    user: str | None,
    password: str | None,
) -> int | None:
    db_esc = _escape_identifier(database)
    tbl_esc = _escape_identifier(table)
    col_esc = _escape_identifier(column)
    q = f"SELECT COUNT(DISTINCT {col_esc}) FROM {db_esc}.{tbl_esc}"
    rows, err = _run_mysql(
        database, q, host=host, port=port, user=user, password=password
    )
    if err or not rows:
        return None
    try:
        return int(rows[0][0].strip())
    except (ValueError, IndexError):
        return None


def _process_table(
    database: str,
    table: str,
    out_dir: Path,
    host: str | None,
    port: int | None,
    user: str | None,
    password: str | None,
) -> tuple[bool, str]:
    columns = _get_columns(database, table, host, port, user, password)
    if not columns:
        return False, f"カラム取得失敗: {table}"

    total = _get_count(database, table, host, port, user, password)
    if total is None:
        return False, f"総行数取得失敗: {table}"

    rows_data: list[dict[str, Any]] = []
    for col_name, ord_pos, data_type in columns:
        card = _get_cardinality(database, table, col_name, host, port, user, password)
        cardinality = card if card is not None else -1
        rows_data.append(
            {
                "column_name": col_name,
                "ordinal_position": ord_pos,
                "data_type": data_type,
                "cardinality": cardinality,
            }
        )

    try:
        out_dir.mkdir(parents=True, exist_ok=True)
    except Exception as e:
        return False, f"出力ディレクトリの作成に失敗しました ({out_dir}): {e}"

    safe_db = database.replace("/", "_").replace("\\", "_").replace("..", "_")
    safe_table = table.replace("/", "_").replace("\\", "_").replace("..", "_")
    base = f"{safe_db}_{safe_table}"
    csv_path = out_dir / f"{base}_columns_cardinality.csv"
    with csv_path.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(
            f,
            fieldnames=["column_name", "ordinal_position", "data_type", "cardinality"],
        )
        w.writeheader()
        for r in rows_data:
            w.writerow(r)

    report = {
        "database": database,
        "table": table,
        "total_rows": total,
        "columns_count": len(columns),
        "columns": rows_data,
        "timestamp": datetime.now().isoformat(timespec="seconds"),
    }
    report_path = out_dir / f"{base}_report.json"
    report_path.write_text(
        json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    return (
        True,
        f"{table}: total_rows={total}, columns={len(columns)} -> {csv_path.name}",
    )


def main() -> int:
    parser = argparse.ArgumentParser(
        description="テーブル濃度数を取得し CSV/JSON を出力"
    )
    repo_root = _find_repo_root(Path(__file__).resolve().parent)
    default_out_dir = repo_root / "skill_out" / "mysql_table_cardinality"
    parser.add_argument("-d", "--database", required=True, help="DB 名")
    parser.add_argument(
        "-t", "--table", required=True, help="テーブル名（全テーブルは *）"
    )
    parser.add_argument("--host", default=None, help="MySQL host")
    parser.add_argument("--port", type=int, default=None, help="MySQL port")
    parser.add_argument("-u", "--user", default=None, help="MySQL user")
    parser.add_argument(
        "-p",
        "--password",
        default="",
        help="MySQL password（非推奨、MYSQL_PASSWORD または .env を使用）",
    )
    parser.add_argument(
        "-o",
        "--out-dir",
        type=Path,
        default=default_out_dir,
        help="出力先の親ディレクトリ（既定: ./skill_out/mysql_table_cardinality）",
    )
    parser.add_argument(
        "--run-id",
        default=None,
        help="run 識別子（未指定時は JST タイムスタンプ。auto も可）",
    )
    args = parser.parse_args()
    project_root = repo_root
    rs = _load_run_scope()
    run_dir, _rid = rs.prepare_run_output_dir(
        args.out_dir,
        "mysql-table-cardinality",
        run_id=args.run_id,
    )
    out_dir = run_dir.resolve()

    host, port, user, password = _resolve_credentials(args, project_root)
    if args.password:
        password = args.password

    database = args.database
    table_arg = args.table

    if table_arg == "*":
        tables = _get_tables(database, host, port, user, password)
        if not tables:
            print("Error: テーブル一覧の取得に失敗しました")
            return 1
        successes = []
        for t in tables:
            ok, msg = _process_table(database, t, out_dir, host, port, user, password)
            if ok:
                print(msg)
                successes.append(True)
            else:
                print(f"Error: {msg}")
        success_count = len(successes)
        print(f"Done: {success_count}/{len(tables)} tables")
        return 0 if success_count == len(tables) else 1

    ok, msg = _process_table(database, table_arg, out_dir, host, port, user, password)
    if ok:
        print(msg)
        return 0
    print(f"Error: {msg}")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
