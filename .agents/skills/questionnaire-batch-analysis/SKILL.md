---
name: questionnaire-batch-analysis
description: Use when batch-analyzing multiple categorical questionnaire items from a question-config CSV with two-way or three-way tabulations.
license: MIT
metadata:
  version: "1.1"
---

**IRON LAW**: `--question-config` の必須列が欠けている、または `var1/var2/var3` が入力データに存在しない状態では実行しない。まず設定不整合を修正してから再実行する。

設問設定 CSV に基づき、複数設問を同一ルールで処理して `summary.csv` と設問別レポートを出力する。

## 共通品質契約

本スキルは `.agent/shared/analysis_quality_contract.md` を参照する。実行前には入力品質と設問設定、実行後には設問別成果物、横断総括、解釈保留、完了報告を契約に沿って確認する。

## 実行前の推奨ステップ: Pass 0 (Interactive Consultation)

分析を始める前に **`vcd-pass0-consultation`** スキルを使用して、データの検分と `analysis_config.json` の生成を行うことを強く推奨します。これにより、入力パスや出力先が一貫して管理されます。

## 実行チェックリスト

- [ ] **入力確認（必須）**: `--data`（非集計CSV）と `--question-config`（設問設定CSV）が存在する
- [ ] **共通設定確認**: `vcd-pass0-consultation` で生成した `analysis_config.json` がある場合は `--config` で渡す
- [ ] **設定確認（必須）**: `references/config-schema.md` の必須列を満たす
- [ ] **品質契約確認**: `.agent/shared/analysis_quality_contract.md` に従い、欠損、過剰水準、セルスパース性、設問タイプ、集約・除外の必要性を確認する
- [ ] **確認ゲート**: `--out` が既存ディレクトリの場合、上書きしてよいかユーザー確認
- [ ] **確認ゲート**: 設問数が多い（目安: 50件超）場合、実行時間増大を案内して継続確認
- [ ] **実行**: `templates/batch_runner.R` を実行
- [ ] **完了判定**: `summary.csv` と `{output_slug}/report.html` が生成されている
- [ ] **横断総括**: 複数設問を扱う場合は `cross_question_summary.md` を生成し、重要設問、解釈保留、次アクションを整理する

## 実行コマンド

```bash
Rscript .agent/skills/questionnaire-batch-analysis/templates/batch_runner.R \
  --config analysis_config.json \
  --question-config question_config.csv \
  --run-id run_001
```

- **`--config`**: `vcd-pass0-consultation` が出力した JSON 設定ファイル。
- **`--question-config`**: 設問ごとの分析ルールを定義した CSV ファイル（従来の `--config`）。
- **`--run-id`**: 実行識別子。指定すると成果物が隔離される。

※ `--config` を使用する場合、JSON 内の `input` が `--data` に、`question_config` が `--question-config` に自動的に割り当てられます。

- **`--run-id`**: 既定値 `run` のときは従来どおり `--out` 直下に出力。`run_001` や `auto`（JSTタイムスタンプ）など **`run` 以外**を指定すると、成果物は `--out/runs/<id>/` に隔離され、`summary.csv` の上書き衝突を避けられます。

## 出力

- `--out`（既定: `./skill_out/questionnaire/`）配下（`--run-id` が `run` 以外のときは `runs/<id>/` サブフォルダ）
  - `summary.csv`（`run_id` 列は **`--run-id` 解決後**の値。`auto` ならタイムスタンプ、`runs/<id>/` の `<id>` と一致）
  - `{output_slug}/report.html`
  - `{output_slug}/figures/residual_plot.png`
  - `cross_question_summary.md`（複数設問の横断総括。設問別成果物を置き換えず、上位索引として追加）

## 横断総括

複数設問を分析した場合は、`summary.csv` と設問別 `report.html` を根拠に `cross_question_summary.md` を生成する。

**構成（最低限）**:
- 主要結論: 重要設問と全体傾向
- 重要設問: 効果量、残差方向、セル数、設問タイプを合わせて説明
- 解釈保留: `status=error`、設定不整合、スパースセル、効果量が小さい大標本結果
- 設問タイプ別注意: `nominal_2way`、`likert_2way`、`nominal_3way` の解釈差
- 次アクション: 再分類、層別、追加確認、報告上の注意点

**禁止**:
- P値だけで設問を順位付けする
- `status=error` 行を結果解釈に混ぜる
- `likert_2way` を名義カテゴリと同じ表現だけで扱う
- `nominal_3way` を2-wayの単純な関連として断定する

## リソース（必要時のみ読む）

- `examples/question_config_example.csv`: 設問設定CSVの具体例
- `references/config-schema.md`: 設問設定CSVの必須列・最小例・よくある失敗
- `references/survey_prep.md`: 入力CSV準備の要点
- `references/interpretation.md`: 結果の読み方
- `references/workflow.md`: 実行フローと確認ゲート
- `.agent/shared/analysis_quality_contract.md`: 共通分析品質契約、横断総括、完了条件

## アンチパターン

- 必須列未確認のまま実行する
- `subset_expr` エラーを無視したまま結果を解釈する
- `status=error` 行を確認せずに `summary.csv` をそのまま採用する
- P値のみで設問をランキングする
- 横断総括を設問別レポートの代替として扱う
