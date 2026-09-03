from __future__ import annotations


def build_explanation(score: float, label: str, rule_hits: list[dict], contributions: dict[str, float]) -> str:
    parts: list[str] = [f"Overall anomaly score={score:.3f}, label={label}."]
    if rule_hits:
        rules = ", ".join(hit["rule_id"] for hit in rule_hits)
        parts.append(f"Triggered deterministic rules: {rules}.")
    if contributions:
        top = sorted(contributions.items(), key=lambda kv: kv[1], reverse=True)[:3]
        parts.append("Top model contributions: " + ", ".join(f"{k}={v:.3f}" for k, v in top) + ".")
    parts.append("Treat this as review prioritization, not automatic clinical/regulatory adjudication.")
    return " ".join(parts)
