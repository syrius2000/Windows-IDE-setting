---
name: vcd-pass0-consultation
description: Use when starting a new categorical data analysis to inspect data, select dimensions, and define the analysis scope before statistical computation.
---

# VCD Pass 0: Interactive Consultation

大標本カテゴリカルデータ分析（`vcd-bayesian-evidence-analysis`）の最初の一手として、データの統計的性質を検分し、分析の軸（次元）や層別の要否を決定するための対話型スキル。

## 共通品質契約

本スキルは `.agent/shared/analysis_quality_contract.md` を参照する。Pass 0では、統計計算前の入力品質、分析スコープ、変数選択、集約・除外・層別の判断を契約に沿って確認し、`data_analysis_scope.md` と `analysis_config.json` に反映する。

## ワークフロー

### 1. データ物理検分 (Inspection)
まず、以下のスクリプトを実行して、データの客観的な統計情報を取得します。

```bash
Rscript .agent/shared/inspect_data.R <path_to_your_data.csv> --out-dir output/<project_name>/run_<id>/
```

実行後、生成された `output/<project_name>/run_<id>/inspection_results.json` を読み取り、以下の点を確認します：

- 各変数の水準数（多すぎないか？）
- 度数の分布（極端に少ないセルはないか？）
- 欠損値の有無
- 度数列（`Freq` 等）の有無
- 過剰次元、スパースセル、集約による情報損失の可能性

### 2. インタラクティブ提案 (Consultation)
検分した統計量に基づき、ユーザーに対して以下の2点を主軸に提案を行います。

#### A. 次元削減の提案

- 変数が多い（4次元以上）場合、交互作用が複雑になりすぎて解釈が困難になります。
- 目的変数に対して寄与が低いと思われる変数や、水準数が多すぎる変数の除外・集約を提案します。

#### B. 層別解析の提案

- 特定の属性（例：性別、地域）によって構造が全く異なると予想される場合、全体分析ではなく層別（分割）して分析することを提案します。

### 3. 設計図と構成の出力 (Artifacts)
ユーザーの合意が得られたら、以下の2つのファイルを生成します。保存先は `output/<project_name>/run_<id>/` を推奨します。

1. **`data_analysis_scope.md`**:
   - 分析の背景、選択した変数の根拠、除外した変数の理由を記録した人間用ドキュメント。
   - 集約、除外、層別、解釈保留が必要な場合は、その理由と影響を記録する。
2. **`analysis_config.json`**:
   - Pass 1 (`analysis.R` 等) に渡すための設定ファイル。
   - `vcd-bayesian-evidence-analysis/references/analysis_config.schema.json` に従うフラットな JSON:
     - `input`: 入力CSVのパス
   - `vars`: 分析対象の変数リスト (`["var1", "var2"]`)
   - `freq`: 度数列の名前 (例: `"Freq"`)
   - `response_var`: 応答変数。3次元以上でCramér's Vを算出する場合は、`vars` に含まれる目的変数を指定する
   - `output_dir`: 出力の親ディレクトリ
   - `run_id`: 実行識別子
   - 任意キーとして `dataset_name`, `response_var`, `top_k`, `threshold_k`, `large_n_threshold`, `ebic_gamma`, `ebic_p`, `level2_factor`, `level3_factor`, `arm_top_rules`, `arm_min_support`, `arm_min_confidence` を指定できます。

最小例:

```json
{
  "input": "examples/data/titanic.csv",
  "vars": ["Class", "Sex", "Age", "Survived"],
  "freq": "Freq",
  "response_var": "Survived",
  "output_dir": "output/titanic",
  "run_id": "titanic_v1"
}
```

生成後は Pass 1 に進む前に検証します。`analysis.R --config` は自動で検証するため、次のコマンドで設定・列名・数値型の不備を統計計算前に検出できます。

```bash
Rscript .agent/skills/vcd-bayesian-evidence-analysis/templates/analysis.R --config output/project/run_v1/analysis_config.json
```

### 4. 次の一手へのガイド (The Guidance)
成果物を生成した後、ユーザーに対して次に実行すべき `vcd-bayesian-evidence-analysis` のコマンドを明示的に案内します。

```bash
# 例
Rscript .agent/skills/vcd-bayesian-evidence-analysis/templates/analysis.R --config output/project/run_v1/analysis_config.json
```

## 完了条件

- `inspection_results.json` を読んだうえで、入力品質と分析スコープの確認結果を説明できる。
- `data_analysis_scope.md` と `analysis_config.json` の保存先を示せる。
- 未解決の欠損、過剰水準、スパースセル、設定不整合がある場合は、Pass 1へ進む前の解釈保留またはブロッカーとして示す。

## アンチパターン

- **全変数投入**: 「とりあえず全部」は次元の呪いと解釈の混乱を招きます。Pass 0 で絞り込むことが重要です。
- **検分なしの実行**: データのスパース性や水準数を知らずに計算を回すと、Pass 1 でエラーや無意味な結果が出る原因になります。
