---
name: vcd-bayesian-evidence-analysis
description: Use when analyzing large-sample categorical cross-tabs with Poisson GLM, Bayesian evidence, Evidence Score, or effect sizes, and when separating statistical significance from practical importance.
license: MIT
metadata:
  version: "1.0"
---

**IRON LAW**: Pass 3（`dashboard.html`）は既定で Pass 2 産物（`executive_summary.md`）が無いと失敗する。プレビュー目的でのみ `require_pass2 = FALSE` を明示し、それ以外では Pass 1→2→3 の順序を崩さない。

大標本における「P値の罠」を克服し、ベイズファクター（BF）・Evidence Score・効果量（Cramér's V / Fei）を併用して「統計的有意性」と「実質的意義」を峻別するAI連携型分析パイプライン。

`mysql-create-query-support` などで検証済みになった抽出 SQL は、repo root の `sql/validated/` 配下を正本として参照する。分析用 CSV は、その SQL の粒度・除外条件・検証結果と対応するものを使う。

## 共通品質契約

本スキルは `.agent/shared/analysis_quality_contract.md` を参照する。Pass 0では分析スコープ、Pass 1では統計計算と主要JSON、Pass 2ではAIレビュー標準構成、Pass 2.5では品質確認、Pass 3ではHTMLと図表の読み取り確認を契約に沿って満たす。

## 統計的背景

本スキルの **推論本体**は、(1) セル度数に対する **独立 Poisson GLM** の標準化ピアソン残差から作る **Evidence Score**、(2) **独立 Poisson 対 飽和 Poisson** の EBIC に基づく **$\mathrm{BF}_{10}$ 近似**、および (3) **Cramér's V / Fei** です。`dashboard.html` の用語解説と同じ整理です。

### 指標の粒度契約

- **セル単位**: `Residual` と `Evidence_Score` は、各セルの観測度数が独立モデルの期待値からどれだけ逸脱したかを示す。
- **全体効果量**: `Cramér's V` / `Fei` は、セルごとの列ではなく、表全体または分析全体の効果量として扱う。
- **全セル表の禁止事項**: `dashboard.html` の全セル・エビデンス・テーブルに Cramér's V を行ごとの列として表示しない。必要な場合は上部カード、効果量説明枠、または比較レポートの別枠に表示する。
- **未算出時**: `effects.effect_status`, `effects.effect_reason` を確認し、値を捏造しない。Pass 2 では「未算出」と理由を明示する。

### Evidence Score

$$\mathrm{Evidence\;Score}_{ijk} = r_{ijk}^2 - k \cdot \log(N)$$

- $r_{ijk}$: **独立** Poisson GLM（主効果のみ）に基づくセル $(i,j,k)$ の標準化ピアソン残差
- $k \cdot \log(N)$: 多段階閾値（CLI の `--threshold_k`、JSON の `thresholds.threshold_k` と `core.log_n`）
- **正値 → 実質的エビデンス**（ノイズを超える逸脱）／**負値 → ノイズレベル**（独立モデルで説明しうる範囲）

### Bayes Factor（EBIC近似）

$$\log \mathrm{BF}_{10} \approx \tfrac{1}{2}\bigl(\mathrm{EBIC}_{\mathrm{indep}} - \mathrm{EBIC}_{\mathrm{sat}}\bigr)$$

- $\mathrm{EBIC}_{\mathrm{indep}}$: **主効果のみ**の Poisson（独立構造）、$\mathrm{EBIC}_{\mathrm{sat}}$: **セルごとに別期待値**の飽和 Poisson
- Jeffreys の目安: $\mathrm{BF}_{10} > 100$ 決定的、$> 10$ 強い、$> 3$ 中程度
- $\mathrm{BF}_{10} = \infty$ に近い極大値: 独立モデルでは到底説明しきれない強い逸脱（飽和側が圧倒的に有利）

### BIC ペナルティの類比（$M_0$ / $M_1$）

ダッシュボードでは、**「主効果に対し、ある1セルだけ余分なパラメータを1つ足すと BIC のペナルティが $\log(N)$ だけ増える」**という直観を、連続反応の加法モデル（$y_{ijk}=\mu+\alpha_i+\beta_j+\gamma_k+\varepsilon$ と、1セルだけ $\delta$ を付ける $M_1$）で **類比**として示しています。これは **ペナルティ項の読み**用であり、セル度数 $n_{ijk}$ の Poisson 期待値の式そのものではありません。$\mathrm{BF}_{10}$ の比較は **独立 Poisson vs 飽和 Poisson** です。

## 前提条件

- `R` (≥ 4.0) および Pass 1/3 で `pacman` によりロードされるパッケージ（手動導入する場合は `references/dependencies.md` を参照）：
  - `dplyr`, `tidyr`, `jsonlite`, `DT`, `htmlwidgets`, `htmltools`, `effectsize`, `knitr`, `rmarkdown`, `pacman`
- 入力データは UTF-8 エンコードの CSV または R 組み込みデータセット名を指定

## 実行前の推奨ステップ: Pass 0 (Interactive Consultation)

大規模・多次元データを分析する場合、いきなり Pass 1 を実行する前に **`vcd-pass0-consultation`** スキルを使用して分析のスコープを確定させることを強く推奨します。

- **理由**: 変数が多すぎると「次元の呪い」により結果の解釈が困難になり、偽陽性のリスクも高まります。
- **手順**: `.agent/shared/inspect_data.R` でデータを検分し、AI と対話して重要な軸（次元）や層別解析の必要性を判断してください。
- **成果物**: Pass 0 を経ることで、Pass 1 でそのまま利用可能な `analysis_config.json` が得られます。正準仕様は `references/analysis_config.schema.json` です。

`analysis_config.json` の最小例:

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

`analysis.R --config` は、Pass 1 の統計計算前に `analysis_config.json` を検証します。必須キー、`vars` / `freq` の入力CSV列との一致、数値パラメータの型が不正な場合は日本語エラーで停止します。未知キーは警告を出しつつ読み込みます。

## 実行手順（3-Pass・順序厳守）

**必須の流れ:** Pass 1 完了 → Pass 2 で `executive_summary.md` を `output_dir` に保存 → 必要に応じて Pass 2.5 で `quality_check.md` を保存 → Pass 3 で `dashboard.html` を生成。Pass 3 は既定で `executive_summary.md` が無いと **エラーで停止**する（`dashboard.Rmd` の `params$require_pass2`、既定 `TRUE`）。プレビュー専用で Pass 2 を省略する場合のみ `require_pass2 = FALSE` を指定する。

### Pass 1: R Engine（統計計算）

```bash
Rscript .agent/skills/vcd-bayesian-evidence-analysis/templates/analysis.R \
  --input your_data.csv \
  --output_dir ./skill_out/vcd_bayesian/ \
  --run-id datasetA_20260417 \
  --dataset_name mydata \
  --response_var outcome_col \
  --top_k 10 \
  --threshold_k 1 \
  --large_n_threshold 1000
```

Pass 0 が生成した config を使う場合:

```bash
Rscript .agent/skills/vcd-bayesian-evidence-analysis/templates/analysis.R \
  --config output/titanic/run_v1/analysis_config.json
```

| オプション | 既定値 | 説明 |
| :--- | :--- | :--- |
| `--run-id` | （なし） | 指定時は `<--output_dir>/run_<prefix>/` に隔離（`prefix` = 解決後 `run_id` の先頭16文字。未指定時は入力から算出したハッシュの先頭16文字）。`auto` は JST タイムスタンプに展開される |
| `--response_var` | （なし） | 3次元以上でCramér's Vを算出するための応答変数。指定時は「予測側水準の組み合わせ × 応答変数」の2次元表へ畳み込んで全体効果量を算出する |
| `--top_k` | 10 | Top-K 表示件数 |
| `--threshold_k` | 1 | 多段階閾値係数（Score > k × log(N)） |
| `--large_n_threshold` | 1000 | 大規模データモード切替閾値 |
| `--ebic_gamma` | 0.5 | EBIC 追加ペナルティ係数（γ） |
| `--ebic_p` | 飽和モデル係数数 | EBIC の候補パラメータ数（省略時は自動） |
| `--level2_factor` | 2 | 多段階閾値 Level2 倍率 |
| `--level3_factor` | 3 | 多段階閾値 Level3 倍率 |
| `--arm_top_rules` | 20 | ARM（support/confidence/lift）上位件数 |
| `--arm_min_support` | 0.01 | ARM 最小 support |
| `--arm_min_confidence` | 0.10 | ARM 最小 confidence |
| `--help` | - | CLI ヘルプを表示 |
| `--help_stats` | - | 統計指標ガイドを表示 |

※ `--input` が無い場合は R 組み込みの `HairEyeColor` データセットを使用する。
※ `--vars` で分析対象変数を指定可能（省略時は全変数を使用）。
※ `--freq` で度数列名を指定可能（省略時は `Freq`）。
※ `--response_var` は `--vars` に含める。未指定または算出不可の場合、Cramér's Vは未算出理由付きで `effects.effect_status = "not_applicable"` または `"failed"` になる。
※ ARM は **行データのみ** 対象。`Freq` がある場合は重みとして扱う。

### Pass 2: AI 考察生成（本スキル）

Pass 1 が生成した `evidence_results.json` を読み込み、以下の **日本語エグゼクティブ・サマリー** を `executive_summary.md` として生成する。

**AI プロンプト指示**:

あなたは **計量薬理学・医療統計の専門家** です。`evidence_results.json` を入力として受け取り、以下の4節構成で日本語考察を執筆してください。

#### 節1: 全体的な関連性の評価（ベイズファクター + 効果量）

- **重要: 見出しには必ず `####` (H4) を使用してください。**
- 冒頭で主要結論、実務上の意味、解釈保留の有無を先に記述
- `bf_independence` の値を明示し、Jeffreys スケールで解釈
- `model_selection.method`（EBIC）と `model_selection.bf10_bic`（比較用）があれば併記
- `effects.primary` が `cramers_v` または `fei` であることを踏まえて、実用的意義を評価
- `effects.effect_status` が `computed` の場合のみ、Cramér's V / Fei の数値を示す。`not_applicable` または `failed` の場合は「未算出」と `effects.effect_reason` を明記し、値があるかのように書かない
- Cramér's V は全体効果量であり、`core.full_data` の各セルへ割り付ける指標ではないことを明示
- BF = Inf → 「独立モデルでは到底説明不可能な極めて強固な交互作用」
- 対象次元数と変数名を明記

#### 節2: エビデンス・スコアによる「真の関連」の抽出

- **重要: 見出しには必ず `####` (H4) を使用してください。**
- Evidence Score の定義を数式で示す: $\mathrm{Evidence\;Score} = r^2 - k \cdot \log(N)$（JSON の `thresholds.threshold_k` と `core.log_n` を明示）
- `thresholds.level1/level2/level3` の値と意味（強度レベル）を説明
- 正値セル数 / 全セル数を集計して記載
- 大標本でのP値の限界（type I error inflation）に言及

#### 節3: 多次元交互作用の解釈（層別エビデンス）

- **重要: 見出しには必ず `####` (H4) を使用してください。**
- `core.top_k_data` に含まれる **上位セル**（Evidence Score 降順）を具体的数値付きで記述
- **レイアウト**: セル一覧は長文の連続を避け、読みやすい **Markdown表**（`| 変数 | 水準 | … |`）または **番号付き箇条書き**で整列させる（Pass 3 の Top-K 表と対応しやすい形）
- Evidence Score **下位3セル**（負の絶対値上位）も `core.full_data` から参照して記述
- 層別変数がある場合、層ごとのスコア差異を比較・考察

#### 節4: 結論と実務的示唆

- **重要: 見出しには必ず `####` (H4) を変えずに使用してください。**
- 分析全体の要約（2〜3文）
- 実務・学術的に重要な発見の強調
- 欠損、スパースセル、過剰水準、集約、サンプルサイズに由来する限界
- 次アクション（再分類、層別、追加確認、報告上の注意点）

**禁止事項**:

- 英語での考察出力（数式・変数名を除く）
- Evidence Score 負値セルを「有意な関連あり」と表現すること
- P値を主な根拠として使用すること
- 2次元データとして3次元データを解釈すること
- 時間順序や介入情報がない結果から因果を断定すること

#### 大規模データモード（N > 1,000 の場合）
`large_sample_mode` が `true` の場合、以下を必ず考察に含めること：

- Cramér's V の値と Cohen 基準による評価を冒頭に明示
- Cramér's V が未算出の場合は、未算出理由と、Evidence Scoreがセル単位指標であることを明示
- Evidence Score が多数のセルで正値になっている場合、「大標本効果による飽和の可能性」に言及
- P値ではなく効果量を主な根拠として使用
- `thresholds.threshold_k` が 1 より大きい場合、その閾値設定の根拠を記述
- `warnings.practical_significance_low` が `true` の場合は Dual-Filter 警告を明示

### Pass 2.5: 品質確認

Pass 2 の後、必要に応じて `quality_check.md` を `executive_summary.md` と同じ run 出力ディレクトリに保存する。

**確認項目**:

- `executive_summary.md` が結論、根拠、限界、解釈保留、次アクションを含む。
- P値、効果量、Evidence Score、Bayes Factor、セル数、サンプルサイズを読み分けている。
- Evidence Score 負値セルを関連ありと扱っていない。
- 大標本効果、スパースセル、過剰水準、集約による情報損失を必要に応じて明示している。
- `evidence_results.json`、Top-K表、`dt_table.html`、`dashboard.html`予定の図表と本文が矛盾していない。
- 重大な未解決事項がある場合は完了扱いにせず、ブロッカーまたは解釈保留として報告する。

### Pass 3: ダッシュボード生成

`dashboard.html` は **`evidence_results.json` と同じ `run_<prefix>/` ディレクトリ**（`run_output_dir_from_root` と同じ規則）に出力する。Pass 1 と同じ **out_root** を `--output_dir` に渡す（Rmd の `params$output_dir` は out_root のまま、HTML の保存先だけが `run_<prefix>/` 配下になる）。

```bash
Rscript .agent/skills/vcd-bayesian-evidence-analysis/templates/render_dashboard.R \
  --output_dir ./skill_out/vcd_bayesian/
```

プレビュー専用（Pass 2 省略）:

```bash
Rscript .agent/skills/vcd-bayesian-evidence-analysis/templates/render_dashboard.R \
  --output_dir ./skill_out/vcd_bayesian/ \
  --no-require-pass2
```

| フラグ / `dashboard.Rmd` パラメータ | 既定 | 説明 |
| :--- | :--- | :--- |
| `--no-require-pass2` | （指定しない） | 指定時のみ `executive_summary.md` なしでレンダー（プレビュー専用） |
| `require_pass2`（Rmd） | `TRUE` | `render_dashboard.R` では既定で `TRUE`。上記フラグで `FALSE` になる |

## 確認ゲート

- 別データの解析を続ける場合は **`--run-id`** で `run_<prefix>/` を分けるか、`--output_dir` 自体を変えて上書きを避ける（`vcd-categorical-analysis` の `runs/<id>/` とはレイアウトが異なる点に注意）。
- `output_dir` に既存の `evidence_results.json` / `dashboard.html` がある場合、上書き実行の可否を確認する。
- `require_pass2 = FALSE` で Pass 3 を先行する場合、プレビュー目的であることを確認し、本番成果物に使わないことを明示する。

## 生成されるファイル

| 出力 | 説明 |
| :--- | :--- |
| `run_meta.json` | Pass 1 時に `run_<prefix>/` に出力。`out_root` は `--output_dir`、`run_output_dir` は当該 `run_<prefix>/`（`.agent/shared/run_scope.R` の `write_run_meta`） |
| `evidence_results.json` | `core/model_selection/effects/thresholds/warnings/extensions` のモジュール構造 + 旧キー互換（Pass 1） |
| `dt_table.html` | 列フィルタ付きインタラクティブDTテーブル（+青/−赤色分け）（Pass 1）。`evidence_results.json` と同じ **`run_<prefix>/` 成果ディレクトリ**に保存される（`selfcontained` 時は同隣に補助ファイルが増える場合あり） |
| `executive_summary.md` | AI日本語エグゼクティブサマリー（Pass 2） |
| `quality_check.md` | AIレビュー・指標解釈・図表整合・解釈保留の品質確認（Pass 2.5） |
| `dashboard.html` | Top-K＋折りたたみ全テーブル＋用語解説統合HTMLダッシュボード（Pass 3）。**`run_<prefix>/` 直下**（`dt_table.html` と同階層） |

## アンチパターン対策

| # | アンチパターン | 対策 |
|---|-------------|------|
| A | 2次元への固執 | 次元数を `dim(table)` で自動判定、常に Poisson GLM を使用 |
| B | レンダリングパス失敗 | Pass 3 は `render_dashboard.R` を使い、リポジトリルートを `knit_root_dir` に固定する |
| C | 英語のみ出力 | すべての出力（ラベル・UI・考察）を日本語にデフォルト設定 |
| D | Pass 2 を飛ばして Pass 3 のみ実行 | 既定 `require_pass2 = TRUE` で `executive_summary.md` 必須。意図的プレビューのみ `FALSE` |
| E | レビュー過剰主張 | `quality_check.md` でP値偏重、因果断定、Evidence Score負値セルの誤解釈、図表矛盾を確認 |

## 連携スキル

- **前処理**: `vcd-categorical-analysis` （残差分析・モザイクプロット）
- **レポート**: `vcd-categorical-reporting` （AI判断レポート生成）
