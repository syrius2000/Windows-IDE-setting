import pandas as pd

from anomaly_detection.config import load_config
from anomaly_detection.rules import evaluate_rules


def test_rule_flags_detect_basic_issues():
    cfg = load_config()
    df = pd.DataFrame({
        "record_id": ["a", "b"],
        "study_id": ["S", "S"],
        "site_id": ["X", None],
        "subject_id": ["P1", "P1"],
        "form_name": ["VS", "VS"],
        "visit_date": ["2026-01-02", "2026-01-02"],
        "recorded_at": ["2026-01-01", "2026-01-03"],
        "age": [-1, 60],
    })
    flags = evaluate_rules(df, cfg)
    assert flags.loc[0, "temporal_inconsistency"] == 1
    assert flags.loc[0, "negative_age"] == 1
    assert flags.loc[1, "missing_required_value"] == 1
    assert flags["rule_score"].max() > 0
