#!/usr/bin/env python3
"""validate-project.py - Case Project Integrity & Governance Validation Engine

Performs deterministic machine checks on:
1. PROJECT.yml schema compliance (against schemas/project.schema.json)
2. Directory structure (4 golden rules: src/, sql/, reports/, outputs/)
3. Prohibited file formats & credentials leakage (.sas7bdat, .xpt, .env, .key, .pem)
4. Git exclusion compliance (using non-invasive `git check-ignore --stdin` and `git ls-files`)
5. Recursive encoding boundaries (CP932 for SAS, UTF-8 for Python/R/TypeScript/Markdown)
6. Release manifest enforcement (outputs/release/ files require completed release-manifest.yml)
"""

import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
from typing import Any, Dict, List
import jsonschema
import yaml

PROHIBITED_EXTENSIONS = {
    ".sas7bdat",
    ".sas7bcat",
    ".xpt",
    ".dta",
    ".rds",
    ".rdata",
    ".env",
    ".key",
    ".pem",
    ".secret",
}


def find_platform_root(start_path: Path) -> Path:
    """Finds the root directory containing schemas/ and templates/."""
    curr = start_path.resolve()
    while curr != curr.parent:
        if (curr / "schemas" / "project.schema.json").exists():
            return curr
        curr = curr.parent
    return start_path.resolve()


def load_yaml(file_path: Path) -> Dict[str, Any]:
    with open(file_path, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)


def validate_schema(data: Dict[str, Any], schema_path: Path) -> List[str]:
    errors = []
    if not schema_path.exists():
        return [f"Fatal: Project Schema file not found at: {schema_path}"]
    with open(schema_path, "r", encoding="utf-8") as f:
        schema = json.load(f)
    try:
        validator = jsonschema.Draft7Validator(schema)
        for error in validator.iter_errors(data):
            errors.append(f"PROJECT.yml schema error at '{'.'.join(str(p) for p in error.path)}': {error.message}")
    except Exception as e:
        errors.append(f"Schema validation exception: {str(e)}")
    return errors


def check_directory_structure(project_dir: Path) -> List[str]:
    errors = []
    required_dirs = [
        "src",
        "sql",
        "reports",
        "outputs/private",
        "outputs/release",
        "data/synthetic",
    ]
    for d in required_dirs:
        p = project_dir / d
        if not p.exists() or not p.is_dir():
            errors.append(f"Missing required directory: {d}")
    return errors


def check_prohibited_files(project_dir: Path) -> List[str]:
    errors = []
    for root, dirs, files in os.walk(project_dir):
        rel_root = Path(root).relative_to(project_dir)
        parts = rel_root.parts
        if any(p in {".git", "node_modules", ".venv", ".run"} for p in parts):
            continue

        for file in files:
            ext = Path(file).suffix.lower()
            rel_file = rel_root / file

            # Prohibited extension check outside private intermediate storage
            if ext in PROHIBITED_EXTENSIONS:
                if len(parts) >= 2 and parts[0] == "outputs" and parts[1] == "private":
                    pass
                else:
                    errors.append(f"Prohibited file format detected in project area: {rel_file}")

            if file.startswith(".env") and not file.endswith(".example"):
                errors.append(f"Plaintext credentials file detected: {rel_file}")
    return errors


def check_git_exclusions_non_invasive(project_dir: Path) -> List[str]:
    """Non-invasively inspects Git tracking and .gitignore compliance using git check-ignore --stdin."""
    errors = []
    git_dir = project_dir / ".git"
    if not git_dir.exists():
        # Direct check of .gitignore contents if Git not yet initialized
        gitignore = project_dir / ".gitignore"
        if not gitignore.exists():
            errors.append("Missing .gitignore file in project root.")
        else:
            content = gitignore.read_text(encoding="utf-8")
            if "outputs/private" not in content and "outputs/private/*" not in content:
                errors.append(".gitignore does not exclude outputs/private/.")
            if ".run" not in content:
                errors.append(".gitignore does not exclude .run/ directory.")
        return errors

    # Check non-invasively via git check-ignore --stdin
    test_paths = "outputs/private/test_sample.tmp\nconfig/local.paths.yml\n.run/test.log\n"
    res = subprocess.run(
        ["git", "check-ignore", "--stdin"],
        input=test_paths,
        cwd=str(project_dir),
        capture_output=True,
        text=True
    )
    ignored_paths = set(res.stdout.splitlines())
    if "outputs/private/test_sample.tmp" not in ignored_paths:
        errors.append("outputs/private/ is NOT ignored by Git according to 'git check-ignore'.")
    if ".run/test.log" not in ignored_paths:
        errors.append(".run/ directory is NOT ignored by Git according to 'git check-ignore'.")

    # Check currently tracked / staged files via git ls-files
    res_ls = subprocess.run(
        ["git", "ls-files"],
        cwd=str(project_dir),
        capture_output=True,
        text=True
    )
    if res_ls.returncode == 0:
        tracked_files = res_ls.stdout.splitlines()
        for tf in tracked_files:
            p = Path(tf)
            if p.suffix.lower() in PROHIBITED_EXTENSIONS:
                errors.append(f"Prohibited file is actively tracked by Git: {tf}")
            if tf.startswith("outputs/private/") and not tf.endswith(".gitignore") and not tf.endswith("README.md"):
                errors.append(f"Private output file is actively tracked by Git: {tf}")
            if tf.startswith(".run/"):
                errors.append(f".run directory artifact is tracked by Git: {tf}")

    return errors


def check_encoding_recursive(project_dir: Path) -> List[str]:
    """Recursively checks character encodings across all subdirectories."""
    errors = []
    # 1. SAS files in src/sas-cp932/ (recursively) must be valid CP932 / Shift-JIS
    sas_dir = project_dir / "src" / "sas-cp932"
    if sas_dir.exists():
        for sas_file in sas_dir.rglob("*.sas"):
            try:
                with open(sas_file, "r", encoding="cp932") as f:
                    f.read()
            except UnicodeDecodeError:
                errors.append(f"SAS file is not valid CP932 (Shift-JIS): {sas_file.relative_to(project_dir)}")

    # 2. Python, R, TypeScript, SQL, Markdown files across the project must be valid UTF-8
    check_targets = [
        ("src/python", "*.py"),
        ("src/r", "*.R"),
        ("src/typescript", "*.ts"),
        ("sql", "*.sql"),
        ("reports", "*.qmd"),
        ("reports", "*.md"),
        ("docs", "*.md"),
    ]
    for rel_dir, pattern in check_targets:
        target_dir = project_dir / rel_dir
        if target_dir.exists():
            for code_file in target_dir.rglob(pattern):
                try:
                    with open(code_file, "r", encoding="utf-8") as f:
                        f.read()
                except UnicodeDecodeError:
                    errors.append(f"File is not valid UTF-8: {code_file.relative_to(project_dir)}")
    return errors


def check_interactive_reports(project_dir: Path) -> List[str]:
    """Inspects rendered Quarto HTML and interactive templates for external CDN/network leaks,
    unauthorized output locations, and unmasked patient identifiers.
    """
    import re
    errors = []

    # 1. Prohibit generated HTML and data artifacts directly in reports/quarto/ (must be in outputs/private/ or outputs/release/)
    quarto_reports_dir = project_dir / "reports" / "quarto"
    if quarto_reports_dir.exists():
        for artifact in quarto_reports_dir.glob("*.html"):
            errors.append(
                f"Generated HTML artifact found in reports/quarto/: {artifact.relative_to(project_dir)}. "
                "Interactive HTML reports must be placed in outputs/private/ or outputs/release/."
            )
        for data_artifact in quarto_reports_dir.glob("*.json"):
            errors.append(
                f"Data payload found in reports/quarto/: {data_artifact.relative_to(project_dir)}. "
                "Aggregated data payloads must reside in outputs/private/ or outputs/release/."
            )

    # 2. Check all generated HTML reports across outputs/ and reports/
    html_files = list(project_dir.glob("outputs/**/*.html")) + list(project_dir.glob("reports/**/*.html"))
    
    # Blocked external domains and URL patterns
    prohibited_cdn_patterns = [
        (re.compile(r"cdn\.jsdelivr\.net", re.IGNORECASE), "jsdelivr CDN dependency"),
        (re.compile(r"unpkg\.com", re.IGNORECASE), "unpkg CDN dependency"),
        (re.compile(r"cdn\.observableusercontent\.com", re.IGNORECASE), "Observable CDN asset dependency"),
        (re.compile(r"static\.observableusercontent\.com", re.IGNORECASE), "Observable static file/WASM dependency"),
        (re.compile(r"api\.observablehq\.com", re.IGNORECASE), "Observable API dependency"),
        (re.compile(r"cdnjs\.cloudflare\.com", re.IGNORECASE), "cdnjs CDN dependency"),
        (re.compile(r"raw\.githubusercontent\.com", re.IGNORECASE), "Raw GitHub asset dependency"),
    ]

    # Blocked JavaScript dynamic network patterns
    js_network_patterns = [
        (re.compile(r"<\s*(?:script|link|img|iframe|video|audio)[^>]+(?:src|href)\s*=\s*[\"'](?:https?:|//)", re.IGNORECASE), "Active remote resource tag"),
        (re.compile(r"\bfetch\s*\(\s*[\"'`](?:https?:|//)", re.IGNORECASE), "fetch() network request"),
        (re.compile(r"\bimport\s*\(\s*[\"'`](?:https?:|//)", re.IGNORECASE), "Dynamic import() remote module request"),
        (re.compile(r"\bimport\s+[^;]+\s+from\s+[\"'`](?:https?:|//)", re.IGNORECASE), "Static import from remote URL"),
        (re.compile(r"\bnew\s+Worker\s*\(\s*[\"'`](?:https?:|//)", re.IGNORECASE), "Remote Web Worker dependency"),
        (re.compile(r"\.open\s*\(\s*[\"'`][A-Z]+[\"'`]\s*,\s*[\"'`](?:https?:|//)", re.IGNORECASE), "XMLHttpRequest remote request"),
    ]

    for html_file in html_files:
        try:
            content = html_file.read_text(encoding="utf-8")
            lower_content = content.lower()

            # Check prohibited CDN patterns
            for pat, desc in prohibited_cdn_patterns:
                if pat.search(content):
                    errors.append(f"{desc} detected in HTML report: {html_file.relative_to(project_dir)}")

            # Check JS network patterns
            for pat, desc in js_network_patterns:
                if pat.search(content):
                    errors.append(f"{desc} detected in HTML report: {html_file.relative_to(project_dir)}")

            # Check for leaked unmasked patient IDs or small-cell suppression failures
            if "patient_id" in lower_content or re.search(r"synth_\d{4}", lower_content):
                errors.append(f"Individual-level patient identifiers detected in HTML report: {html_file.relative_to(project_dir)}")

        except Exception as e:
            errors.append(f"Failed to inspect HTML report {html_file.relative_to(project_dir)}: {e}")

    return errors


def check_release_manifest(project_dir: Path) -> List[str]:
    errors = []
    release_dir = project_dir / "outputs" / "release"
    manifest_file = release_dir / "release-manifest.yml"

    if release_dir.exists():
        artifacts = [
            f for f in release_dir.iterdir()
            if f.is_file() and f.name not in {"release-manifest.yml", "README.md", ".gitignore"}
        ]
        if artifacts:
            if not manifest_file.exists():
                errors.append(f"Artifacts exist in outputs/release/ ({len(artifacts)} files) but release-manifest.yml is missing.")
            else:
                try:
                    manifest = load_yaml(manifest_file)
                    rel = manifest.get("release", {})
                    checks = rel.get("checks", {})
                    reviewed_by = rel.get("reviewed_by", "")

                    if not reviewed_by or str(reviewed_by).strip() == "":
                        errors.append("release-manifest.yml: 'reviewed_by' is empty. Human reviewer signature required.")
                    if not checks.get("direct_identifiers_removed", False):
                        errors.append("release-manifest.yml: 'direct_identifiers_removed' check is not confirmed (must be true).")
                    if not checks.get("small_cells_reviewed", False):
                        errors.append("release-manifest.yml: 'small_cells_reviewed' check is not confirmed (must be true).")
                    if not checks.get("disclosure_risk_reviewed", False):
                        errors.append("release-manifest.yml: 'disclosure_risk_reviewed' check is not confirmed (must be true).")
                except Exception as e:
                    errors.append(f"Failed to parse release-manifest.yml: {e}")
    return errors


def run_validation(project_dir: Path, schema_path: Path) -> Dict[str, Any]:
    project_yml = project_dir / "PROJECT.yml"
    checks_results = []
    all_errors = []

    # Check 1: PROJECT.yml existence
    if not project_yml.exists():
        return {
            "status": "FAIL",
            "message": "PROJECT.yml not found in project root.",
            "errors": ["Missing PROJECT.yml"],
            "checks": [{"id": "project_yml_existence", "status": "FAIL", "errors": ["Missing PROJECT.yml"]}],
        }

    # Check 2: Schema validation
    try:
        data = load_yaml(project_yml)
        schema_errors = validate_schema(data, schema_path)
        if schema_errors:
            all_errors.extend(schema_errors)
            checks_results.append({"id": "schema_validation", "status": "FAIL", "errors": schema_errors})
        else:
            checks_results.append({"id": "schema_validation", "status": "PASS"})
    except Exception as e:
        all_errors.append(f"Failed to parse PROJECT.yml: {e}")
        checks_results.append({"id": "schema_validation", "status": "FAIL", "errors": [str(e)]})

    # Check 3: Directory structure
    dir_errors = check_directory_structure(project_dir)
    if dir_errors:
        all_errors.extend(dir_errors)
        checks_results.append({"id": "directory_structure", "status": "FAIL", "errors": dir_errors})
    else:
        checks_results.append({"id": "directory_structure", "status": "PASS"})

    # Check 4: Prohibited files
    prohibited_errors = check_prohibited_files(project_dir)
    if prohibited_errors:
        all_errors.extend(prohibited_errors)
        checks_results.append({"id": "prohibited_files", "status": "FAIL", "errors": prohibited_errors})
    else:
        checks_results.append({"id": "prohibited_files", "status": "PASS"})

    # Check 5: Git exclusions & tracking check (non-invasive)
    git_errors = check_git_exclusions_non_invasive(project_dir)
    if git_errors:
        all_errors.extend(git_errors)
        checks_results.append({"id": "git_exclusions", "status": "FAIL", "errors": git_errors})
    else:
        checks_results.append({"id": "git_exclusions", "status": "PASS"})

    # Check 6: Recursive encoding boundaries
    encoding_errors = check_encoding_recursive(project_dir)
    if encoding_errors:
        all_errors.extend(encoding_errors)
        checks_results.append({"id": "encoding_boundaries", "status": "FAIL", "errors": encoding_errors})
    else:
        checks_results.append({"id": "encoding_boundaries", "status": "PASS"})

    # Check 7: Release manifest enforcement
    release_errors = check_release_manifest(project_dir)
    if release_errors:
        all_errors.extend(release_errors)
        checks_results.append({"id": "release_manifest", "status": "FAIL", "errors": release_errors})
    else:
        checks_results.append({"id": "release_manifest", "status": "PASS"})

    # Check 8: Interactive HTML reports self-containment & privacy
    report_errors = check_interactive_reports(project_dir)
    if report_errors:
        all_errors.extend(report_errors)
        checks_results.append({"id": "interactive_reports", "status": "FAIL", "errors": report_errors})
    else:
        checks_results.append({"id": "interactive_reports", "status": "PASS"})

    overall_status = "FAIL" if all_errors else "PASS"
    return {
        "status": overall_status,
        "project_dir": str(project_dir),
        "checks": checks_results,
        "errors": all_errors,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate Case Project Integrity & Governance")
    parser.add_argument("--project-dir", type=str, default=".", help="Path to project directory")
    parser.add_argument("--schema", type=str, default=None, help="Path to project.schema.json")
    parser.add_argument("--json", action="store_true", help="Output results in JSON format")
    args = parser.parse_args()

    project_dir = Path(args.project_dir).resolve()
    if args.schema:
        schema_path = Path(args.schema).resolve()
    else:
        root = find_platform_root(project_dir)
        schema_path = root / "schemas" / "project.schema.json"

    if not schema_path.exists():
        print(f"[FATAL ERROR] Schema file not found: {schema_path}", file=sys.stderr)
        return 2

    result = run_validation(project_dir, schema_path)

    if args.json:
        print(json.dumps(result, indent=2, ensure_ascii=False))
    else:
        print(f"\n========================================================")
        print(f"  Case Project Validation: {result['status']}")
        print(f"  Target: {project_dir}")
        print(f"========================================================")
        for check in result["checks"]:
            symbol = "✓" if check["status"] == "PASS" else "✗"
            print(f"  [{symbol}] {check['id']}: {check['status']}")
            if "errors" in check:
                for err in check["errors"]:
                    print(f"      - ERROR: {err}")
        print("========================================================\n")

    return 1 if result["status"] == "FAIL" else 0


if __name__ == "__main__":
    sys.exit(main())
