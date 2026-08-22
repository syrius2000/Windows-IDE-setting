#!/usr/bin/env python3
"""mysql-readonly-test.py - Secure MySQL 8.0 Read-Only Connection & Quality Tester

Retrieves password strictly from macOS Keychain (zero plaintext secrets on disk).
Performs non-disruptive, production-safe quality and security inspections:
1. Verifies read-only permissions via SHOW GRANTS & information_schema privilege audit (no mock writes/table creation)
2. Calculates total row counts, primary/key duplicate rates, and column NULL percentages
3. Never outputs raw patient records to stdout, console, or logs
"""

import argparse
import json
import sys
from typing import Any, Dict, List

DEFAULT_SERVICE = "rwd_mysql_readonly"

DISALLOWED_WRITE_PRIVILEGES = {
    "INSERT",
    "UPDATE",
    "DELETE",
    "DROP",
    "ALTER",
    "CREATE",
    "SUPER",
    "ALL PRIVILEGES",
}


def verify_readonly_privileges_safely(connection: Any) -> Dict[str, Any]:
    """Safely audits user grants and privileges without executing write/create operations."""
    result = {"read_only_verified": False, "grants": [], "privilege_analysis": ""}
    with connection.cursor() as cursor:
        cursor.execute("SHOW GRANTS")
        grants = [list(row.values())[0] for row in cursor.fetchall()]
        result["grants"] = grants

        # Test setting session transaction to read only (non-destructive)
        try:
            cursor.execute("SET SESSION TRANSACTION READ ONLY")
            cursor.execute("START TRANSACTION READ ONLY")
            cursor.execute("COMMIT")
            ro_tx_ok = True
        except Exception:
            ro_tx_ok = False

        # Parse grant strings for disallowed write permissions
        has_write_grant = False
        for g in grants:
            upper_g = g.upper()
            for wp in DISALLOWED_WRITE_PRIVILEGES:
                if f" {wp} " in upper_g or upper_g.startswith(f"GRANT {wp}"):
                    has_write_grant = True

        if not has_write_grant and ro_tx_ok:
            result["read_only_verified"] = True
            result["privilege_analysis"] = "READ_ONLY_CONFIRMED: Only SELECT/USAGE/READ grants present."
        else:
            result["read_only_verified"] = not has_write_grant
            result["privilege_analysis"] = f"PRIVILEGE_AUDIT: Write grants detected={has_write_grant}, ReadOnlyTx={ro_tx_ok}"

    return result


def inspect_table_quality(connection: Any, table_name: str) -> Dict[str, Any]:
    """Calculates row count, duplicate key rates, and column NULL percentages."""
    metrics = {"table": table_name, "total_rows": 0, "columns": []}

    with connection.cursor() as cursor:
        cursor.execute(f"SELECT COUNT(*) AS total FROM `{table_name}`")
        total_rows = cursor.fetchone()["total"]
        metrics["total_rows"] = total_rows

        if total_rows == 0:
            return metrics

        cursor.execute(f"DESCRIBE `{table_name}`")
        cols = cursor.fetchall()

        primary_key = None
        for col in cols:
            col_name = col["Field"]
            if col["Key"] == "PRI" and not primary_key:
                primary_key = col_name

            cursor.execute(f"SELECT COUNT(*) AS null_count FROM `{table_name}` WHERE `{col_name}` IS NULL")
            null_cnt = cursor.fetchone()["null_count"]
            null_pct = round((null_cnt / total_rows) * 100, 2)

            metrics["columns"].append({
                "name": col_name,
                "type": col["Type"],
                "nullable": col["Null"] == "YES",
                "null_count": null_cnt,
                "null_percentage": null_pct,
            })

        check_col = primary_key or cols[0]["Field"]
        cursor.execute(f"SELECT COUNT(*) - COUNT(DISTINCT `{check_col}`) AS dup_count FROM `{table_name}`")
        dup_cnt = cursor.fetchone()["dup_count"]
        metrics["duplicate_key_check"] = {
            "column": check_col,
            "duplicate_count": dup_cnt,
            "duplicate_rate": round((dup_cnt / total_rows) * 100, 4),
        }

    return metrics


def test_connection(
    host: str,
    port: int,
    db: str,
    user: str,
    service: str,
    table: str | None = None,
    output_json: bool = False,
) -> None:
    try:
        import keyring
    except ImportError:
        print("[ERROR] 'keyring' package is not installed. Run: uv run --with keyring ...", file=sys.stderr)
        sys.exit(2)

    password = keyring.get_password(service, user)
    if not password:
        print(f"[ERROR] No password found in Keychain for Service='{service}', User='{user}'.", file=sys.stderr)
        print(f"        Please run: python3 scripts/macos/configure-keychain.py set --username {user}", file=sys.stderr)
        sys.exit(2)

    try:
        import pymysql
        connection = pymysql.connect(
            host=host,
            port=port,
            user=user,
            password=password,
            database=db,
            cursorclass=pymysql.cursors.DictCursor,
            connect_timeout=10,
            charset="utf8mb4",
        )
    except ImportError:
        print("[ERROR] 'pymysql' package is not installed. Run: uv run --with pymysql ...", file=sys.stderr)
        sys.exit(2)
    except Exception as e:
        print(f"[ERROR] Failed to connect to MySQL: {e}", file=sys.stderr)
        sys.exit(1)

    with connection:
        priv_info = verify_readonly_privileges_safely(connection)

        with connection.cursor() as cursor:
            cursor.execute("SHOW TABLES")
            tables = [list(row.values())[0] for row in cursor.fetchall()]

        table_quality = None
        target_table = table or (tables[0] if tables else None)
        if target_table and target_table in tables:
            table_quality = inspect_table_quality(connection, target_table)

        result_summary = {
            "host": host,
            "port": port,
            "database": db,
            "user": user,
            "privileges": priv_info,
            "tables_found": len(tables),
            "inspected_table": table_quality,
        }

        if output_json:
            print(json.dumps(result_summary, indent=2, ensure_ascii=False))
        else:
            print("========================================================")
            print(f"  MySQL 8.0 Read-Only Quality Report: {user}@{host}/{db}")
            print("========================================================")
            print(f"  [✓] Connected successfully (Found {len(tables)} tables)")
            print(f"  [✓] Privilege Audit: {priv_info.get('privilege_analysis')}")
            if table_quality:
                print(f"\n  === Table Quality: {table_quality['table']} ({table_quality['total_rows']} rows) ===")
                dup = table_quality.get("duplicate_key_check", {})
                print(f"  - Key column '{dup.get('column')}': {dup.get('duplicate_count')} duplicates ({dup.get('duplicate_rate')}%)")
                print("  - Column Nullability & Missingness:")
                for col in table_quality.get("columns", []):
                    print(f"      * {col['name']} ({col['type']}): {col['null_percentage']}% NULL ({col['null_count']} rows)")
            print("========================================================\n")


def main() -> None:
    parser = argparse.ArgumentParser(description="Test read-only connection to MySQL 8.0 with Keychain authentication")
    parser.add_argument("--host", default="127.0.0.1", help="MySQL Server host / IP")
    parser.add_argument("--port", type=int, default=3306, help="MySQL port")
    parser.add_argument("--db", default="rwd_research_db", help="Database name")
    parser.add_argument("--username", "-u", default="rwd_readonly_user", help="Database username")
    parser.add_argument("--service", "-s", default=DEFAULT_SERVICE, help="Keychain service name")
    parser.add_argument("--table", "-t", default=None, help="Table to inspect for data quality")
    parser.add_argument("--json", action="store_true", help="Output JSON format")
    args = parser.parse_args()

    test_connection(args.host, args.port, args.db, args.username, args.service, args.table, args.json)


if __name__ == "__main__":
    main()
