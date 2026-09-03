#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import argparse
import csv
import os
import re
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path


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


def _load_run_scope():
    shared = _find_repo_root(Path(__file__).resolve().parent) / ".agent" / "shared"
    if str(shared) not in sys.path:
        sys.path.insert(0, str(shared))
    import run_scope

    return run_scope


def validate_identifier(identifier: str, field_name: str) -> str:
    """
    Validate that an identifier (like database name or column name) contains only
    safe alphanumeric characters and underscores/hyphens to prevent SQL injection
    and path traversal.
    """
    if not re.match(r"^[a-zA-Z0-9_\-]+$", identifier):
        print(
            f"[ERROR] Invalid {field_name}: '{identifier}'. Only alphanumeric characters, hyphens, and underscores are allowed.",
            file=sys.stderr,
        )
        sys.exit(1)
    return identifier


def get_mysql_cmd() -> str:
    """
    Finds the absolute path to the mysql binary to avoid B607 security warnings.
    """
    mysql_path = shutil.which("mysql")
    if not mysql_path:
        print("[ERROR] 'mysql' command not found in PATH.", file=sys.stderr)
        sys.exit(1)
    return str(mysql_path)


def run_mysql_query(query, db_name, host=None, port=None, user=None, password=None):
    """
    Execute a query using the mysql CLI via subprocess and return the results.
    By default, relies on ~/.my.cnf for auth unless explicitly provided.
    """
    mysql_cmd = get_mysql_cmd()
    cmd: list[str] = [
        mysql_cmd,
        "--batch",
        "--raw",
        "--skip-column-names",
        "-e",
        query,
        db_name,
    ]

    if host:
        cmd.extend(["-h", host])
    if port:
        cmd.extend(["-P", str(port)])
    if user:
        cmd.extend(["-u", user])
    if password:
        cmd.extend(["-p" + password])  # Note: no space after -p

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        print(f"[ERROR] MySQL CLI error: {e.stderr}", file=sys.stderr)
        sys.exit(1)


def execute_and_save_csv(
    query, db_name, output_path, host=None, port=None, user=None, password=None
):
    """
    Connect to MySQL via CLI, run query with headers, and parse TSV output into a clean CSV.
    """
    print(f"[INFO] Connecting to MySQL using CLI targeting database '{db_name}'...")

    # We want column names for the final output, so no --skip-column-names here
    mysql_cmd = get_mysql_cmd()
    cmd: list[str] = [mysql_cmd, "--batch", "--raw", "-e", query, db_name]

    if host:
        cmd.extend(["-h", host])
    if port:
        cmd.extend(["-P", str(port)])
    if user:
        cmd.extend(["-u", user])
    if password:
        cmd.extend(["-p" + password])

    try:
        print(
            "[INFO] Executing generated SQL query (this may take a while for large databases)..."
        )
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)

        # MySQL --batch outputs tab-separated values.
        lines = result.stdout.strip().split("\n")
        if not lines or lines == [""]:
            print("[WARNING] Query returned no results.")
            return

        print(
            f"[SUCCESS] Query executed successfully. Retrieved {len(lines) - 1} data rows."
        )

        print(f"[INFO] Writing results to {output_path}...")
        with open(output_path, "w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            for line in lines:
                writer.writerow(line.split("\t"))

        print(f"[SUCCESS] Results saved to {output_path}")

    except subprocess.CalledProcessError as e:
        print(f"[ERROR] Error executing query: {e.stderr}", file=sys.stderr)
        sys.exit(1)


def get_tables_with_column(
    db_name, column_name, host=None, port=None, user=None, password=None
):
    """
    Fetch a list of tables in the specified database that contain the specified column.
    """
    query = f"""
        SELECT TABLE_NAME
        FROM information_schema.columns
        WHERE TABLE_SCHEMA = '{db_name}' AND COLUMN_NAME = '{column_name}';
    """

    stdout = run_mysql_query(query, "information_schema", host, port, user, password)

    if not stdout:
        return []

    # Split by newline and filter out empty strings
    return [table for table in stdout.split("\n") if table.strip()]


def generate_matrix_sql(tables, id_column):
    """
    Generate the SQL query to create the entity matrix.
    """
    if not tables:
        return ""

    # 1. Build the CTE (WITH clause) to union all distinct IDs
    union_queries: list[str] = []
    for table in tables:
        union_queries.append(
            f"    SELECT {id_column} AS {id_column}_base FROM {table} WHERE {id_column} IS NOT NULL"
        )

    cte_body = "\n    UNION\n".join(union_queries)

    sql = f"WITH all_distinct_ids AS (\n{cte_body}\n)\n"

    # 2. Build the SELECT and CASE statements
    select_parts: list[str] = [f"    base.{id_column}_base AS {id_column}"]
    join_parts: list[str] = []

    for table in tables:
        # Table alias (safe generic alias to avoid reserved word conflicts)
        alias = f"t_{table}"

        # Add to SELECT: CASE WHEN t_alias.id is not null THEN 1 ELSE 0 END AS table_name
        select_parts.append(
            f"    CASE WHEN {alias}.{id_column} IS NOT NULL THEN 1 ELSE 0 END AS `{table}`"
        )

        # Add to JOIN: LEFT JOIN (SELECT DISTINCT id FROM table) alias ON base.id = alias.id
        join_parts.append(
            f"LEFT JOIN (SELECT DISTINCT {id_column} FROM `{table}` WHERE {id_column} IS NOT NULL) {alias} "
            f"ON base.{id_column}_base = {alias}.{id_column}"
        )

    sql += "SELECT\n" + ",\n".join(select_parts) + "\n"
    sql += "FROM all_distinct_ids base\n"
    sql += "\n".join(join_parts) + "\n"
    sql += f"ORDER BY base.{id_column}_base;"

    return sql


def main():
    parser = argparse.ArgumentParser(
        description="Generate and optionally execute a SQL script to map ID presence across tables using standard mysql CLI."
    )
    repo_root = _find_repo_root(Path(__file__).resolve().parent)
    default_output_dir = repo_root / "skill_out" / "mysql-entity-matrix"
    parser.add_argument(
        "-d", "--database", required=True, help="Target MySQL Database name"
    )
    parser.add_argument(
        "-i",
        "--id_column",
        default="PATIENTNO",
        help="Target ID column name to cross-check (default: PATIENTNO)",
    )
    parser.add_argument(
        "-H",
        "--host",
        default=None,
        help="MySQL Host (If omitted, uses ~/.my.cnf default)",
    )
    parser.add_argument(
        "-P",
        "--port",
        type=int,
        default=None,
        help="MySQL Port (If omitted, uses ~/.my.cnf default)",
    )
    parser.add_argument(
        "-u",
        "--user",
        default=None,
        help="MySQL User (If omitted, uses ~/.my.cnf default)",
    )
    parser.add_argument(
        "-p",
        "--password",
        default=None,
        help="MySQL Password (If omitted, uses ~/.my.cnf default)",
    )
    parser.add_argument(
        "-e",
        "--execute",
        action="store_true",
        help="Execute the generated query against the database and save results to CSV",
    )
    parser.add_argument(
        "-o",
        "--output_dir",
        default=str(default_output_dir),
        help="成果物の親ディレクトリ",
    )
    parser.add_argument(
        "--run-id",
        default=None,
        help="run 識別子（未指定時は JST タイムスタンプ。auto も可）",
    )

    args = parser.parse_args()

    # Security Validation (Sanitization)
    validate_identifier(args.database, "Database Name")
    validate_identifier(args.id_column, "ID Column Name")

    print(
        f"[INFO] Scanning database '{args.database}' for tables containing column '{args.id_column}'..."
    )

    tables = get_tables_with_column(
        db_name=args.database,
        column_name=args.id_column,
        host=args.host,
        port=args.port,
        user=args.user,
        password=args.password,
    )

    if not tables:
        print(
            f"[WARNING] No tables found containing column '{args.id_column}' in database '{args.database}'."
        )
        sys.exit(0)

    print(f"[INFO] Found {len(tables)} tables: {', '.join(tables)}")

    print("[INFO] Generating cross-table matrix SQL query...")
    matrix_sql = generate_matrix_sql(tables, args.id_column)

    rs = _load_run_scope()
    run_dir, _rid = rs.prepare_run_output_dir(
        args.output_dir,
        "mysql-entity-matrix",
        run_id=args.run_id,
    )
    os.makedirs(run_dir, exist_ok=True)

    sql_file_path = os.path.join(run_dir, f"matrix_query_{args.database}.sql")

    with open(sql_file_path, "w", encoding="utf-8") as f:
        f.write(matrix_sql)

    print(f"[SUCCESS] SQL query generated and saved to: {sql_file_path}")

    if args.execute:
        csv_file_path = os.path.join(run_dir, f"matrix_result_{args.database}.csv")
        execute_and_save_csv(
            query=matrix_sql,
            db_name=args.database,
            output_path=csv_file_path,
            host=args.host,
            port=args.port,
            user=args.user,
            password=args.password,
        )
    else:
        print(
            "[INFO] Run with --execute flag to run the query and generate a CSV matrix."
        )


if __name__ == "__main__":
    main()
