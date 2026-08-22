## 1. Schemas & Profile Configurations

- [x] 1.1 `schemas/project.schema.json`（PROJECT.ymlの型・Enum・必須項目検証用JSON Schema）の実装
- [x] 1.2 `schemas/ocr-envelope.schema.json`（疾患非依存のOCR座標・信頼度・監査メタデータ・nullableレビュアー対応JSON Schema）の実装
- [x] 1.3 `profiles/windows-standard/manifest.json` および `profiles/mac-rwd-expert/manifest.json`（パッケージ・バージョン定義・ODBC任意定義）の作成

## 2. Analysis Project Template (Copier)

- [x] 2.1 `templates/analysis-project/copier.yml` および Jinjaテンプレート定義の作成
- [x] 2.2 テンプレート内標準ディレクトリ（`src/sas-cp932/`, `src/python/`, `src/r/`, `src/typescript/`, `sql/`, `reports/`, `outputs/private/`, `outputs/release/`, `data/synthetic/`, `config/`）の整備
- [x] 2.3 `templates/analysis-project/template/outputs/release/release-manifest.yml`（開示統制・人手レビュー記録ファイル）の作成
- [x] 2.4 テンプレート内 `.cursor/rules/`, `AGENTS.md`, `.vscode/tasks.json`（`${workspaceFolder}` 相対SAS実行タスク）, `.vscode/settings.json`（CP932/UTF-8マッピング設定）, `.gitignore`, `pyproject.toml`, `package.json` の整備

## 3. Case Project Factory & Validation Engine

- [x] 3.1 `scripts/project/validate-project.py`（ディレクトリ、禁止拡張子、再帰的文字コード、PROJECT.ymlスキーマ、非侵入型Git除外検査、開示統制ブロック）の実装
- [x] 3.2 `scripts/project/New-AnalysisProject.ps1`（Windows向けCopier生成・検証・プレビュー・利用者確認付きGit初期化スクリプト）の実装
- [x] 3.3 `scripts/project/new-analysis-project.sh`（Mac向けCopier生成・検証・プレビュー・利用者確認付きGit初期化スクリプト）の実装

## 4. Windows 11 Environment Automation Scripts

- [x] 4.1 `scripts/windows/00-diagnose.ps1`（ハードウェア・OS・管理者権限・WinGet・PS7非破壊診断・二重レポート出力）の実装
- [x] 4.2 `scripts/windows/01-install-common.ps1`（Terminal, PS7, Git, 7-Zipサイレント導入と検証）の実装
- [x] 4.3 `scripts/windows/02-install-analysis.ps1`（uv, Python 3.12, rig, R, Rtools, Quarto, DuckDB CLI, `uv tool` Copier固定版導入・安全ダウンロード）の実装
- [x] 4.4 `scripts/windows/03-install-reporting.ps1`（Node.js LTS, pnpm, Slidev, PptxGenJS環境導入）の実装
- [x] 4.5 `scripts/windows/04-configure.ps1`（Cursor設定, 拡張機能, CP932/UTF-8マッピング, Gitleaks/pre-commit）の実装
- [x] 4.6 `scripts/windows/05-verify.ps1`（全ツール稼働・多言語合成データE2E自動検証）の実装
- [x] 4.7 `scripts/windows/invoke-sas.ps1`（SASパス自動検出・CP932維持・`.run/sas/` 分離・ERROR/WARNING判定ラッパー）の実装

## 5. macOS Expert & RWD / OCR Pipeline

- [x] 5.1 `scripts/macos/diagnose.sh`（Mac環境・Ollama・MySQL疎通性・Keychain・Vision CLI診断）の実装
- [x] 5.2 `scripts/macos/configure-keychain.py`（macOS Keychain MySQLパスワード管理ユーティリティ）の実装
- [x] 5.3 `scripts/macos/mysql-readonly-test.py`（MySQL 8.0 読取専用直接接続・安全な権限監査・データ品質検査サンプル）の実装
- [x] 5.4 `scripts/macos/ocr/vision-ocr/`（Apple Vision Swift CLI）の実装
- [x] 5.5 `scripts/macos/ocr/ocr-pipeline.py`（Pythonオーケストレーター・複数ページ対応・ローカルVLM `qwen2.5-vl:32b` フォールバック・`gpt-oss-120b`・人手確認キュー）の実装
- [x] 5.6 `scripts/macos/offline-check.sh`（全アクティブインターフェース・確立ソケット・DNS・クラウド同期検査スクリプト）の実装
- [x] 5.7 `scripts/macos/test-odbc.py`（MySQL Connector/ODBC・iODBC DSN設定検査、ARM64/x86_64アーキテクチャ検査、メタデータ限定疎通確認）の実装

## 6. Synthetic Data, Documentation & Tests

- [x] 6.1 `synthetic-data/`（患者識別子なしのダミー医療データセット: SAS, CSV, Parquet）の作成
- [x] 6.2 `docs/software-matrix.md`（OSSライセンス・公式配布元・固定バージョン・更新/削除手順表）の作成
- [x] 6.3 `docs/beginner-cheatsheet.md` & `docs/daily-operations.md`（初心者チートシート・日常運用手順書）の作成
- [x] 6.4 `docs/sas-cp932.md` & `docs/mysql-readonly.md`（ODBC/DSN手順含む） & `docs/ai-data-boundary.md` & `docs/incident-response.md` の作成
- [x] 6.5 `README.md` & `AGENTS.md`（マスターナビゲーション・全体ガイド）の作成
- [x] 6.6 `tests/test_all_scenarios.py`（全シナリオ網羅自動テストスイート）の作成と検証
