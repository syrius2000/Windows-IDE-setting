from __future__ import annotations

import hashlib
import json
from datetime import datetime, timezone
from typing import Any


def stable_hash(obj: Any) -> str:
    payload = json.dumps(obj, sort_keys=True, ensure_ascii=False, default=str).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


def make_audit_record(*, config: dict, input_rows: int, model_version: str = "0.1.0") -> dict[str, Any]:
    return {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "model_version": model_version,
        "config_hash": stable_hash(config),
        "input_rows": input_rows,
        "purpose": "review_queue_prioritization",
    }
