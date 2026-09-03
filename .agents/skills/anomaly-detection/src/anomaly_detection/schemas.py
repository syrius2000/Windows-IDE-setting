from __future__ import annotations

from datetime import datetime
from typing import Any, Literal

from pydantic import BaseModel, Field, ConfigDict


class Record(BaseModel):
    """One EDC/RWD row plus metadata."""

    model_config = ConfigDict(extra="allow")

    record_id: str
    values: dict[str, Any] = Field(default_factory=dict)
    metadata: dict[str, Any] = Field(default_factory=dict)


class DetectionRequest(BaseModel):
    study_id: str
    batch_id: str | None = None
    mode: Literal["batch", "stream"] = "batch"
    return_explanations: bool = True
    records: list[Record]


class RuleHit(BaseModel):
    rule_id: str
    severity: Literal["info", "warning", "critical"] = "warning"
    message: str
    weight: float = 1.0


class DetectionResult(BaseModel):
    record_id: str
    score: float = Field(ge=0.0, le=1.0)
    label: Literal["normal", "warning", "critical"]
    triggered_rules: list[RuleHit] = Field(default_factory=list)
    model_contributions: dict[str, float] = Field(default_factory=dict)
    explanation: str = ""


class DetectionResponse(BaseModel):
    study_id: str
    batch_id: str | None = None
    generated_at: datetime = Field(default_factory=datetime.utcnow)
    results: list[DetectionResult]
    summary: dict[str, Any] = Field(default_factory=dict)
