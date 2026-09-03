# リファレンス: vcd-categorical-analysis

カテゴリカルデータの独立性検定と、残差ベースの可視化に関する理論リファレンスです。

## 1. 分析手法: 対数線形モデル (Log-linear Models)

変数が3つ以上（3-way以上）の場合、単純な2次元のカイ二乗検定では捉えきれない複雑な交互作用を評価するために Poisson GLM を用いた対数線形モデルを使用します。

- **独立モデル**: すべての変数が互いに独立であると仮定。
- **2次交互作用モデル**: 変数のペア（AB, BC, AC）間の関連のみを考慮。
- **飽和モデル**: すべての交互作用を考慮（観測値と完全に一致）。

## 2. 共通指標へのポインタ

- [ピアソン残差によるセルの特異性評価](../../../docs/Reference/evidence-analysis/stats_categorical.md#1-ピアソン残差-pearson-residuals)
- [Cramér's V による全体の関連性の強さ](../../../docs/Reference/evidence-analysis/stats_categorical.md#2-cramérs-v-クラメールのv)

## 3. 可視化の解釈
- **モザイクプロット (Mosaic Plots)**: セルの面積が観測度数を表し、色が残差の大きさ（偏りの強さ）を表します。青色は「期待より多い」、赤色は「期待より少ない」ことを視覚的に示します。

## 推奨 Reference

- `references/workflow.md`: 分析の順序と成果物。
- `references/glm-gnm-goodness.md`: GLM/GNM、適合度、残差診断。
- `references/ordinal-likert-advanced.md`: 順序尺度・Likert の扱い。
- `references/ai-narrative-workflow.md`: 数値結果から考察文へ変換する際の判断順序。

## 参考文献
- Meyer, D., Zeileis, A., & Hornik, K. (2006). The Strucplot Framework: Visualizing Multi-way Contingency Tables with vcd. *Journal of Statistical Software*.
- 舟尾 暢男. (2011). 『The R Book (データ解析のスタンダード)』. 九天社.
