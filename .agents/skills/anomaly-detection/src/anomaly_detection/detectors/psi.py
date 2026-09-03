from __future__ import annotations

import numpy as np
import pandas as pd
from scipy import stats


def calculate_psi(
    baseline: np.ndarray, current: np.ndarray, n_bins: int = 10
) -> float:
    """Calculate Population Stability Index (PSI) between baseline and current distributions."""
    baseline = baseline[~np.isnan(baseline)]
    current = current[~np.isnan(current)]

    if len(baseline) == 0 or len(current) == 0:
        return 0.0

    percentiles = np.linspace(0, 100, n_bins + 1)
    bins = np.percentile(baseline, percentiles)
    bins[0] = -np.inf
    bins[-1] = np.inf

    # 重複ビンへの対応
    bins = np.unique(bins)
    if len(bins) < 2:
        return 0.0

    b_counts, _ = np.histogram(baseline, bins=bins)
    c_counts, _ = np.histogram(current, bins=bins)

    b_percents = b_counts / len(baseline)
    c_percents = c_counts / len(current)

    # ゼロ割り防止用の微小値補正
    eps = 1e-4
    b_percents = np.where(b_percents == 0, eps, b_percents)
    c_percents = np.where(c_percents == 0, eps, c_percents)

    psi_val = np.sum((c_percents - b_percents) * np.log(c_percents / b_percents))
    return float(psi_val)


class PSIDetector:
    """Population Stability Index (PSI) & KS-test Drift Detector.

    Evaluates distribution shifts between baseline and current cohorts.
    Outputs metrics to be included in the execution summary.
    """

    def __init__(self, config: dict):
        self.config = config
        self.psi_config = config.get("psi", {})

    def evaluate_batch(self, df: pd.DataFrame) -> dict[str, dict]:
        if not self.psi_config.get("enabled", True):
            return {}

        group_col = self.psi_config.get("group_col", "cohort_group")
        baseline_grp = self.psi_config.get("baseline_group", "baseline")
        current_grp = self.psi_config.get("current_group", "current")
        n_bins = int(self.psi_config.get("n_bins", 10))

        if group_col not in df.columns:
            return {}

        numeric_cols = self.config.get("numeric_cols", [])
        if not numeric_cols:
            numeric_cols = df.select_dtypes(include=[np.number]).columns.tolist()

        psi_metrics = {}
        ks_metrics = {}

        b_df = df[df[group_col] == baseline_grp]
        c_df = df[df[group_col] == current_grp]

        if len(b_df) == 0 or len(c_df) == 0:
            return {}

        for col in numeric_cols:
            if col not in df.columns or col == group_col:
                continue

            b_vals = b_df[col].dropna().values
            c_vals = c_df[col].dropna().values

            if len(b_vals) < 5 or len(c_vals) < 5:
                continue

            # PSI 計算
            psi_val = calculate_psi(b_vals, c_vals, n_bins=n_bins)
            level = "stable"
            if psi_val > 0.25:
                level = "significant_shift"
            elif psi_val > 0.10:
                level = "moderate_shift"

            psi_metrics[col] = {
                "psi_value": round(psi_val, 4),
                "shift_level": level,
            }

            # KS 検定
            ks_stat, p_val = stats.ks_2samp(b_vals, c_vals)
            ks_metrics[col] = {
                "ks_statistic": round(float(ks_stat), 4),
                "p_value": round(float(p_val), 4),
                "is_different": bool(p_val < 0.05),
            }

        return {
            "psi_metrics": psi_metrics,
            "ks_metrics": ks_metrics,
        }
