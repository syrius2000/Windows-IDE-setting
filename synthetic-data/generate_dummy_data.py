#!/usr/bin/env python3
"""generate_dummy_data.py - Generator for Synthetic Medical RWD Datasets

Produces completely synthetic, non-identifiable medical cohort datasets for
CI/CD, local testing, and demonstration of SAS, Python, R, and SQL pipelines.
"""

import csv
from pathlib import Path
import random


def generate_cohort(num_records: int = 200) -> list[dict]:
    random.seed(2026)
    cohort = []
    for i in range(1, num_records + 1):
        patient_id = f"SYNTH_{i:04d}"
        age = random.randint(35, 85)
        sex = random.choice(["M", "F"])
        arm = random.choice(["Active", "Control"])
        baseline_score = round(random.gauss(50, 10), 1)

        # Survival outcome with synthetic effect
        if arm == "Active":
            followup = random.randint(90, 730)
            event = 1 if random.random() < 0.20 else 0
        else:
            followup = random.randint(30, 600)
            event = 1 if random.random() < 0.38 else 0

        cohort.append({
            "patient_id": patient_id,
            "age": age,
            "sex": sex,
            "treatment_arm": arm,
            "baseline_score": baseline_score,
            "followup_days": followup,
            "event_occurred": event,
        })
    return cohort


def main() -> None:
    output_dir = Path(__file__).resolve().parent
    csv_path = output_dir / "synthetic_cohort.csv"

    cohort = generate_cohort(200)
    fieldnames = list(cohort[0].keys())

    with open(csv_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(cohort)

    print(f"[✓] Generated 200 synthetic records at: {csv_path}")


if __name__ == "__main__":
    main()
