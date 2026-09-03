import numpy as np
import pandas as pd
import pytest
from anomaly_detection.detectors import MCDDetector


def test_mcd_detector_fit_and_score():
    np.random.seed(42)
    normal_data = np.random.multivariate_normal(mean=[10, 20], cov=[[1, 0.5], [0.5, 1]], size=100)
    outliers = np.array([[30, 50], [50, 80]])
    data = np.vstack([normal_data, outliers])
    
    df = pd.DataFrame(data, columns=["val1", "val2"])
    config = {
        "numeric_cols": ["val1", "val2"],
        "categorical_cols": [],
        "mcd": {"enabled": True},
        "random_state": 42
    }

    detector = MCDDetector(config)
    detector.fit(df)
    scores = detector.score_samples(df)

    assert "mcd" in scores
    mcd_scores = scores["mcd"]
    assert len(mcd_scores) == len(df)
    assert (mcd_scores >= 0.0).all() and (mcd_scores <= 1.0).all()
    
    # 外れ値のスコアが正常点より高いことを検証
    outlier_scores = mcd_scores.iloc[-2:]
    normal_scores = mcd_scores.iloc[:-2]
    assert outlier_scores.mean() > normal_scores.mean()
