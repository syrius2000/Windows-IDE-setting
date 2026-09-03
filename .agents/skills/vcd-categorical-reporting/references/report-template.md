# 判断ファースト・レポートテンプレート

```markdown
# VCD カテゴリカル分析結果（判断ファースト）

## 1. 結論と所見

（ここにサマリー1〜2文を記述）

### 主要な所見
- （所見1：主効果から言える強力な関連）
- （所見2：2-way交互作用から言える特異な偏り）
- （所見3：層別で特に目立つ傾向）

### 推奨アクション
- （データに基づくネクストステップや追加調査の提案）

---

## 2. 判断根拠

### 統計モデル比較

| モデル | 逸脱度 (Deviance) | 自由度 (df) | p値 (vs 前モデル) | Cramer's V (周辺) |
| :--- | :--- | :--- | :--- | :--- |
| 主効果 (Main) | [Deviance_Main] | [df_Main] | - | [V] |
| 2-way 交互作用 | [Deviance_2way] | [df_2way] | [p_value] | - |

> [!NOTE] 
> （p値や有意セル比率に基づく、モデルの当てはまりに関する解釈を1〜2行で）

### 注目すべき層（AI選択）

> [!TIP]
> AI は `[選択した層名]` の層が最も統計的に特筆すべき偏りを持つと判断し、以下のマトリックスを前面に配置しました。（理由：最大残差 X.XX, Cramer's V: Y.YY）

（ここに選択した層の `gt` マトリックスへのリンクまたは埋め込みを配置）
`./skill_out/vcd_categorical/matrix_data_layer.html`

---

## 3. 詳細データ

### 残差の全量探索

すべての層と変数の残差は、以下のインタラクティブテーブルでソート・検索可能です。

- [インタラクティブ残差テーブル（DT）](./skill_out/vcd_categorical/dt_residuals_data.html)

### 全層別マトリックス

（すべての層の `gt` マトリックスへのリンクをリスト化）
- [層 A のマトリックス](./skill_out/vcd_categorical/matrix_data_A.html)
- [層 B のマトリックス](./skill_out/vcd_categorical/matrix_data_B.html)
...

### モザイクプロット / Association プロット

（PNG ファイルへのリンクを配置）
- [Mosaic Plot](./skill_out/vcd_categorical/mosaic_data.png)
- [Association Plot](./skill_out/vcd_categorical/assoc_data.png)
```