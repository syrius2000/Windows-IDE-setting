# 日常運用マニュアル（Daily Operations Manual）

本マニュアルは、Case Projectにおける日々の解析ワークフロー、Python/Rによる標準解析、SASログ確認、成果物の承認公開、およびテンプレート更新の手順を解説します。

---

## 1. 標準的な解析フロー（2つのパターン）

### パターン A: Python / R 中心解析（SAS不要・推奨標準フロー）
SASライセンスを持たない環境、またはモダンな言語スタック単体で解析を行う場合の標準フローです。

```mermaid
graph LR
    Data["外部保護データ<br>(C:\\RWD_DATA)"] --> PyR["1. Python / R 抽出・統計解析<br>(DuckDB / Polars / tidyverse)"]
    PyR --> OutPriv["outputs/private/<br>(中間集計・個票ログ)"]
    OutPriv --> Rep["2. 報告書生成<br>(Quarto / PPTX / Slidev)"]
    Rep --> Audit["3. 開示リスク人手レビュー<br>(release-manifest.yml)"]
    Audit --> Release["4. 成果物公開<br>(outputs/release/)"]
```

### パターン B: 既存SAS資産併用フロー（SAS保有時のみ）
既存のSASマクロやレガシー前処理コードを活用する場合のフローです。

```mermaid
graph LR
    Data["外部保護データ<br>(C:\\RWD_DATA)"] --> SAS["1. SAS抽出・前処理<br>(src/sas-cp932/)"]
    SAS --> OutPriv["outputs/private/<br>(中間データ・ログ)"]
    OutPriv --> PyR["2. Python/R統計・可視化<br>(DuckDB / survival)"]
    PyR --> Rep["3. 報告書生成<br>(Quarto / PPTX)"]
    Rep --> Audit["4. 開示リスク人手レビュー<br>(release-manifest.yml)"]
    Audit --> Release["5. 成果物公開<br>(outputs/release/)"]
```

---

## 2. Python / R による日々の解析実行

### Python 解析（`uv` 環境）
```powershell
# 依存パッケージを同期して実行
uv run python src/python/sample_rwd_pipeline.py
```

### R 統計解析
```powershell
# R スクリプトの実行
Rscript src/r/sample_survival_analysis.R
```

### Quarto 報告書 ＆ プレゼン生成
```powershell
# Quarto レポートの生成 (HTML / PDF / DOCX)
quarto render reports/quarto/summary.qmd

# PowerPoint スライド生成
pnpm report:pptx
```

---

## 3. SAS 実行とログ確認（`invoke-sas.ps1` - 任意機能）

> ℹ️ **本セクションは SAS 9.4 がインストールされている環境でのみ利用します。**

1. **プログラムの実行**:
   - Cursorで対象の `.sas` を開き、`Ctrl + Shift + B` を実行します。
2. **実行結果の確認**:
   - 実行ログと出力ファイルは `.run/sas/<program>/<timestamp>/` に分離生成されます。
   - ログ内に `ERROR:` が存在する場合、コンソールに赤字でエラー内容がハイライトされます。
3. **文字コードの維持**:
   - SASソースはCP932で保存されます。日本語ラベルやコメントの文字化けが発生しないことを確認してください。

---

## 4. 成果物の承認と公開手順 (`outputs/release/`)

集約表、グラフ、PowerPointスライドを外部報告に用いる際は、必ず以下の手順を踏みます：

1. 成果物（例: `summary_table.xlsx`, `report.pptx`）を `outputs/release/` にコピーします。
2. `outputs/release/release-manifest.yml` を開き、以下のチェック項目を確認して `true` に更新します：
   ```yaml
   release:
     project_id: "case-urology"
     reviewed_at: "2026-08-23"
     reviewed_by: "山口 (研究責任者)"
     data_classification: "deidentified"
     approved_files:
       - "summary_table.xlsx"
       - "report.pptx"
     checks:
       direct_identifiers_removed: true
       small_cells_reviewed: true
       free_text_reviewed: true
       disclosure_risk_reviewed: true
     disclosure_control:
       rule_reference: "Osaka Univ Biostat Guidelines"
       small_cell_threshold: 5
       notes: "5例未満のセルはハイフン(-)にマスキング済み"
   ```
3. プロジェクト整合性検査を実行して合格を確認します：
   ```powershell
   uv run python scripts/validate-project.py --project-dir .
   ```
4. Gitコミットを行います。

---

## 5. テンプレート更新の検知と適用

共通基盤テンプレート（`templates/analysis-project`）に新機能や設定更新があった場合：

1. **作業ツリーの確認**:
   - `git status` で未コミットの変更がないことを確認します。
2. **更新チェック**:
   ```bash
   copier update --check-only
   ```
3. **更新の適用とレビュー**:
   ```bash
   copier update
   ```
   - 競合（Conflict）が発生した場合は自動解決せず、差分を確認して手動でマージしてください。
