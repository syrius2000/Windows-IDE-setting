---
name: vcd-categorical-analysis
description: Use when analyzing two-way or three-way nominal categorical data with the vcd workflow and producing an executive summary or dashboard.
license: MIT
metadata:
  author: vcd-categorical-analysis-skill
  version: "3.1"
---

名義カテゴリカル変数（クロス表 **2-way / 3-way**）の独立性検定（Poisson GLM）および残差の可視化を行う。**エージェント3ステップ**で集計・AI考察・レポート生成までを一貫して行う。Step 1 の R エンジンは **2パス**（`--profile` → `render_config.json` → `--render`）。

## 共通品質契約

本スキルは `.agent/shared/analysis_quality_contract.md` を参照する。Step 1では入力品質と出力生成、Step 2ではAIレビュー標準構成、Step 2.5では品質確認、Step 3ではHTMLと図表の読み取り確認を契約に沿って満たす。

## スコープ

| 項目 | 内容 |
| :--- | :--- |
| **次元** | **3-way まで**。4-way 以上は対象外（分割・集約を提案）。 |
| **出力先** | `./skill_out/vcd_categorical/run_<id>/`（`--out` は親ディレクトリ、`--run-id` 未指定時は JST タイムスタンプで自動隔離） |
| **正本** | `.agent/skills/vcd-categorical-analysis/` です。旧ミラーは廃止済みのため参照しません。 |

## 必須ワークフロー（実行フェーズ）

ユーザーが **「実行して」** 等で実行フェーズに入った後、**以下3ステップを連続実行**する。Step 1 完了前にチャットで要約して終了しない。

1. **Step 1（Data）**: R **2パス**を完遂し、`summary_*.json`・`categorical_results.json`・残差 CSV/HTML/PNG 等が生成されたことを確認する。
2. **Step 2（AI Review）**: JSON を読み、日本語考察を **`executive_summary.md`** として保存する（チャットへの長文出力のみで代替しない）。詳細が必要な場合は `vcd_analysis_report.md` も可。
3. **Step 2.5（Quality Check）**: 必要に応じて **`quality_check.md`** を保存し、P値偏重、残差方向、スパースセル、集約による情報損失、図表と本文の矛盾を確認する。
4. **Step 3（Report）**: **既定は `dashboard.Rmd`**。`report.Rmd` はレガシー代替。HTML 生成と読み取り確認を行ってから完了報告する。

## Step 1: R Engine（2パス）

**IRON LAW**: Pass 2（`--render`）の前に、必ず Pass 1 の `data_profile.json` を確認し、過大セル数・過剰水準に対する `render_config.json` を決める。

### Pass 1: プロファイリング

```bash
Rscript .agent/skills/vcd-categorical-analysis/templates/analysis.R \
  --profile \
  --data your_data.csv \
  --vars "var1,var2" \
  --freq "Freq" \
  --out ./skill_out/vcd_categorical/ \
  --run-id datasetA_20260417
```

- **`--run-id`（任意）**: 成果物を `<--out>/run_<prefix>/` に隔離。未指定時は JST タイムスタンプ。`auto` も可。
- **`--data` 省略時**: 内蔵 `HairEyeColor` を使用。
- **`--freq` 列が無い場合**: 自動集計し `Freq` として扱う。

### Pass 2: 本生成

`data_profile.json` を読んだうえで `render_config.json` を用意し、本生成を実行する。

```bash
Rscript .agent/skills/vcd-categorical-analysis/templates/analysis.R \
  --render \
  --config render_config.json \
  --data your_data.csv \
  --vars "var1,var2" \
  --freq "Freq" \
  --label "mydata" \
  --out ./skill_out/vcd_categorical/ \
  --run-id datasetA_20260417
```

### Step 1 確認ゲート

- 別データを連続解析する場合も、未指定の `--run-id` なら自動で別 `run_<id>/` に隔離される。明示名が必要なら `--run-id` を指定する。
- `--out` が既存の場合でも、run サブディレクトリ単位で上書きを避けられる。
- `render_config.json` で `collapse_below_n` 等を使う場合、情報損失の許容可否を確認する。
- `data_profile.json` で過剰水準、スパースセル、4-way以上相当の複雑性が見える場合は、集約、除外、層別、解釈保留のいずれかを提案する。

## Step 2: AI 考察

主に `summary_{label}.json` および `categorical_results.json` を読み、`executive_summary.md` を生成する。

**構成（最低限）**:
- 節1: 結論ファースト（何が分かったか、実務上何を保留するか）
- 節2: Cramér's V と Cohen 基準による全体関連
- 節3: `abs_pearson_res` ≥ 1.96 のセル（観測度数が期待度数より多い/少ない方向）
- 節4: 限界、解釈保留、次アクション

**禁止**: 英語本文（変数名・数式除く）、P値のみでの結論、残差方向を確認しない「多い/少ない」表現、セル数や集約による情報損失を無視した断定。

判断ファースト3章の詳細は `vcd-categorical-reporting/references/report-template.md`（非推奨スキル・参照テンプレ）を参照可。

## Step 2.5: 品質確認

Step 2 の後、必要に応じて `quality_check.md` を同じ出力ディレクトリに保存する。

**確認項目**:
- AIレビューが結論、根拠、限界、解釈保留、次アクションを含む。
- P値だけで結論していない。
- 残差方向、効果量、セル数、スパースセル、集約による情報損失を区別している。
- 図表、残差表、`categorical_results.json` と本文が矛盾していない。
- 重大な未解決事項がある場合は完了扱いにせず、ブロッカーまたは解釈保留として報告する。

## Step 3: レポート

### 既定: dashboard.Rmd

```bash
Rscript -e "rmarkdown::render(
  '.agent/skills/vcd-categorical-analysis/templates/dashboard.Rmd',
  output_file = 'dashboard.html',
  output_dir = './skill_out/vcd_categorical/',
  params = list(output_dir = './skill_out/vcd_categorical/'),
  knit_root_dir = getwd()
)"
```

`executive_summary.md` が無いとダッシュボードに警告が出る。Step 2 を省略しない。
`quality_check.md` がある場合は、未解決事項が残っていないか確認してから完了報告する。

### 代替: report.Rmd（レガシー）

```bash
Rscript -e "rmarkdown::render(
  '.agent/skills/vcd-categorical-analysis/templates/report.Rmd',
  output_file = 'report.html',
  output_dir = './skill_out/vcd_categorical/',
  params = list(output_dir = './skill_out/vcd_categorical/'),
  knit_root_dir = getwd()
)"
```

## 生成ファイル

| 出力 | Step / Pass | 説明 |
| :--- | :--- | :--- |
| `data_profile.json` | Pass 1 | 次元・水準・セル数プロファイル |
| `data_profile_post.json` | Pass 2 | 集約後プロファイル |
| `summary_{label}.json` | Pass 2 | モデル比較・残差統計サマリー |
| `residuals_{label}.csv` 等 | Pass 2 | 残差・gt/DT HTML・PNG |
| `categorical_results.json` | Pass 2 | ダッシュボード連携用 JSON |
| `executive_summary.md` | Step 2 | AI 日本語サマリー |
| `quality_check.md` | Step 2.5 | AIレビュー・図表・解釈保留の品質確認 |
| `dashboard.html` | Step 3（既定） | 統合ダッシュボード |

## リソース

| パス | 役割 |
| :--- | :--- |
| `templates/analysis.R` | 2パス集計パイプライン |
| `templates/dashboard.Rmd` | **既定** HTML ダッシュボード |
| `templates/report.Rmd` | 代替 Rmd |
| `references/interface.md` | JSON/CSV 契約 |
| `references/workflow.md` | 3ステップ + 2パス図 |
| `references/ai-narrative-workflow.md` | AI による考察文生成、残差・効果量・層別差の説明順序、過剰主張を避ける表現ルール |
| `.agent/shared/analysis_quality_contract.md` | 共通分析品質契約、Pass 2.5、完了条件 |
| `tests/verify_skill.sh` | 検証スクリプト |

## 関連スキル

- `vcd-pass0-consultation` … 分析前のデータ検分・次元選定
- `vcd-bayesian-evidence-analysis` … 大標本時の効果量・BIC/BF 視点
- `vcd-categorical-reporting` … **非推奨**（本スキル Step 2 に統合。参照テンプレのみ）
- `mysql-table-cardinality` … DB 探索が先の場合
