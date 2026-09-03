from __future__ import annotations

import numpy as np
import pandas as pd
from statsmodels.tsa.seasonal import STL

from .ensemble import _scale01


class STLDetector:
    """STL (Seasonal-Trend Decomposition using LOESS) Anomaly Detector.

    Decomposes time series data into trend, seasonal, and residual components.
    Anomalies are detected based on the absolute residuals.
    Safely skips execution if data length is insufficient or time ordering is invalid.
    """

    def __init__(self, config: dict):
        self.config = config
        self.stl_config = config.get("stl", {})

    def fit_score(self, df: pd.DataFrame) -> dict[str, pd.Series]:
        if not self.stl_config.get("enabled", False):
            return {}

        time_col = self.stl_config.get("time_col", "visit_date")
        value_col = self.stl_config.get("value_col", "val1")
        period = int(self.stl_config.get("period", 7))

        if time_col not in df.columns or value_col not in df.columns:
            return {"stl": pd.Series(0.0, index=df.index)}

        try:
            # 時系列のソート
            sub_df = df[[time_col, value_col]].copy()
            sub_df[time_col] = pd.to_datetime(sub_df[time_col], errors="coerce")
            sub_df = sub_df.dropna(subset=[time_col, value_col])

            if len(sub_df) < max(2 * period, 10):
                # 系列長が不足している場合はスキップ
                return {"stl": pd.Series(0.0, index=df.index)}

            # ソートしてインデックスを保持
            sub_df = sub_df.sort_values(by=time_col)
            ts_values = sub_df[value_col].values

            res = STL(ts_values, period=period, robust=True).fit()
            resid = np.abs(res.resid)
            scaled_resid = _scale01(resid)

            # 元の順序にインデックスをマッピング
            result_series = pd.Series(0.0, index=df.index)
            result_series.loc[sub_df.index] = scaled_resid
            return {"stl": result_series}

        except Exception:
            # 形式不整合や分解失敗時のフォールバック
            return {"stl": pd.Series(0.0, index=df.index)}
