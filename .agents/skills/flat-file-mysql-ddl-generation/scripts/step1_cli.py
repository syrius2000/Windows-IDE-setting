#!/usr/bin/env python3
"""Step1: CP932 CSV からサンプル SQL と重複レポートを出力。"""

from __future__ import annotations

import argparse
import csv
import json
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Iterable

TRY_ENCODINGS = ["utf-8", "utf-8-sig", "cp932", "shift_jis", "euc_jp", "iso2022_jp"]


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


def _read_sample_bytes(path: Path, max_bytes: int = -1, sample_lines: int = 4) -> bytes:
    if max_bytes < 0 and sample_lines < 0:
        return path.read_bytes()
    collected = bytearray()
    line_count = 0
    with path.open("rb") as f:
        while True:
            if sample_lines >= 0 and line_count >= sample_lines:
                break
            if max_bytes >= 0 and len(collected) >= max_bytes:
                break
            line = f.readline()
            if not line:
                break
            collected.extend(line)
            line_count += 1
    return bytes(collected)


def _load_run_scope():
    shared = _find_repo_root(Path(__file__).resolve().parent) / ".agent" / "shared"
    if str(shared) not in sys.path:
        sys.path.insert(0, str(shared))
    import run_scope

    return run_scope


def detect_encoding(path: Path, encodings: Iterable[str] | None = None) -> str:
    data = _read_sample_bytes(path, sample_lines=10)
    for enc in encodings or TRY_ENCODINGS:
        try:
            data.decode(enc)
            return enc
        except (UnicodeDecodeError, LookupError):
            continue
    return "binary"


def _read_head_lines(path: Path, encoding: str, n: int = 4) -> list[str]:
    lines: list[str] = []
    with path.open("r", encoding=encoding, errors="replace") as f:
        for _ in range(n):
            line = f.readline()
            if not line:
                break
            lines.append(line.rstrip("\n\r"))
    return lines


def _detect_delimiter(head_lines: list[str]) -> tuple[str, str]:
    if not head_lines:
        return ",", ","
    header = head_lines[0]
    candidates = [
        (",", header.count(",")),
        ("\t", header.count("\t")),
        ("|", header.count("|")),
    ]
    delim, _ = max(candidates, key=lambda x: x[1])
    if delim == "\t":
        return "\t", "\\t"
    return delim, delim


def _detect_line_ending(path: Path, sample_size: int = 8192) -> tuple[str, str]:
    with path.open("rb") as f:
        sample = f.read(sample_size)
    crlf = sample.count(b"\r\n")
    lf = sample.count(b"\n") - crlf
    cr = sample.count(b"\r") - crlf
    if crlf > max(lf, cr):
        return "CRLF (DOS/Windows)", "\\r\\n"
    if lf > 0:
        return "LF (UNIX/Mac)", "\\n"
    if cr > 0:
        return "CR (Old Mac)", "\\r"
    return "UNKNOWN", "\\n"


def _truncate(line: str, max_len: int = 180) -> str:
    return line[:max_len] + " ... (truncated)" if len(line) > max_len else line


def _build_sample_sql(path: Path, encoding: str, head_lines: list[str]) -> str:
    charset_map = {
        "utf-8": "utf8mb4",
        "utf8": "utf8mb4",
        "utf-8-sig": "utf8mb4",
        "cp932": "cp932",
        "shift_jis": "cp932",
        "shift-jis": "cp932",
        "euc_jp": "ujis",
        "euc-jp": "ujis",
    }
    abs_path = path.resolve()
    line_ending_desc, line_ending_mysql = _detect_line_ending(path)
    _, mysql_delim = _detect_delimiter(head_lines)
    mysql_charset = charset_map.get((encoding or "").lower(), "utf8mb4")
    fields = f"FIELDS TERMINATED BY '{mysql_delim}' OPTIONALLY ENCLOSED BY '\"' ESCAPED BY '\\\\'"
    parts = [
        f"-- 元ファイル: {abs_path}",
        f"-- 推定エンコーディング: {encoding}",
        f"-- 改行: {line_ending_desc}",
        f"-- 生成: {datetime.now().isoformat(timespec='seconds')}",
        "-- 先頭4行プレビュー:",
    ]
    for i, line in enumerate(head_lines, 1):
        parts.append(f"-- [{i}] {_truncate(line)}")
    parts.extend(
        [
            "--",
            f"-- LOAD DATA INFILE '{abs_path}' INTO TABLE your_table_name",
            f"-- CHARACTER SET {mysql_charset}",
            f"-- {fields}",
            f"-- LINES TERMINATED BY '{line_ending_mysql}'",
            "-- IGNORE 1 LINES",
            "-- (col1, col2, ...);",
        ]
    )
    return "\n".join(parts) + "\n"


def _count_rows_and_duplicates(
    path: Path, encoding: str, delimiter: str
) -> tuple[int, int]:
    """Returns (total, duplicates). duplicates は重複している出現回数（余分な行の数）。ユニーク行数 = total − duplicates。"""
    total = 0
    seen: set[tuple[str, ...]] = set()
    dup_count = 0
    with path.open("r", encoding=encoding, errors="replace") as f:
        reader = csv.reader(f, delimiter=delimiter)
        first = True
        for row in reader:
            if first:
                first = False
                continue
            total += 1
            key = tuple(row)
            if key in seen:
                dup_count += 1
            else:
                seen.add(key)
    return total, dup_count


def run_step1(csv_paths: list[Path], out_dir: Path) -> list[dict[str, object]]:
    reports: list[dict[str, object]] = []
    out_dir.mkdir(parents=True, exist_ok=True)
    for path in csv_paths:
        if not path.exists():
            reports.append(
                {
                    "path": str(path),
                    "error": "not found",
                    "total": 0,
                    "duplicates": 0,
                    "unique": 0,
                }
            )
            continue
        enc = detect_encoding(path)
        if enc == "binary":
            reports.append(
                {
                    "path": str(path),
                    "error": "encoding detection failed",
                    "total": 0,
                    "duplicates": 0,
                    "unique": 0,
                }
            )
            continue
        head = _read_head_lines(path, enc, 4)
        delim_char, _ = _detect_delimiter(head)
        sql = _build_sample_sql(path, enc, head)
        out_sql = out_dir / f"{path.stem}Import.sql"
        out_sql.write_text(sql, encoding="utf-8")
        total, dup = _count_rows_and_duplicates(path, enc, delim_char)
        reports.append(
            {
                "path": str(path),
                "out_sql": str(out_sql),
                "encoding": enc,
                "total": total,
                "duplicates": dup,
                "unique": total - dup,
                "error": None,
            }
        )
    return reports


def main() -> int:
    parser = argparse.ArgumentParser(description="Step1: sample SQL + duplicate report")
    parser.add_argument("csv_paths", nargs="+", type=Path, help="対象 CSV ファイル")
    repo_root = _find_repo_root(Path(__file__).resolve().parent)
    default_out_dir = repo_root / "skill_out" / "step1_sample_sql"
    parser.add_argument(
        "-o",
        "--out-dir",
        type=Path,
        default=default_out_dir,
        help="出力先（既定: ./skill_out/step1_sample_sql）",
    )
    parser.add_argument(
        "--run-id",
        default=None,
        help="run 識別子（未指定時は JST タイムスタンプ。auto も可）",
    )
    args = parser.parse_args()
    out_dir = args.out_dir.resolve()
    reports = run_step1(list(args.csv_paths), out_dir)
    error = False
    for r in reports:
        if r.get("error"):
            print(f"Error: {r['path']} -> {r['error']}")
            error = True
            continue
        print(
            f"{Path(str(r['path'])).name}: total={r['total']}, duplicates={r['duplicates']}, unique={r['unique']}, "
            f"encoding={r['encoding']} -> {Path(str(r['out_sql'])).name}"
        )
    rs = _load_run_scope()
    first_csv = args.csv_paths[0] if args.csv_paths else None
    run_dir, _rid = rs.prepare_run_output_dir(
        out_dir,
        "flat-file-mysql-ddl-generation",
        run_id=args.run_id,
        input_path=first_csv,
    )
    report_path = run_dir / "step1_report.json"
    report_path.write_text(
        json.dumps(reports, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(f"report: {report_path}")
    return 1 if error else 0


if __name__ == "__main__":
    raise SystemExit(main())
