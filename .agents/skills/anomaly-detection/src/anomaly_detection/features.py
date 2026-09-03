from __future__ import annotations

import numpy as np
import pandas as pd
from sklearn.compose import ColumnTransformer
from sklearn.impute import SimpleImputer
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder, RobustScaler


def infer_feature_columns(df: pd.DataFrame, config: dict) -> tuple[list[str], list[str]]:
    specified = config.get("value_columns", {})
    numeric = [c for c in specified.get("numeric", []) if c in df.columns]
    categorical = [c for c in specified.get("categorical", []) if c in df.columns]
    if not numeric:
        numeric = list(df.select_dtypes(include=["number", "bool"]).columns)
    if not categorical:
        categorical = list(df.select_dtypes(include=["object", "category", "string"]).columns)
        categorical = [c for c in categorical if c not in {"record_id", "subject_id"}]
    return numeric, categorical


def build_preprocessor(df: pd.DataFrame, config: dict) -> ColumnTransformer:
    numeric, categorical = infer_feature_columns(df, config)
    numeric_pipeline = Pipeline([
        ("imputer", SimpleImputer(strategy="median")),
        ("scaler", RobustScaler()),
    ])
    categorical_pipeline = Pipeline([
        ("imputer", SimpleImputer(strategy="most_frequent")),
        ("onehot", OneHotEncoder(handle_unknown="ignore", sparse_output=False)),
    ])
    return ColumnTransformer([
        ("num", numeric_pipeline, numeric),
        ("cat", categorical_pipeline, categorical),
    ], remainder="drop")


def robust_mad_scores(df: pd.DataFrame, config: dict) -> pd.Series:
    numeric, _ = infer_feature_columns(df, config)
    if not numeric:
        return pd.Series(0.0, index=df.index)
    X = df[numeric].apply(pd.to_numeric, errors="coerce")
    med = X.median(axis=0)
    mad = (X - med).abs().median(axis=0).replace(0, np.nan)
    z = ((X - med).abs() / (1.4826 * mad)).replace([np.inf, -np.inf], np.nan).fillna(0.0)
    max_z = z.max(axis=1)
    thr = float(config.get("robust_stats", {}).get("mad_z_threshold", 4.5))
    return (max_z / thr).clip(0, 1)
