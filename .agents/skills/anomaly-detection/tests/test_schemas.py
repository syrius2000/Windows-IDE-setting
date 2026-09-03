import json
from pathlib import Path
import jsonschema
import pandas as pd
import pytest

from anomaly_detection.pipeline import run_detection
from anomaly_detection.schemas import DetectionRequest


def test_detection_request_schema():
    req = DetectionRequest(
        study_id="S",
        records=[{"record_id": "r1", "values": {"age": 60}, "metadata": {"source": "EDC"}}],
    )
    assert req.records[0].record_id == "r1"


def test_output_schema_v0_2_0_validation():
    """Verify that run_detection output strictly complies with output.schema.json (v0.2.0)."""
    skill_dir = Path(__file__).resolve().parent.parent
    schema_path = skill_dir / "docs" / "schemas" / "output.schema.json"
    
    with open(schema_path, "r", encoding="utf-8") as f:
        schema = json.load(f)

    df = pd.DataFrame({
        "record_id": [f"row-{i}" for i in range(20)],
        "study_id": "S",
        "site_id": "S1",
        "subject_id": [f"P{i}" for i in range(20)],
        "form_name": "VS",
        "visit_date": pd.date_range("2026-01-01", periods=20, freq="D"),
        "cohort_group": ["baseline"] * 10 + ["current"] * 10,
        "age": [60] * 19 + [-2],
        "sbp": [120] * 20,
        "val1": range(20),
    })

    config = {
        "numeric_cols": ["age", "sbp", "val1"],
        "robust_stats": {"enabled": True},
        "mcd": {"enabled": True},
        "stl": {"enabled": True, "time_col": "visit_date", "value_col": "val1", "period": 7},
        "psi": {"enabled": True, "group_col": "cohort_group", "baseline_group": "baseline", "current_group": "current"},
    }

    output = run_detection(df, config)

    # jsonschema による検証 (不整合があれば jsonschema.ValidationError が発生)
    jsonschema.validate(instance=output, schema=schema)
    assert output["schema_version"] == "v0.2.0"
