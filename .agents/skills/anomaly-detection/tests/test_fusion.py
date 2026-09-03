import pandas as pd
import pytest
from anomaly_detection.fusion import ScoreFusionEngine


def test_score_fusion_engine():
    rule_scores = pd.Series([1.0, 0.0, 0.5], index=[0, 1, 2])
    detector_scores = {
        "robust_mad": pd.Series([0.0, 1.0, 0.5], index=[0, 1, 2]),
        "iforest": pd.Series([0.2, 0.8, 0.4], index=[0, 1, 2]),
        "mcd": pd.Series([0.1, 0.9, 0.3], index=[0, 1, 2]),
    }
    config = {
        "score_fusion": {
            "rule_weight": 0.40,
            "robust_weight": 0.20,
            "iforest_weight": 0.20,
            "mcd_weight": 0.20,
        }
    }

    engine = ScoreFusionEngine(config)
    fused, scaled = engine.fuse_scores(rule_scores, detector_scores)

    assert len(fused) == 3
    assert (fused >= 0.0).all() and (fused <= 1.0).all()
    assert "rule_score" in scaled
    assert "mcd" in scaled
