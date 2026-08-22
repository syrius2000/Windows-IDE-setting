#!/usr/bin/env python3
"""configure-keychain.py - Safe macOS Keychain Credential Manager

Manages MySQL 8.0 read-only database credentials in macOS Keychain via the 'keyring' package.
Prevents plaintext password leakage in .env files, history, or logs.
"""

import argparse
import getpass
import sys
import keyring

DEFAULT_SERVICE = "rwd_mysql_readonly"


def set_password(service: str, username: str) -> None:
    print(f"Configuring Keychain credential for Service='{service}', Username='{username}'")
    password = getpass.getpass("Enter MySQL password: ")
    if not password:
        print("[ERROR] Password cannot be empty.", file=sys.stderr)
        sys.exit(1)
    confirm = getpass.getpass("Confirm MySQL password: ")
    if password != confirm:
        print("[ERROR] Passwords do not match.", file=sys.stderr)
        sys.exit(1)

    keyring.set_password(service, username, password)
    print(f"[✓] Password securely saved to macOS Keychain (Service: {service}, User: {username})")


def check_password(service: str, username: str) -> None:
    pw = keyring.get_password(service, username)
    if pw:
        print(f"[✓] Credential exists in macOS Keychain for Service='{service}', User='{username}'.")
    else:
        print(f"[✗] No credential found for Service='{service}', User='{username}'.", file=sys.stderr)
        sys.exit(1)


def delete_password(service: str, username: str) -> None:
    try:
        keyring.delete_password(service, username)
        print(f"[✓] Credential deleted from Keychain for Service='{service}', User='{username}'.")
    except Exception as e:
        print(f"[ERROR] Could not delete credential: {e}", file=sys.stderr)
        sys.exit(1)


def main() -> None:
    parser = argparse.ArgumentParser(description="Manage MySQL credentials securely in macOS Keychain")
    parser.add_argument("action", choices=["set", "check", "delete"], help="Action to perform")
    parser.add_argument("--username", "-u", default="rwd_readonly_user", help="Database username")
    parser.add_argument("--service", "-s", default=DEFAULT_SERVICE, help="Keychain service name")
    args = parser.parse_args()

    if args.action == "set":
        set_password(args.service, args.username)
    elif args.action == "check":
        check_password(args.service, args.username)
    elif args.action == "delete":
        delete_password(args.service, args.username)


if __name__ == "__main__":
    main()
