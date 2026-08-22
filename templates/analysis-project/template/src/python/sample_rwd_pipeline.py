"""Sample Python RWD Analysis Pipeline (UTF-8)

Demonstrates DuckDB querying, Polars/pandas data manipulation, disclosure control
(small-cell suppression), and aggregated JSON generation for offline interactive Quarto reports.
"""

import json
from pathlib import Path


def suppress_small_cells(records: list[dict], threshold: int = 5) -> list[dict]:
    """Applies strict disclosure control by suppressing all aggregated metrics when patient count is below threshold (<5)."""
    dimension_keys = {"treatment_arm", "sex", "period", "age_group", "cohort", "strata", "category"}
    sanitized = []
    for r in records:
        item = dict(r)
        count = item.get("n_patients")
        if count is not None and count < threshold:
            for k in list(item.keys()):
                if k not in dimension_keys and k != "suppressed":
                    item[k] = None
            item["suppressed"] = True
        else:
            item["suppressed"] = False
        sanitized.append(item)
    return sanitized


def run_pipeline() -> None:
    import datetime
    import csv
    import sqlite3

    root_dir = Path(__file__).resolve().parents[2]
    synthetic_csv = root_dir / "data" / "synthetic" / "synthetic_cohort.csv"
    output_private = root_dir / "outputs" / "private"
    output_release = root_dir / "outputs" / "release"
    reports_quarto = root_dir / "reports" / "quarto"

    output_private.mkdir(parents=True, exist_ok=True)
    output_release.mkdir(parents=True, exist_ok=True)
    reports_quarto.mkdir(parents=True, exist_ok=True)

    print(f"[INFO] Loading synthetic data from: {synthetic_csv}")
    
    # Generate synthetic CSV if missing
    if not synthetic_csv.exists():
        synthetic_csv.parent.mkdir(parents=True, exist_ok=True)
        with open(synthetic_csv, "w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow(["patient_id", "age", "sex", "treatment_arm", "followup_days", "event_occurred"])
            for i in range(1, 201):
                writer.writerow([
                    f"SYNTH_{i:04d}",
                    45 + (i % 35),
                    "M" if i % 2 == 0 else "F",
                    "Control" if i % 3 == 0 else "Active",
                    120 + (i * 7) % 730,
                    1 if i % 4 == 0 else 0
                ])
        print(f"[INFO] Created synthetic cohort CSV: {synthetic_csv}")

    # Check for duckdb / pandas or fallback to standard sqlite3
    has_duckdb = False
    try:
        import duckdb
        import pandas as pd
        has_duckdb = True
    except ImportError:
        has_duckdb = False

    if has_duckdb:
        df = pd.read_csv(synthetic_csv, encoding="utf-8")
        con = duckdb.connect(database=":memory:")
        con.register("cohort", df)

        summary_df = con.execute("""
            SELECT
                treatment_arm,
                COUNT(*) AS total_patients,
                ROUND(AVG(age), 1) AS mean_age,
                SUM(event_occurred) AS total_events,
                ROUND(AVG(followup_days), 1) AS mean_followup
            FROM cohort
            GROUP BY treatment_arm
        """).df()

        print("\n=== Baseline Summary (DuckDB) ===")
        print(summary_df)

        intermediate_path = output_private / "intermediate_summary.csv"
        summary_df.to_csv(intermediate_path, index=False, encoding="utf-8")

        interactive_df = con.execute("""
            SELECT
                treatment_arm,
                sex,
                CASE
                    WHEN followup_days < 365 THEN '<1年 (365日未満)'
                    ELSE '1年以上 (365日以上)'
                END AS period,
                CASE
                    WHEN age < 55 THEN '<55'
                    WHEN age BETWEEN 55 AND 69 THEN '55-69'
                    ELSE '70+'
                END AS age_group,
                COUNT(*) AS n_patients,
                SUM(event_occurred) AS n_events,
                ROUND(SUM(event_occurred) * 100.0 / COUNT(*), 1) AS event_rate,
                ROUND(AVG(followup_days), 1) AS mean_followup
            FROM cohort
            GROUP BY treatment_arm, sex, period, age_group
            ORDER BY treatment_arm, sex, period, age_group
        """).df()
        records = interactive_df.to_dict(orient="records")
    else:
        # Fallback using standard library sqlite3
        con = sqlite3.connect(":memory:")
        cur = con.cursor()
        cur.execute("""
            CREATE TABLE cohort (
                patient_id TEXT,
                age INTEGER,
                sex TEXT,
                treatment_arm TEXT,
                followup_days INTEGER,
                event_occurred INTEGER
            )
        """)
        with open(synthetic_csv, "r", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            for row in reader:
                cur.execute(
                    "INSERT INTO cohort VALUES (?, ?, ?, ?, ?, ?)",
                    (row["patient_id"], int(row["age"]), row["sex"], row["treatment_arm"], int(row["followup_days"]), int(row["event_occurred"]))
                )
        con.commit()

        # Baseline summary
        cur.execute("""
            SELECT
                treatment_arm,
                COUNT(*) AS total_patients,
                ROUND(AVG(age), 1) AS mean_age,
                SUM(event_occurred) AS total_events,
                ROUND(AVG(followup_days), 1) AS mean_followup
            FROM cohort
            GROUP BY treatment_arm
        """)
        baseline_rows = cur.fetchall()
        print("\n=== Baseline Summary (SQLite Fallback) ===")
        for r in baseline_rows:
            print(r)

        intermediate_path = output_private / "intermediate_summary.csv"
        with open(intermediate_path, "w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow(["treatment_arm", "total_patients", "mean_age", "total_events", "mean_followup"])
            writer.writerows(baseline_rows)

        cur.execute("""
            SELECT
                treatment_arm,
                sex,
                CASE
                    WHEN followup_days < 365 THEN '<1年 (365日未満)'
                    ELSE '1年以上 (365日以上)'
                END AS period,
                CASE
                    WHEN age < 55 THEN '<55'
                    WHEN age BETWEEN 55 AND 69 THEN '55-69'
                    ELSE '70+'
                END AS age_group,
                COUNT(*) AS n_patients,
                SUM(event_occurred) AS n_events,
                ROUND(CAST(SUM(event_occurred) AS REAL) * 100.0 / COUNT(*), 1) AS event_rate,
                ROUND(AVG(followup_days), 1) AS mean_followup
            FROM cohort
            GROUP BY treatment_arm, sex, period, age_group
            ORDER BY treatment_arm, sex, period, age_group
        """)
        cols = ["treatment_arm", "sex", "period", "age_group", "n_patients", "n_events", "event_rate", "mean_followup"]
        records = [dict(zip(cols, row)) for row in cur.fetchall()]

    sanitized_records = suppress_small_cells(records, threshold=5)

    payload = {
        "metadata": {
            "title": "Interactive RWD Cohort Summary",
            "generated_at": datetime.datetime.now().isoformat(),
            "small_cell_threshold": 5,
            "disclosure_control_applied": True,
        },
        "data": sanitized_records,
    }

    # Save to outputs/private for Quarto report embedding (Git ignored)
    interactive_json_private = output_private / "interactive_cohort_summary.json"

    with open(interactive_json_private, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)

    print(f"[INFO] Generated disclosure-controlled interactive payload: {interactive_json_private}")


if __name__ == "__main__":
    run_pipeline()
