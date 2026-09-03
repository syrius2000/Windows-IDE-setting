# 序数・リッカート変数の高度な分析ガイド

> **スコープ外注記**: 本スキル（`vcd-categorical-analysis`）の主対象は**名義カテゴリカル変数**の独立性分析です。
> 序数変数・リッカート尺度を扱う場合は、本ドキュメントを参照の上、必要に応じて `gnm` パッケージや専用手法を検討してください。

## 1. 名義 vs 序数の違い

| 特性 | 名義（Nominal） | 序数（Ordinal） |
| :--- | :--- | :--- |
| 順序関係 | なし | あり（例: 「やや同意」<「同意」） |
| 適切なモデル | Poisson GLM（対数線形モデル） | 順序ロジスティック、線形スコアモデル |
| 検定統計量 | Pearson χ²、Cramér's V | Spearman ρ、Kendall τ、連関係数 |

## 2. リッカート尺度のクロス表分析

5段階・7段階のリッカート尺度をカテゴリカル変数として扱う場合：

### 2-way の場合

```r
# 線形スコアを割り当てた連関検定
vcd::assocstats(tab)           # χ²、Cramér's V
cor.test(as.numeric(df$A), as.numeric(df$B), method = "spearman")
```

### GNM による行列連関モデル（RC モデル）

```r
library(gnm)
# RC(1) モデル: 行・列に潜在スコアを推定
fit_rc <- gnm(Freq ~ Mult(1, A, B), family = poisson, data = df)
```

## 3. 本スキルの適用限界

本スキル (`vcd-categorical-analysis`) での対応範囲：

| 条件 | 対応 |
| :--- | :--- |
| 名義×名義 (2-way / 3-way) | ✓ 完全対応 |
| 序数×名義（序数を名義として扱う） | △ 分析可能だが情報損失あり |
| 純粋な序数×序数 | ✗ 非推奨（GNM 等を使用すること） |
| 4-way 以上 | ✗ スコープ外 |

## 4. 参考パッケージ

| パッケージ | 用途 |
| :--- | :--- |
| `gnm` | 一般化非線形モデル、RC 連関モデル |
| `ordinal` | 累積ロジットモデル、比例オッズモデル |
| `polycor` | 多列相関係数（polyserial, polychoric） |
| `vcdExtra` | vcd の拡張ユーティリティ |
