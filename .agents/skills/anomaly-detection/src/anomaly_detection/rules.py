from __future__ import annotations

import pandas as pd


def _rule_score_from_flags(flags: pd.DataFrame, weights: dict[str, float]) -> pd.Series:
    if flags.empty:
        return pd.Series([], dtype=float)
    score = pd.Series(0.0, index=flags.index)
    for col in flags.columns:
        score = score + flags[col].astype(float) * float(weights.get(col, 0.5))
    return score.clip(0, 1)


def evaluate_rules(df: pd.DataFrame, config: dict) -> pd.DataFrame:
    """Evaluate deterministic EDC/RWD data-quality rules.

    Returns a DataFrame with one boolean/int flag per rule plus a rule_score.
    """
    flags = pd.DataFrame(index=df.index)
    required = list(config.get("required_columns", []))
    missing_cols = [c for c in required if c not in df.columns]
    if missing_cols:
        # Missing columns are a batch-level issue; mark all rows as affected.
        flags["missing_required_column"] = 1
    else:
        flags["missing_required_value"] = df[required].isna().any(axis=1).astype(int)

    entity_keys = [c for c in config.get("entity_keys", []) if c in df.columns]
    if entity_keys:
        flags["duplicate_entity_key"] = df.duplicated(entity_keys, keep=False).astype(int)
    else:
        flags["duplicate_entity_key"] = 0

    if {"visit_date", "recorded_at"}.issubset(df.columns):
        visit = pd.to_datetime(df["visit_date"], errors="coerce")
        recorded = pd.to_datetime(df["recorded_at"], errors="coerce")
        flags["temporal_inconsistency"] = (recorded < visit).fillna(False).astype(int)
    else:
        flags["temporal_inconsistency"] = 0

    if "age" in df.columns:
        age = pd.to_numeric(df["age"], errors="coerce")
        flags["negative_age"] = (age < 0).fillna(False).astype(int)
        flags["implausible_age"] = ((age > 120) | (age < 0)).fillna(False).astype(int)
    else:
        flags["negative_age"] = 0
        flags["implausible_age"] = 0

    if {"sbp", "dbp"}.issubset(df.columns):
        sbp = pd.to_numeric(df["sbp"], errors="coerce")
        dbp = pd.to_numeric(df["dbp"], errors="coerce")
        flags["implausible_bp"] = ((sbp < 50) | (sbp > 260) | (dbp < 30) | (dbp > 160)).fillna(False).astype(int)
    else:
        flags["implausible_bp"] = 0

    if "is_query_open" in df.columns:
        flags["unresolved_query"] = df["is_query_open"].fillna(False).astype(bool).astype(int)
    else:
        flags["unresolved_query"] = 0

    weights = {
        "missing_required_column": 1.0,
        "missing_required_value": config.get("rules", {}).get("required_missing_weight", 1.0),
        "duplicate_entity_key": config.get("rules", {}).get("duplicate_weight", 0.85),
        "temporal_inconsistency": config.get("rules", {}).get("temporal_inconsistency_weight", 0.9),
        "negative_age": config.get("rules", {}).get("negative_age_weight", 1.0),
        "implausible_age": config.get("rules", {}).get("physiologic_range_weight", 0.7),
        "implausible_bp": config.get("rules", {}).get("physiologic_range_weight", 0.7),
        "unresolved_query": config.get("rules", {}).get("unresolved_query_weight", 0.4),
    }
    flags["rule_score"] = _rule_score_from_flags(flags, weights)
    return flags


def describe_rule_hits(row: pd.Series) -> list[dict]:
    hits: list[dict] = []
    messages = {
        "missing_required_column": "Required schema column is missing at batch level.",
        "missing_required_value": "Required EDC value is missing.",
        "duplicate_entity_key": "Duplicate entity key detected.",
        "temporal_inconsistency": "Recorded date precedes visit date.",
        "negative_age": "Age is negative.",
        "implausible_age": "Age is outside plausible range.",
        "implausible_bp": "Blood pressure is outside plausible range.",
        "unresolved_query": "Open query remains unresolved.",
    }
    for rule_id, message in messages.items():
        if int(row.get(rule_id, 0)) == 1:
            sev = "critical" if rule_id in {"missing_required_column", "negative_age"} else "warning"
            hits.append({"rule_id": rule_id, "severity": sev, "message": message, "weight": 1.0})
    return hits
