import numpy as np
import pandas as pd
import pytest
from scipy.stats import spearmanr
from anomaly_detection.pipeline import run_detection
from anomaly_detection.detectors import _scale01


def test_score_fusion_rank_correlation_consistency():
    """Verify that Python ScoreFusionEngine produces consistent, high Spearman rank correlation

    between composite fused scores and individual component Detector ranking metrics.
    """
    np.random.seed(42)
    n = 200
    df = pd.DataFrame({
        "record_id": [f"row-{i}" for i in range(n)],
        "study_id": "STUDY-001",
        "site_id": "S001",
        "subject_id": [f"SUBJ-{i:04d}" for i in range(n)],
        "form_name": "LB",
        "visit_date": pd.date_range("2026-01-01", periods=n, freq="D"),
        "cohort_group": ["baseline"] * 100 + ["current"] * 100,
        "age": np.random.normal(60, 5, n),
        "sbp": np.random.normal(120, 10, n),
        "dbp": np.random.normal(80, 5, n),
        "val1": np.random.normal(50, 5, n),
        "lab_value": np.random.normal(10, 2, n),
    })

    # 人工異常の注入
    df.loc[10, "age"] = -5
    df.loc[20, "sbp"] = 350
    df.loc[30, ["val1", "lab_value"]] = [200, 150]

    config = {
        "numeric_cols": ["age", "sbp", "dbp", "val1", "lab_value"],
        "categorical_cols": ["site_id", "form_name"],
        "robust_stats": {"enabled": True},
        "iforest": {"enabled": True},
        "lof": {"enabled": True},
        "mcd": {"enabled": True},
        "stl": {"enabled": False},
        "psi": {"enabled": True},
        "score_fusion": {
            "rule_weight": 0.30,
            "robust_weight": 0.10,
            "iforest_weight": 0.20,
            "lof_weight": 0.15,
            "mcd_weight": 0.25,
        },
    }

    # 1. パイプラインによる統合スコアの算出
    output = run_detection(df, config)
    results = output["results"]
    res_df = pd.DataFrame(results).set_index("record_id")
    py_scores = res_df.loc[df["record_id"], "score"].values

    # 2. 各構成要素（ルール・モデルスコア）の加重正規化期待値との相関検証
    model_contribs = res_df.loc[df["record_id"], "model_contributions"]
    expected_scores = np.zeros(n)
    for idx, contrib in enumerate(model_contribs):
        score_sum = (
            contrib.get("rule_score", 0) * 0.30
            + contrib.get("robust_mad", 0) * 0.10
            + contrib.get("iforest", 0) * 0.20
            + contrib.get("lof", 0) * 0.15
            + contrib.get("mcd", 0) * 0.25
        )
        expected_scores[idx] = score_sum

    expected_scores = _scale01(expected_scores)

    # 3. Spearman 順位相関の計算
    corr, p_value = spearmanr(py_scores, expected_scores)
    print(f"Fusion rank correlation: {corr:.4f} (p-value: {p_value:.4e})")

    # ランク一貫性検証: 相関係数 >= 0.70
    assert corr >= 0.70, f"Rank correlation {corr:.4f} is less than threshold 0.70"
