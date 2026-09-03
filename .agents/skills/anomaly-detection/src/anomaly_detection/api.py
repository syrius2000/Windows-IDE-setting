from __future__ import annotations

import pandas as pd
from fastapi import FastAPI

from .config import load_config
from .pipeline import run_detection
from .schemas import DetectionRequest

app = FastAPI(title="EDC/RWD Anomaly Detection Skill", version="0.1.0")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/detect")
def detect(req: DetectionRequest) -> dict:
    rows = []
    for rec in req.records:
        row = {"record_id": rec.record_id, **rec.values, **{f"meta_{k}": v for k, v in rec.metadata.items()}}
        rows.append(row)
    df = pd.DataFrame(rows)
    cfg = load_config()
    out = run_detection(df, cfg)
    return {"study_id": req.study_id, "batch_id": req.batch_id, **out}
