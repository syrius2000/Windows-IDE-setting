import pandas as pd

from anomaly_detection.config import load_config
from anomaly_detection.pipeline import run_detection


def test_pipeline_returns_ranked_results():
    cfg = load_config()
    df = pd.DataFrame({
        "record_id": [f"r{i}" for i in range(30)],
        "study_id": ["S"] * 30,
        "site_id": ["A"] * 30,
        "subject_id": [f"P{i}" for i in range(30)],
        "form_name": ["VS"] * 30,
        "visit_date": ["2026-01-01"] * 30,
        "recorded_at": ["2026-01-02"] * 30,
        "age": [60] * 29 + [-2],
        "sbp": [120] * 30,
        "dbp": [80] * 30,
    })
    out = run_detection(df, cfg)
    assert "results" in out
    assert out["results"][0]["score"] >= out["results"][-1]["score"]
    assert any(h["rule_id"] == "negative_age" for h in out["results"][0]["triggered_rules"])
