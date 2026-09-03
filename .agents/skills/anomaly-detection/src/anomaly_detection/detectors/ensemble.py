from __future__ import annotations

import numpy as np
import pandas as pd
from sklearn.ensemble import IsolationForest
from sklearn.neighbors import LocalOutlierFactor

from ..features import build_preprocessor


def _scale01(x: np.ndarray) -> np.ndarray:
    x = np.asarray(x, dtype=float)
    if x.size == 0:
        return x
    lo, hi = np.nanmin(x), np.nanmax(x)
    if not np.isfinite(lo) or not np.isfinite(hi) or hi == lo:
        return np.zeros_like(x, dtype=float)
    return (x - lo) / (hi - lo)


class EnsembleDetector:
    """Isolation Forest + LOF detector wrapper.

    Scores are normalized so that larger means more anomalous.
    """

    def __init__(self, config: dict):
        self.config = config
        self.preprocessor = None
        self.iforest: IsolationForest | None = None
        self.lof: LocalOutlierFactor | None = None

    def fit(self, df: pd.DataFrame) -> "EnsembleDetector":
        self.preprocessor = build_preprocessor(df, self.config)
        X = self.preprocessor.fit_transform(df)
        random_state = int(self.config.get("random_state", 42))
        if self.config.get("iforest", {}).get("enabled", True):
            icfg = self.config.get("iforest", {})
            self.iforest = IsolationForest(
                n_estimators=int(icfg.get("n_estimators", 300)),
                contamination=icfg.get("contamination", 0.02),
                max_samples=icfg.get("max_samples", "auto"),
                random_state=random_state,
            ).fit(X)
        if self.config.get("lof", {}).get("enabled", True):
            lcfg = self.config.get("lof", {})
            self.lof = LocalOutlierFactor(
                n_neighbors=int(lcfg.get("n_neighbors", 20)),
                contamination=lcfg.get("contamination", 0.02),
                novelty=True,
            ).fit(X)
        return self

    def score_samples(self, df: pd.DataFrame) -> dict[str, pd.Series]:
        if self.preprocessor is None:
            raise RuntimeError("Detector must be fitted before scoring.")
        X = self.preprocessor.transform(df)
        scores: dict[str, pd.Series] = {}
        if self.iforest is not None:
            raw = -self.iforest.score_samples(X)
            scores["iforest"] = pd.Series(_scale01(raw), index=df.index)
        if self.lof is not None:
            raw = -self.lof.score_samples(X)
            scores["lof"] = pd.Series(_scale01(raw), index=df.index)
        return scores
