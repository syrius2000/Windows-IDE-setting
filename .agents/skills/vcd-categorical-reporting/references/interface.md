# VCD Analysis ↔ Reporting インターフェース契約

interface_version: "2.1"

## 出力ディレクトリ

`./skill_out/vcd_categorical/`（分析側で `--run-id` 指定時は `runs/<id>/` サブディレクトリ）

## Pass 1 出力: data_profile.json
## Pass 2 出力: data_profile_post.json

| フィールド | 型 | 説明 |
| :--- | :--- | :--- |
| n_dimensions | int | 変数の数（2 or 3） |
| variables | object | 変数名をキー、{n_levels, levels} を値 |
| total_cells | int | 全セル数 |
| total_cells_2way_marginal | int | 2-way 周辺表のセル数 |
| n_nonzero_cells | int | Freq > 0 のセル数 |
| sparsity_ratio | float | n_nonzero_cells / total_cells |
| warning | string | ゼロセル等の警告メッセージ（無ければ null） |

## Pass 2 入力: render_config.json

| フィールド | 型 | 既定値 | 説明 |
| :--- | :--- | :--- | :--- |
| collapse_below_n | int | 0 | この Freq 以下のセルを集約（0=集約しない） |
| max_levels_per_var | int | 999 | 各変数の最大水準数（超過分は集約） |
| strata_to_render | array(string) | [] | gt マトリックスを生成する層（空=全層） |
| gt_matrix_vars | array(int) | [1, 2] | マトリックスの行・列に使う変数インデックス |
| plot_mode | string | "auto" | "auto" / "always" / "residual_only" |

※ R側は未知のキーを無視し、不正な型は既定値にフォールバックする（`validate_config`）。

## Pass 2 出力ファイル規約

| ファイル名パターン | 形式 | 生成元 | 消費先 |
| :--- | :--- | :--- | :--- |
| `data_profile.json` | JSON | analysis (Pass 1) | reporting |
| `data_profile_post.json` | JSON | analysis (Pass 2) | reporting |
| `summary_{data}.json` | JSON | analysis (Pass 2) | reporting |
| `residuals_{data}.csv` | CSV | analysis (Pass 2) | reporting |
| `residuals_{data}_significant.csv` | CSV | analysis (Pass 2) | reporting |
| `matrix_marginal_{data}.html` | gt HTML | analysis (Pass 2) | reporting |
| `matrix_{data}_{layer}.html` | gt HTML | analysis (Pass 2) | reporting |
| `dt_residuals_{data}.html` | DT HTML | analysis (Pass 2) | reporting |
| `mosaic_{data}.png` | PNG | analysis (Pass 2) | reporting |
| `assoc_{data}.png` | PNG | analysis (Pass 2) | reporting |
| `cotab_{data}.png` | PNG | analysis (Pass 2) | reporting |

## summary_*.json スキーマ

```json
{
  "interface_version": "2.1",
  "test_used": "string",
  "models_tested": ["string"],
  "deviance_main": "number",
  "df_main": "integer",
  "deviance_2way": "number",
  "df_2way": "integer",
  "p_value_main_vs_2way": "number",
  "cramers_v_marginal": "number",
  "top_residuals_main": [{"cell": "string", "res": "number"}],
  "top_residuals_2way": [{"cell": "string", "res": "number"}],
  "strata_summary": {
    "strata_var": "string",
    "n_strata": "integer",
    "max_abs_res_per_stratum": {"layer_name": "number"},
    "cramers_v_per_stratum": {"layer_name": "number"},
    "n_significant_cells_5pct": "integer",
    "n_significant_cells_1pct": "integer",
    "total_cells": "integer"
  }
}
```

## 変更ルール

- analysis 側が出力フォーマットを変更する場合、interface_version をインクリメントすること。
- reporting 側は interface_version を確認し、非互換の場合はユーザーに警告すること。
