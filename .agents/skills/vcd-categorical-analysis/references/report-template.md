# レポートテンプレート（analysis スキル向け）

> このファイルは `vcd-categorical-analysis` の出力成果物に関するテンプレート参照です。
> AI による判断ファーストレポートの構成テンプレートは `vcd-categorical-reporting/references/report-template.md` を参照してください。

## analysis.R 出力ファイル一覧

Pass 2 実行後に `./skill_out/vcd_categorical/` に生成されるファイル：

| ファイル | 内容 | 形式 |
| :--- | :--- | :--- |
| `data_profile_post.json` | 集約後のデータプロファイル | JSON |
| `summary_{label}.json` | モデル比較・残差統計サマリー | JSON |
| `residuals_{label}.csv` | 全セルの Pearson 残差（全モデル） | CSV |
| `residuals_{label}_significant.csv` | 有意セル上位20件（絶対値降順） | CSV |
| `matrix_marginal_{label}.html` | 周辺2変数の残差マトリックス（gt） | HTML |
| `matrix_{label}_{layer}.html` | 各層の残差マトリックス（gt、3-way 時） | HTML |
| `dt_residuals_{label}.html` | インタラクティブ残差テーブル（DT） | HTML |
| `mosaic_{label}.png` | モザイクプロット | PNG |
| `assoc_{label}.png` | アソシエーションプロット（2-way のみ） | PNG |
| `cotab_{label}.png` | 条件付きモザイクプロット（3-way のみ） | PNG |

## `summary_*.json` の主要フィールド

```json
{
  "interface_version": "2.1",
  "deviance_main": 数値,
  "df_main": 整数,
  "deviance_2way": 数値,
  "df_2way": 整数,
  "p_value_main_vs_2way": 数値,
  "cramers_v_marginal": 数値,
  "top_residuals_main": [{"cell": "A:B:C", "res": 数値}],
  "strata_summary": {
    "max_abs_res_per_stratum": {"層名": 数値},
    "cramers_v_per_stratum": {"層名": 数値},
    "n_significant_cells_5pct": 整数,
    "n_significant_cells_1pct": 整数
  }
}
```

## `residuals_*.csv` のカラム定義

| カラム | 型 | 説明 |
| :--- | :--- | :--- |
| `vars[1]` | factor | 変数1の水準 |
| `vars[2]` | factor | 変数2の水準 |
| `vars[3]` | factor | 変数3の水準（3-way 時のみ） |
| `Freq` | numeric | 観測度数 |
| `pearson_res` | numeric | Pearson 残差 |
| `abs_pearson_res` | numeric | Pearson 残差の絶対値 |
| `model_type` | character | `"Main Effects (A+B[+C])"` または `"2-way ((A+B[+C])^2)"` |
| `cell_label` | character | 水準を `:` で連結したセル識別子 |

## レガシー `report.Rmd` について

`templates/report.Rmd` は v1.x の一気通貫テンプレートです。
新規分析には使用せず、`analysis.R` の2パス方式を推奨します。
