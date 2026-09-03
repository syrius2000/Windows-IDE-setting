from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from .config import load_config
from .io import read_table, write_csv, write_jsonl
from .pipeline import run_detection


def _find_repo_root(start: Path) -> Path:
    current = start.resolve()
    for _ in range(15):
        if (current / ".agent").is_dir():
            return current
        if current.parent == current:
            break
        current = current.parent
    return Path.cwd()


def _load_run_scope() -> object:
    shared = _find_repo_root(Path(__file__).resolve()) / ".agent" / "shared"
    if str(shared) not in sys.path:
        sys.path.insert(0, str(shared))
    import run_scope

    return run_scope


def main() -> None:
    parser = argparse.ArgumentParser(description="Run EDC/RWD anomaly detection.")
    parser.add_argument("--input", required=True)
    parser.add_argument(
        "--output", default=None, help="出力ファイルパス（明示時は従来どおり）"
    )
    parser.add_argument(
        "--output-root",
        default=None,
        help="成果物の親ディレクトリ（--output 未指定時。既定: ./skill_out/anomaly_detection）",
    )
    parser.add_argument(
        "--run-id",
        default=None,
        help="run 識別子（--output 未指定時。未指定なら JST タイムスタンプ）",
    )
    parser.add_argument("--config", default=None)
    parser.add_argument("--format", choices=["jsonl", "csv"], default="jsonl")
    args = parser.parse_args()

    if args.output:
        output_path = Path(args.output)
    else:
        rs = _load_run_scope()
        repo = _find_repo_root(Path(__file__).resolve())
        out_root = (
            Path(args.output_root)
            if args.output_root
            else repo / "skill_out" / "anomaly_detection"
        )
        run_dir, _rid = rs.prepare_run_output_dir(
            out_root,
            "anomaly-detection",
            run_id=args.run_id,
            input_path=args.input,
        )
        ext = "jsonl" if args.format == "jsonl" else "csv"
        output_path = run_dir / f"anomaly_results.{ext}"

    df = read_table(args.input)
    cfg = load_config(args.config)
    out = run_detection(df, cfg)

    # 各レコードに schema_version を付与
    schema_ver = out.get("schema_version", "v0.2.0")
    for r in out["results"]:
        r["schema_version"] = schema_ver

    if args.format == "jsonl":
        write_jsonl(out["results"], output_path)
    else:
        write_csv(out["results"], output_path)

    # summary.json も同一ディレクトリに保存
    summary_path = output_path.parent / "summary.json"
    summary_data = {"schema_version": schema_ver}
    summary_data.update(out["summary"])
    with open(summary_path, "w", encoding="utf-8") as f:
        json.dump(summary_data, f, ensure_ascii=False, indent=2)

    print(out["summary"])
    print(f"output: {output_path}")
    print(f"summary: {summary_path}")


if __name__ == "__main__":
    main()
