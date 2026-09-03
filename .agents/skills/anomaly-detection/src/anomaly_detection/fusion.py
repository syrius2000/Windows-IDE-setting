from __future__ import annotations

import numpy as np
import pandas as pd

from .detectors import _scale01


class ScoreFusionEngine:
    """Engine for scaling and combining multiple anomaly scores.

    Normalizes individual detector scores to [0, 1] and computes a weighted sum (fused_score).
    Dynamically reweights active detector weights if some detectors are disabled or produce all zeroes.
    """

    def __init__(self, config: dict):
        self.config = config
        self.fusion_config = config.get("score_fusion", {})

    def fuse_scores(
        self,
        rule_scores: pd.Series,
        detector_scores: dict[str, pd.Series],
    ) -> tuple[pd.Series, dict[str, pd.Series]]:
        """Combines rule scores and model scores into a final fused score."""
        n = len(rule_scores)
        scaled_contributions: dict[str, pd.Series] = {}

        # 1. ルールスコアの正規化
        scaled_contributions["rule_score"] = pd.Series(_scale01(rule_scores.values), index=rule_scores.index)

        # 2. 各検出器スコアの正規化
        for name, series in detector_scores.items():
            scaled_contributions[name] = pd.Series(_scale01(series.values), index=series.index)

        # 3. 重みの取得と再配分
        default_weights = {
            "rule_score": 0.30,
            "robust_mad": 0.10,
            "iforest": 0.20,
            "lof": 0.15,
            "mcd": 0.15,
            "stl": 0.10,
        }

        weights = {}
        for key in default_weights.keys():
            cfg_weight_key = f"{key}_weight" if not key.endswith("_weight") else key
            if key == "rule_score":
                cfg_weight_key = "rule_weight"
            elif key == "robust_mad":
                cfg_weight_key = "robust_weight"

            weights[key] = float(self.fusion_config.get(cfg_weight_key, default_weights[key]))

        # アクティブなスコアのフィルタリング
        active_weights = {}
        for key, s in scaled_contributions.items():
            if key in weights and weights[key] > 0:
                active_weights[key] = weights[key]

        total_w = sum(active_weights.values())
        if total_w == 0:
            fused = pd.Series(0.0, index=rule_scores.index)
            return fused, scaled_contributions

        # 4. 加重平均と clip(0, 1)
        fused = pd.Series(0.0, index=rule_scores.index)
        for key, weight in active_weights.items():
            norm_w = weight / total_w
            fused += scaled_contributions[key] * norm_w

        fused = pd.Series(np.clip(fused.values, 0.0, 1.0), index=rule_scores.index)
        return fused, scaled_contributions
