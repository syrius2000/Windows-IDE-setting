# 初心者統計家向け Cursor ＆ RWD環境 チートシート

本チートシートは、IT初学者の統計専門家が日常の解析・報告業務を安全かつ快適に行うためのクイックリファレンスです。

---

## 🌟 0. クリーンな Windows 11 PC での初回一括セットアップ

SASとOfficeしか入っていないPCを初期化・構築する場合：

1. 本リポジトリを展開し、フォルダ内の **`Setup-Windows.bat`** を右クリックして **「管理者として実行」** します。
2. 自動的に WinGet, Git, Python 3.12, R 4.4, Quarto, DuckDB, Node.js, Cursor設定が完了します。
3. （詳しい手順: [クリーン Windows 11 初期セットアップ手順書](windows-bootstrap-guide.md)）

---

## 🌟 4大ディレクトリ配置原則（これだけ覚えればOK）

1. 📂 **`src/`**: プログラム（SAS, Python, R, TypeScript）
   - `src/sas-cp932/`: SASコード (CP932文字コード)
   - `src/python/`: Python解析スクリプト (UTF-8)
   - `src/r/`: R統計解析コード (UTF-8)
2. 📊 **`sql/`**: SQLクエリ・データ抽出スクリプト
3. 📑 **`reports/`**: 報告書（Quarto, Slidev, PowerPoint）
4. 📦 **`outputs/`**: 成果物出力先
   - `outputs/private/`: 中間データ・個票・ログ（**Gitに保存されません**）
   - `outputs/release/`: 人手確認済み公開成果物（`release-manifest.yml` を記録）

---

## 🚀 1. 新規解析テーマ（Case Project）の作成

PowerShell（Windows）またはターミナル（Mac）で以下のコマンドを実行します：

```powershell
# Windows 11 の場合
.\scripts\project\New-AnalysisProject.ps1 -Name "case-urology" -Profile "windows-standard" -DataClassification "deidentified"
```

```bash
# macOS の場合
./scripts/project/new-analysis-project.sh case-pompe-disease mac-rwd-expert sensitive
```

- 画面に表示されるプレビューを確認し、`Y` を押すとGitが初期化され、Cursorが自動起動します。

---

## 💻 2. 日常の解析実行方法（Cursor内）

### SASプログラムの実行
1. Cursorで `src/sas-cp932/sample_analysis.sas` を開きます。
2. キーボードで **`Ctrl + Shift + B`** を押します（または上部メニュー `ターミナル` → `タスクの実行` → `SAS: Run current program`）。
3. 実行結果（`.log` と `.lst`）は `.run/sas/` に自動保存され、コンソールにエラー有無が表示されます。

### Pythonスクリプトの実行（uv）
```powershell
uv run python src/python/sample_rwd_pipeline.py
```

### Rスクリプトの実行
```powershell
Rscript src/r/sample_survival_analysis.R
```

### 報告書（Quarto HTML / PPTX）の生成
```powershell
# Quarto レポートの作成
quarto render reports/quarto/summary.qmd

# 編集可能 PowerPoint の作成
pnpm report:pptx
```

---

## 🛡️ 3. プロジェクトの健全性・セキュリティ検査

コードや設定を変更した後、いつでも以下のコマンドで安全性を検証できます：

```powershell
uv run python scripts/validate-project.py --project-dir .
```

- `[✓]` がすべて緑色で表示されれば合格です。
- `[✗]` が出た場合は、メッセージに従って禁止ファイル（`.sas7bdat` 等）を移動してください。

---

## ⚠️ 4. 絶対にやってはいけないこと（禁忌事項）

1. **実データやパスワードをGitにコミットしない**:
   - 実データ（`.sas7bdat`, 患者CSV）は必ずProject外部フォルダ（`C:\RWD_DATA\` 等）に配置してください。
2. **実患者データをCursor AIプロンプトに貼り付けない**:
   - AIにコードを聞くときは、必ず `data/synthetic/` の合成データを使って質問してください。
3. **SASファイル（`src/sas-cp932/`）の文字コードをUTF-8に変えない**:
   - Cursorの設定により自動でCP932として開かれます。文字コードを変更して保存しないでください。
