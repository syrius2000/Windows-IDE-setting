from __future__ import annotations

import argparse
import pickle
from pathlib import Path

from anomaly_detection.config import load_config
from anomaly_detection.detectors import EnsembleDetector
from anomaly_detection.io import read_table


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--model", required=True)
    parser.add_argument("--config", default=None)
    args = parser.parse_args()
    df = read_table(args.input)
    cfg = load_config(args.config)
    detector = EnsembleDetector(cfg).fit(df)
    out = Path(args.model)
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("wb") as f:
        pickle.dump({"config": cfg, "detector": detector}, f)
    print(f"wrote {out}")


if __name__ == "__main__":
    main()
