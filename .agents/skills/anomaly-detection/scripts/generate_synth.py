from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
import pandas as pd


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True)
    parser.add_argument("--n", type=int, default=500)
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()

    rng = np.random.default_rng(args.seed)
    n = args.n

    # 時系列を均等な日付シーケンスで生成
    base_dates = pd.date_range("2026-01-01", periods=n, freq="D")
    
    # コホートグループ (baseline / current)
    cohort_group = np.where(np.arange(n) < n // 2, "baseline", "current")

    # current 群にはわずかにシフトノイズを加える
    lab_vals = rng.lognormal(2.5, 0.4, n).round(2)
    shift_mask = cohort_group == "current"
    lab_vals[shift_mask] += rng.normal(1.5, 0.5, np.sum(shift_mask)).round(2)

    df = pd.DataFrame({
        "record_id": [f"row-{i}" for i in range(n)],
        "study_id": "STUDY-001",
        "site_id": rng.choice(["S001", "S002", "S003", "S004"], size=n),
        "subject_id": [f"SUBJ-{i:04d}" for i in range(n)],
        "form_name": rng.choice(["DM", "VS", "LB", "AE"], size=n),
        "visit_date": base_dates,
        "cohort_group": cohort_group,
        "age": rng.normal(62, 10, n).round(0),
        "sbp": rng.normal(125, 15, n).round(0),
        "dbp": rng.normal(78, 10, n).round(0),
        "val1": rng.normal(50, 10, n).round(2) + np.sin(np.arange(n) * 2 * np.pi / 7) * 5,  # 7日周期性
        "lab_value": lab_vals,
        "is_query_open": rng.random(n) < 0.05,
    })
    df["recorded_at"] = df["visit_date"] + pd.to_timedelta(rng.integers(0, 7, n), unit="D")
    if n >= 10:
        df.loc[0, "age"] = -1
        df.loc[1, "sbp"] = 320
        df.loc[2, "recorded_at"] = df.loc[2, "visit_date"] - pd.Timedelta(days=3)
        df.loc[3, "site_id"] = np.nan
        df.loc[4, ["study_id", "site_id", "subject_id", "visit_date", "form_name"]] = df.loc[5, ["study_id", "site_id", "subject_id", "visit_date", "form_name"]].to_numpy()
    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(out, index=False)
    print(f"wrote {out}")


if __name__ == "__main__":
    main()
