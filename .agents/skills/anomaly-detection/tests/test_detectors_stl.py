import numpy as np
import pandas as pd
import pytest
from anomaly_detection.detectors import STLDetector


def test_stl_detector():
    dates = pd.date_range("2026-01-01", periods=50, freq="D")
    t = np.arange(50)
    # 7日周期 + スパイク異常
    values = 10 + 5 * np.sin(2 * np.pi * t / 7)
    values[25] += 50.0  # 異常値

    df = pd.DataFrame({"visit_date": dates, "val1": values})
    config = {
        "stl": {
            "enabled": True,
            "time_col": "visit_date",
            "value_col": "val1",
            "period": 7,
        }
    }

    detector = STLDetector(config)
    scores = detector.fit_score(df)

    assert "stl" in scores
    stl_scores = scores["stl"]
    assert len(stl_scores) == len(df)
    # スパイク位置 (index 25) のスコアが最も高いことを確認
    assert stl_scores.iloc[25] > stl_scores.drop(25).mean()


def test_stl_detector_insufficient_length():
    dates = pd.date_range("2026-01-01", periods=5, freq="D")
    df = pd.DataFrame({"visit_date": dates, "val1": np.arange(5)})
    config = {"stl": {"enabled": True, "period": 7}}

    detector = STLDetector(config)
    scores = detector.fit_score(df)
    assert (scores["stl"] == 0.0).all()
