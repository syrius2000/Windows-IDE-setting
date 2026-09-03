from __future__ import annotations

import warnings
import numpy as np
import pandas as pd
from sklearn.covariance import MinCovDet

from ..features import build_preprocessor
from .ensemble import _scale01


class MCDDetector:
    """Minimum Covariance Determinant (Robust Mahalanobis Distance) Detector.

    Calculates robust Mahalanobis distance using MCD estimator.
    Scores are normalized between 0 and 1 (larger means more anomalous).
    """

    def __init__(self, config: dict):
        self.config = config
        self.preprocessor = None
        self.mcd: MinCovDet | None = None
        self.valid_feature_indices: list[int] = []

    def fit(self, df: pd.DataFrame) -> "MCDDetector":
        self.preprocessor = build_preprocessor(df, self.config)
        X = self.preprocessor.fit_transform(df)
        mcd_cfg = self.config.get("mcd", {})
        if mcd_cfg.get("enabled", True) and X.shape[1] > 0 and X.shape[0] > X.shape[1]:
            # 分散がほぼゼロの列を除外してフルランクを維持
            stds = np.std(X, axis=0)
            self.valid_feature_indices = np.where(stds > 1e-6)[0].tolist()

            if len(self.valid_feature_indices) > 0 and X.shape[0] > len(self.valid_feature_indices):
                X_sub = X[:, self.valid_feature_indices]
                random_state = int(self.config.get("random_state", 42))
                support_fraction = mcd_cfg.get("support_fraction", None)
                try:
                    with warnings.catch_warnings():
                        warnings.simplefilter("ignore")
                        self.mcd = MinCovDet(
                            support_fraction=support_fraction,
                            random_state=random_state,
                        ).fit(X_sub)
                except Exception:
                    self.mcd = None
        return self

    def score_samples(self, df: pd.DataFrame) -> dict[str, pd.Series]:
        if self.preprocessor is None:
            raise RuntimeError("Detector must be fitted before scoring.")
        scores: dict[str, pd.Series] = {}
        if self.mcd is not None and len(self.valid_feature_indices) > 0:
            X = self.preprocessor.transform(df)
            X_sub = X[:, self.valid_feature_indices]
            try:
                with warnings.catch_warnings():
                    warnings.simplefilter("ignore")
                    raw_dist = self.mcd.mahalanobis(X_sub)
                scores["mcd"] = pd.Series(_scale01(raw_dist), index=df.index)
            except Exception:
                scores["mcd"] = pd.Series(0.0, index=df.index)
        else:
            scores["mcd"] = pd.Series(0.0, index=df.index)
        return scores
