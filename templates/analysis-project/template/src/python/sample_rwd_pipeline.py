"""Sample Python RWD Analysis Pipeline (UTF-8)

Demonstrates DuckDB querying, Polars/pandas data manipulation,
and report generation from synthetic datasets without touching sensitive data.
"""

from pathlib import Path
import duckdb
import pandas as pd
import polars as pl


def run_pipeline() -> None:
    root_dir = Path(__file__).resolve().parents[2]
    synthetic_csv = root_dir / "data" / "synthetic" / "synthetic_cohort.csv"
    output_private = root_dir / "outputs" / "private"
    output_release = root_dir / "outputs" / "release"

    output_private.mkdir(parents=True, exist_ok=True)
    output_release.mkdir(parents=True, exist_ok=True)

    print(f"[INFO] Loading synthetic data from: {synthetic_csv}")
    if not synthetic_csv.exists():
        print(f"[WARN] {synthetic_csv} not found, generating sample DataFrame.")
        df = pd.DataFrame(
            {
                "patient_id": [f"SYNTH_{i:04d}" for i in range(1, 101)],
                "age": [45 + (i % 35) for i in range(100)],
                "sex": ["M" if i % 2 == 0 else "F" for i in range(100)],
                "treatment_arm": ["Control" if i % 3 == 0 else "Active" for i in range(100)],
                "followup_days": [120 + (i * 7) % 730 for i in range(100)],
                "event_occurred": [1 if i % 4 == 0 else 0 for i in range(100)],
            }
        )
        synthetic_csv.parent.mkdir(parents=True, exist_ok=True)
        df.to_csv(synthetic_csv, index=False, encoding="utf-8")
    else:
        df = pd.read_csv(synthetic_csv, encoding="utf-8")

    # DuckDB In-Memory Analysis
    con = duckdb.connect(database=":memory:")
    con.register("cohort", df)

    summary_df = con.execute("""
        SELECT
            treatment_arm,
            COUNT(*) AS total_patients,
            AVG(age) AS mean_age,
            SUM(event_occurred) AS total_events,
            AVG(followup_days) AS mean_followup
        FROM cohort
        GROUP BY treatment_arm
    """).df()

    print("\n=== Baseline Summary (DuckDB) ===")
    print(summary_df)

    # Save private intermediate table (Git ignored)
    intermediate_path = output_private / "intermediate_summary.csv"
    summary_df.to_csv(intermediate_path, index=False, encoding="utf-8")
    print(f"[INFO] Saved intermediate results to: {intermediate_path}")


if __name__ == "__main__":
    run_pipeline()
