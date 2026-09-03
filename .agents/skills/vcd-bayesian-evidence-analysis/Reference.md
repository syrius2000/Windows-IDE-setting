# リファレンス: vcd-bayesian-evidence-analysis

このスキルで使用されている固有の理論背景および共通指標へのガイドです。

## 1. 固有指標: Evidence Score (大標本フィルタリング)

大規模データセットにおいて、「統計的に有意だが実用的な意味がない」微小な差を除外するための独自指標です。

### 数式

$$\text{Evidence Score}_i = r_{i}^2 - k \cdot \log(N)$$

- $r_i$: ポアソンGLMから算出された標準化ピアソン残差。
- $k \cdot \log(N)$: BIC (Bayesian Information Criterion) に基づく複雑さへのペナルティ。
- **正値**: 統計的ノイズを超えた、実質的な関連の証拠（Evidence）あり。
- **負値**: サンプルサイズの大きさに起因する擬似的な有意である可能性が高い。

## 2. 共通指標へのポインタ

以下の基本概念については、中央統計リファレンスを参照してください。

- [ピアソン残差の定義と数式](../../../docs/Reference/evidence-analysis/stats_categorical.md#1-ピアソン残差-pearson-residuals)
- [Cramér's V による効果量（関連の強さ）判定](../../../docs/Reference/evidence-analysis/stats_categorical.md#2-cramérs-v-クラメールのv)
- [ベイズ因子の解釈基準 (Jeffreys Scale)](../../../docs/Reference/evidence-analysis/stats_bayesian.md#1-ベイズ因子-bayes-factor-bf10)

## 3. 分析の妥当性

- **Poisson GLM**: 各セルが独立したポアソン分布に従うと仮定し、対数線形モデルを適合させることで、多次元の交互作用（変数間の関連）を評価します。

## 参考文献

- Raftery, A. E. (1995). Bayesian Model Selection in Social Research. _Sociological Methodology_.
- [本プロジェクトの実験レポート](../../Large_Categorical_Data_Analysis_Report.md)
