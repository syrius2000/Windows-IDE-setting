import numpy as np
import pandas as pd
import pytest
from anomaly_detection.detectors import PSIDetector, calculate_psi


def test_calculate_psi_same_distribution():
    np.random.seed(42)
    b = np.random.normal(10, 2, 1000)
    c = np.random.normal(10, 2, 1000)
    psi_val = calculate_psi(b, c, n_bins=10)
    assert psi_val < 0.1  # 安定 (shift無し)


def test_calculate_psi_shifted_distribution():
    np.random.seed(42)
    b = np.random.normal(10, 2, 1000)
    c = np.random.normal(15, 2, 1000)  # 平均が大幅シフト
    psi_val = calculate_psi(b, c, n_bins=10)
    assert psi_val > 0.25  # 有意なシフト


def test_psi_detector_eval_batch():
    np.random.seed(42)
    b_vals = np.random.normal(100, 10, 200)
    c_vals = np.random.normal(130, 10, 200)  # 大幅シフト

    df_b = pd.DataFrame({"cohort_group": "baseline", "val1": b_vals})
    df_c = pd.DataFrame({"cohort_group": "current", "val1": c_vals})
    df = pd.concat([df_b, df_c], ignore_index=True)

    config = {
        "numeric_cols": ["val1"],
        "psi": {
            "enabled": True,
            "group_col": "cohort_group",
            "baseline_group": "baseline",
            "current_group": "current",
            "n_bins": 10,
        },
    }

    detector = PSIDetector(config)
    res = detector.evaluate_batch(df)

    assert "psi_metrics" in res
    assert "ks_metrics" in res
    assert "val1" in res["psi_metrics"]
    assert res["psi_metrics"]["val1"]["shift_level"] == "significant_shift"
    assert res["ks_metrics"]["val1"]["is_different"] is True
