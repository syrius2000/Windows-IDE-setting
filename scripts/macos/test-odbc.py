#!/usr/bin/env python3
"""test-odbc.py - macOS MySQL Connector/ODBC & DSN Inspection and Verification Tool

Optional profile verification tool for Office / Excel / FileMaker users.
1. Inspects `myodbc-installer -d -l` and `odbcinst.ini` for registered ODBC drivers
2. Resolves driver binary paths and verifies CPU architecture compatibility (ARM64 vs x86_64)
3. Audits odbc.ini for correct DSN configuration and ensures ZERO plaintext passwords are saved
4. Executes metadata-only connectivity test (SELECT VERSION(), SELECT CURRENT_USER()) via Keychain or interactive prompt
5. Strict exit code semantics: 0=PASS/Skip, 1=Connection Failure, 3=Security Violation
6. Fully decoupled: ODBC absence or failure does NOT affect Python/R direct connections
"""

import argparse
import configparser
import getpass
import json
import os
from pathlib import Path
import platform
import subprocess
import sys
from typing import Any, Dict, List, Optional

DEFAULT_SERVICE = "rwd_mysql_readonly"


def get_system_arch() -> str:
    return platform.machine()  # 'arm64' or 'x86_64'


def check_binary_arch(binary_path: Path) -> Optional[str]:
    """Inspects Mach-O binary architecture using the file command."""
    if not binary_path.exists():
        return None
    try:
        out = subprocess.check_output(["file", str(binary_path)], text=True)
        if "arm64" in out:
            return "arm64"
        elif "x86_64" in out:
            return "x86_64"
        return "unknown"
    except Exception:
        return "error"


def inspect_registered_odbc_drivers() -> Dict[str, Any]:
    """Inspects registered drivers via `myodbc-installer -d -l` or odbcinst.ini."""
    drivers_info: Dict[str, Any] = {
        "installer_found": False,
        "drivers": {},
        "raw_output": "",
    }

    # 1. Try myodbc-installer command
    try:
        res = subprocess.run(
            ["myodbc-installer", "-d", "-l"],
            capture_output=True,
            text=True
        )
        if res.returncode == 0:
            drivers_info["installer_found"] = True
            drivers_info["raw_output"] = res.stdout
            for line in res.stdout.splitlines():
                line = line.strip()
                if line and not line.startswith("---") and not line.startswith("Driver"):
                    d_name = line.strip()
                    drivers_info["drivers"][d_name] = {"name": d_name, "source": "myodbc-installer"}
    except FileNotFoundError:
        pass

    # 2. Check odbcinst.ini files
    odbcinst_candidates = [
        Path.home() / "Library" / "ODBC" / "odbcinst.ini",
        Path.home() / ".odbcinst.ini",
        Path("/Library/ODBC/odbcinst.ini"),
        Path("/etc/odbcinst.ini"),
        Path("/opt/homebrew/etc/odbcinst.ini"),
        Path("/usr/local/etc/odbcinst.ini"),
    ]
    for p in odbcinst_candidates:
        if p.exists():
            cfg = configparser.ConfigParser()
            try:
                cfg.read(p)
                for sec in cfg.sections():
                    drv_path = cfg[sec].get("Driver", "")
                    drivers_info["drivers"][sec] = {
                        "name": sec,
                        "driver_path": drv_path,
                        "source": str(p),
                    }
            except Exception:
                pass

    return drivers_info


def find_odbc_ini_files() -> List[Path]:
    candidates = [
        Path.home() / "Library" / "ODBC" / "odbc.ini",
        Path.home() / ".odbc.ini",
        Path("/Library/ODBC/odbc.ini"),
        Path("/etc/odbc.ini"),
        Path("/opt/homebrew/etc/odbc.ini"),
        Path("/usr/local/etc/odbc.ini"),
    ]
    if "ODBCINI" in os.environ:
        candidates.insert(0, Path(os.environ["ODBCINI"]))
    return [p for p in candidates if p.exists()]


def resolve_driver_binary(driver_spec: str, registered_drivers: Dict[str, Any]) -> Optional[Path]:
    """Resolves driver specification to binary file path."""
    # 1. Direct path check
    direct_p = Path(driver_spec)
    if direct_p.exists():
        return direct_p

    # 2. Lookup in registered drivers
    if driver_spec in registered_drivers.get("drivers", {}):
        d_info = registered_drivers["drivers"][driver_spec]
        if "driver_path" in d_info and d_info["driver_path"]:
            p = Path(d_info["driver_path"])
            if p.exists():
                return p

    # 3. Known standard installation paths on macOS
    standard_paths = [
        Path("/Library/MySQL/Connector-ODBC-8.4/lib/libmyodbc8w.so"),
        Path("/Library/MySQL/Connector-ODBC-8.0/lib/libmyodbc8w.so"),
        Path("/opt/homebrew/lib/libmyodbc8w.so"),
        Path("/usr/local/lib/libmyodbc8w.so"),
        Path("/usr/local/mysql-connector-odbc-8.4-macos/lib/libmyodbc8w.so"),
    ]
    for p in standard_paths:
        if p.exists():
            return p

    return None


def audit_dsn_configuration(dsn_name: str) -> Dict[str, Any]:
    system_arch = get_system_arch()
    registered_drivers = inspect_registered_odbc_drivers()
    ini_files = find_odbc_ini_files()

    result: Dict[str, Any] = {
        "system_arch": system_arch,
        "driver_registration": {
            "status": "INSTALLED" if registered_drivers["drivers"] else "NOT_INSTALLED",
            "installer_available": registered_drivers["installer_found"],
            "registered_drivers": list(registered_drivers["drivers"].keys()),
        },
        "dsn_audit": {
            "dsn_name": dsn_name,
            "status": "NOT_CONFIGURED",
            "ini_files_found": [str(p) for p in ini_files],
            "config": {},
            "issues": [],
            "resolved_driver_path": None,
            "driver_arch": None,
            "arch_match": None,
        }
    }

    if not ini_files:
        result["dsn_audit"]["issues"].append("No odbc.ini file found in standard macOS paths.")
        return result

    for ini_path in ini_files:
        config = configparser.ConfigParser()
        try:
            config.read(ini_path)
            if dsn_name in config:
                result["dsn_audit"]["status"] = "CONFIGURED"
                result["dsn_audit"]["ini_file"] = str(ini_path)
                sec = config[dsn_name]
                result["dsn_audit"]["config"] = {k: sec[k] for k in sec if k.lower() not in {"password", "pwd"}}

                # Security check: Plaintext password prohibition
                if "password" in sec or "pwd" in sec:
                    result["dsn_audit"]["status"] = "SECURITY_VIOLATION"
                    result["dsn_audit"]["issues"].append(f"[SECURITY VIOLATION] Plaintext password found in {ini_path}. Remove immediately!")

                # Driver binary and architecture resolution
                driver_spec = sec.get("Driver", "")
                resolved_p = resolve_driver_binary(driver_spec, registered_drivers)
                if resolved_p:
                    result["dsn_audit"]["resolved_driver_path"] = str(resolved_p)
                    d_arch = check_binary_arch(resolved_p)
                    result["dsn_audit"]["driver_arch"] = d_arch
                    if d_arch:
                        if d_arch == system_arch:
                            result["dsn_audit"]["arch_match"] = True
                        else:
                            result["dsn_audit"]["arch_match"] = False
                            result["dsn_audit"]["issues"].append(
                                f"Architecture Mismatch: System is {system_arch}, but Driver binary ({resolved_p}) is {d_arch}."
                            )
                else:
                    result["dsn_audit"]["issues"].append(f"Driver binary could not be resolved on disk for: '{driver_spec}'")
                break
        except Exception as e:
            result["dsn_audit"]["issues"].append(f"Failed to parse {ini_path}: {e}")

    return result


def get_password_with_interactive_fallback(
    service: str,
    username: str,
    prompt_interactive: bool = False
) -> Optional[str]:
    """Retrieves password from Keychain, or prompts interactively if requested / TTY available."""
    password = None
    # 1. Try Keychain if not forcing prompt
    if not prompt_interactive:
        try:
            import keyring
            password = keyring.get_password(service, username)
        except ImportError:
            pass

    # 2. Interactive prompt fallback
    if not password and (prompt_interactive or sys.stdin.isatty()):
        try:
            print(f"[i] Keychain credential not found for '{username}'. Enter password interactively (not saved to disk):")
            password = getpass.getpass("MySQL Password: ")
        except Exception:
            pass

    return password


def test_odbc_connectivity(
    dsn_name: str,
    username: str,
    service: str,
    prompt_password: bool = False
) -> Dict[str, Any]:
    conn_result: Dict[str, Any] = {"status": "SKIPPED", "message": "", "metadata": {}}

    password = get_password_with_interactive_fallback(service, username, prompt_password)
    if not password:
        conn_result["status"] = "WARN"
        conn_result["message"] = f"No password available (Keychain empty and interactive prompt skipped). Run configure-keychain.py set --username {username} or pass --prompt-password"
        return conn_result

    # Lazy import pyodbc
    try:
        import pyodbc
        conn_str = f"DSN={dsn_name};UID={username};PWD={password}"
        conn = pyodbc.connect(conn_str, timeout=5)
        with conn.cursor() as cursor:
            cursor.execute("SELECT VERSION(), CURRENT_USER()")
            row = cursor.fetchone()
            conn_result["status"] = "PASS"
            conn_result["metadata"] = {"version": row[0], "current_user": row[1]}
            conn_result["message"] = "ODBC connection verified successfully."
        conn.close()
        return conn_result
    except ImportError:
        conn_result["status"] = "INFO"
        conn_result["message"] = "pyodbc Python module not installed in current environment (ODBC can still be used directly by Excel/Office)."
    except Exception as e:
        conn_result["status"] = "FAIL"
        conn_result["message"] = f"ODBC connection failed: {e}"

    return conn_result


def main() -> int:
    parser = argparse.ArgumentParser(description="Audit and test macOS MySQL Connector/ODBC & DSN configuration")
    parser.add_argument("--dsn", default="rwd_research_db", help="ODBC DSN name to inspect")
    parser.add_argument("--username", "-u", default="rwd_readonly_user", help="Database username")
    parser.add_argument("--service", "-s", default=DEFAULT_SERVICE, help="Keychain service name")
    parser.add_argument("--prompt-password", action="store_true", help="Prompt for password interactively instead of reading Keychain")
    parser.add_argument("--json", action="store_true", help="Output in JSON format")
    args = parser.parse_args()

    audit = audit_dsn_configuration(args.dsn)
    conn_test = {"status": "SKIPPED", "message": "DSN not configured or audit issues detected."}

    if audit["dsn_audit"]["status"] == "CONFIGURED" and not audit["dsn_audit"]["issues"]:
        conn_test = test_odbc_connectivity(args.dsn, args.username, args.service, args.prompt_password)

    report = {
        "tool": "test-odbc.py",
        "system_arch": audit["system_arch"],
        "driver_registration": audit["driver_registration"],
        "dsn_audit": audit["dsn_audit"],
        "connection_test": conn_test,
        "isolation_guarantee": "ODBC is an optional profile for Office/Excel users. Direct Python/R connections operate completely independently.",
    }

    if args.json:
        print(json.dumps(report, indent=2, ensure_ascii=False))
    else:
        print("========================================================")
        print(f"  macOS MySQL Connector/ODBC & DSN Audit: DSN='{args.dsn}'")
        print("========================================================")
        print(f"  System CPU Architecture: {audit['system_arch']}")
        print(f"  Driver Registration:     {audit['driver_registration']['status']} (Found: {len(audit['driver_registration']['registered_drivers'])})")
        print(f"  DSN Configuration:       {audit['dsn_audit']['status']}")

        if audit["dsn_audit"].get("resolved_driver_path"):
            print(f"  Driver Binary Path:      {audit['dsn_audit']['resolved_driver_path']}")
            print(f"  Driver Architecture:     {audit['dsn_audit']['driver_arch']} (Match: {audit['dsn_audit']['arch_match']})")

        if audit["dsn_audit"]["issues"]:
            print("\n  [Audit Issues / Warnings]:")
            for issue in audit["dsn_audit"]["issues"]:
                print(f"    - {issue}")

        if conn_test.get("status") == "PASS":
            print(f"\n  [✓] ODBC Metadata Test: PASS")
            print(f"      Server Version: {conn_test['metadata'].get('version')}")
            print(f"      Current User:   {conn_test['metadata'].get('current_user')}")
        elif conn_test.get("status") == "FAIL":
            print(f"\n  [✗] ODBC Metadata Test: FAIL ({conn_test['message']})")
        else:
            print(f"\n  [i] ODBC Live Test: {conn_test['status']} ({conn_test['message']})")

        print("\n  [Fault Isolation Guarantee]:")
        print("  Python (PyMySQL) and R (RMariaDB) direct connections operate independently of ODBC.")
        print("========================================================\n")

    # Exit code contract:
    # 3: Security violation (plaintext password in odbc.ini)
    # 1: DSN is configured but actual connection attempt failed
    # 0: PASS or Cleanly skipped optional profile
    if audit["dsn_audit"]["status"] == "SECURITY_VIOLATION":
        return 3
    elif conn_test.get("status") == "FAIL":
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
