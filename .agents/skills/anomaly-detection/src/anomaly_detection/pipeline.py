from __future__ import annotations

from typing import Any

import pandas as pd

from .audit import make_audit_record
from .detectors import EnsembleDetector, MCDDetector, PSIDetector, STLDetector
from .explain import build_explanation
from .features import robust_mad_scores
from .fusion import ScoreFusionEngine
from .rules import describe_rule_hits, evaluate_rules


def _label(score: float, config: dict) -> str:
    thresholds = config.get("thresholds", {})
    if score >= float(thresholds.get("critical", 0.80)):
        return "critical"
    if score >= float(thresholds.get("warning", 0.55)):
        return "warning"
    return "normal"


def run_detection(df: pd.DataFrame, config: dict) -> dict[str, Any]:
    """Run multi-stage anomaly detection for EDC/RWD data."""
    df = df.copy()
    if "record_id" not in df.columns:
        df["record_id"] = [f"row-{i}" for i in range(len(df))]

    # 1. ルールベース判定
    rules = evaluate_rules(df, config)

    # 2. 統計 & 機械学習モデル判定
    robust = (
        robust_mad_scores(df, config)
        if config.get("robust_stats", {}).get("enabled", True)
        else pd.Series(0.0, index=df.index)
    )

    ensemble = EnsembleDetector(config).fit(df)
    model_scores = ensemble.score_samples(df)

    mcd_detector = MCDDetector(config).fit(df)
    mcd_scores = mcd_detector.score_samples(df)
    model_scores.update(mcd_scores)

    stl_detector = STLDetector(config)
    stl_scores = stl_detector.fit_score(df)
    model_scores.update(stl_scores)

    all_detector_scores = {"robust_mad": robust}
    all_detector_scores.update(model_scores)

    # 3. Score Fusion 統合
    fusion_engine = ScoreFusionEngine(config)
    final_score, scaled_contributions = fusion_engine.fuse_scores(
        rule_scores=rules["rule_score"],
        detector_scores=all_detector_scores,
    )

    # 4. 行ごとの成果物構築
    results: list[dict[str, Any]] = []
    for idx, row in df.iterrows():
        contributions = {}
        for name, series in scaled_contributions.items():
            contributions[name] = float(series.loc[idx])

        score = float(final_score.loc[idx])
        label = _label(score, config)
        hits = describe_rule_hits(rules.loc[idx])
        results.append({
            "record_id": str(row["record_id"]),
            "score": score,
            "label": label,
            "triggered_rules": hits,
            "model_contributions": contributions,
            "explanation": build_explanation(score, label, hits, contributions),
        })

    results = sorted(results, key=lambda x: x["score"], reverse=True)
    top_k = int(config.get("output", {}).get("top_k", len(results)))
    results = results[:top_k]

    # 5. PSI / KS バッチ集計評価
    psi_detector = PSIDetector(config)
    batch_metrics = psi_detector.evaluate_batch(df)

    summary = {
        "n_records": int(len(df)),
        "n_returned": int(len(results)),
        "n_warning_or_critical": int(sum(r["label"] != "normal" for r in results)),
        "audit": make_audit_record(config=config, input_rows=len(df)),
    }
    if batch_metrics:
        summary.update(batch_metrics)

    return {"schema_version": "v0.2.0", "results": results, "summary": summary}
