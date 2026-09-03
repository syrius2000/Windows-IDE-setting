from __future__ import annotations

import argparse

from anomaly_detection.config import load_config
from anomaly_detection.io import read_table
from anomaly_detection.pipeline import run_detection


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--config", default=None)
    args = parser.parse_args()
    df = read_table(args.input)
    cfg = load_config(args.config)
    out = run_detection(df, cfg)
    print(out["summary"])
    print("top 5")
    for r in out["results"][:5]:
        print(r["record_id"], round(r["score"], 3), r["label"], [h["rule_id"] for h in r["triggered_rules"]])


if __name__ == "__main__":
    main()
