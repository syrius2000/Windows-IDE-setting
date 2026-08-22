## Why

阪大の統計専門家および研究チームにおいて、既存のSAS資産（CP932）やOffice報告業務を維持しつつ、Python、R、Git、AI Agent（Cursor / ローカルLLM）を活用したモダンで再現性の高いReal World Data（RWD）解析基盤を構築する必要があります。

これまでの課題として、環境構築の複雑さや属人化に加え、「解析テーマ（泌尿器科、ポンペ病など）ごとにディレクトリ構造やデータ配置がばらばらになりやすい」「Gitリポジトリ内に実データや認証情報が誤混入するリスクがある」「テンプレートの更新管理ができない」「教室内MySQLへの安全な接続経路（Python/R直接接続 vs Office/Excel向けODBC接続）の整理が不十分」という問題がありました。

本変更では、システムを**「Environment層（PC環境基盤）」「Template層（共通雛形管理）」「Case Project層（個別解析案件リポジトリ）」の3層構造**として定義し、1コマンドで標準化されたCase Projectを生成・検証し、テンプレート更新候補を検知してレビュー後に適用できる仕組みを導入します。なお、疾患固有の変数定義や医学的判断は各Case Project側に委ね、本基盤ではディレクトリ、実行基盤、セキュリティ境界、環境再現性、報告自動化の共通化に専念します。

## What Changes

- **3層アーキテクチャの確立**:
  1. **Environment層**: Windows 11 / macOS への共通開発ツール（Cursor, Git, SAS連携, Python/uv, `uv tool install "copier==<固定バージョン>"`, R/rig/renv, Node.js/pnpm, Quarto, Slidev, DuckDB, Ollama, Gitleaks, pre-commit）の診断・自動導入・検証。
  2. **Template層**: `templates/analysis-project/` にCopierベースの標準雛形、`schemas/project.schema.json`、`schemas/ocr-envelope.schema.json`、SAS CP932/UTF-8分離設定、Cursorタスク（`${workspaceFolder}` 相対）、AI利用ルールを整備。
  3. **Case Project層**: テーマごとに独立したGitリポジトリとして分離し、物理的な実データ隔離・初心者向け4大ディレクトリ原則（`src/`, `sql/`, `reports/`, `outputs/`）を徹底。
- **データ境界と成果物管理の強化 (`outputs/`)**:
  - `outputs/` を `outputs/private/`（Git除外・機微な中間集計・個票listing・ログ）と `outputs/release/`（人手確認済みの報告・公開可能成果物）に明確に分離。
  - `outputs/release/release-manifest.yml` を導入し、直接識別子の除去、小セル抑制（閾値はCase側で指定）、自由記載欄の確認、開示リスクレビューの記録を人手で承認・管理。
  - `validate-project.py` により、禁止拡張子、Git追跡状態（`git check-ignore --stdin` / `git ls-files`）、ファイル配置、再帰的文字コードおよびSchema違反を機械検査し、`outputs/release/` の内容は別途人手レビューによって公開可否を確定する（機械検査と人手判断の明確な責務分離）。
- **Schemaの責任分離（共通基盤 vs Case Project）**:
  - **共通基盤側 (`schemas/`)**: `project.schema.json`（プロジェクト定義検証）および `ocr-envelope.schema.json`（疾患非依存のOCR座標・信頼度・監査メタデータ・nullableレビュアー対応）。
  - **Case Project側 (`<case>/schemas/`)**: `extraction.schema.json`（疾患固有の抽出項目・医学的許容範囲）および `analysis-dataset.schema.json`（解析変数定義）。
- **Case Project 自動生成・管理ファクトリ (`scripts/project/`) の新設**:
  - `New-AnalysisProject.ps1` (Windows) および `new-analysis-project.sh` (Mac) により、初心者が1コマンドで対話的/引数指定でCase Projectを生成。
  - 事前導入された固定バージョンの `Copier` を内部実行し、プロジェクト生成 → `validate-project.py` による整合性検証 → 生成内容プレビュー → **利用者確認** → `git init` ＆ 初期コミット → Cursor起動 という安全なフローを実行。
  - テンプレート更新は `copier check-update` による候補検知と差分提示までを自動化し、Case固有ファイルとの競合を人手レビュー後に適用。
- **Windows 11 自動セットアップ & 診断ツールチェーン (`scripts/windows/`)**:
  - `00-diagnose.ps1` 〜 `05-verify.ps1` による診断、WinGet優先＋安全なダウンロード実行フォールバック導入、Cursor環境設定、多言語（Python/DuckDB/SAS/R/PPTX）エンドツーエンド検証。
  - `invoke-sas.ps1` および Cursor Tasks によるローカルSAS（CP932）バッチ実行・ログ/LSTの `.run/sas/` 分離・ERROR/WARNING自動判定。
- **Mac 専門家向け 機微RWD・ローカルAIパイプライン ＆ MySQL接続プロファイル (`scripts/macos/`)**:
  - **MySQL接続経路の明確化**:
    - **標準経路（推奨）**: Python（`PyMySQL` / `mysql-connector-python`）および R（`RMariaDB` / `DBI`）による自己完結型直接接続。
    - **任意経路（Office/Excel用）**: `MySQL Connector/ODBC` + `iODBC` / DSN（ARM64/x86_64アーキテクチャ検査、DSNへの平文パスワード保存禁止、Keychain/対話入力連携、メタデータ限定の疎通確認）。ODBC未導入時や接続失敗時でも標準直接接続経路に一切影響を与えない設計。
  - `diagnose.sh`, `configure-keychain.py`, `mysql-readonly-test.py` による教室内MySQL 8.0読取専用接続・安全な権限監査（書き込み操作を実行しない非破壊的検査）およびmacOS Keychainパスワード管理。
  - `scripts/macos/ocr/` にて **Swift CLI（Apple Visionによるテキスト・座標・信頼度抽出）** と **Pythonオーケストレーター（複数ページ対応、低信頼領域へのローカルVLM `qwen2.5-vl:32b` フォールバック、`gpt-oss-120b` 構造化、`review-queue.json` 永続化）** を分離実装。
  - `offline-check.sh` により、非匿名化データ処理前に全アクティブインターフェース（Wi-Fi/Ethernet/Thunderbolt）、確立ソケット、DNS解決、およびクラウド同期プロセス（Dropbox, OneDrive, Google Drive, Box, iCloud bird）を網羅検査。
- **ガバナンスとドキュメントの完備 (`docs/`)**:
  - ソフトウェア構成表（BOM）、初心者向けチートシート、日常運用マニュアル、AIデータ境界基準、インシデント対応手順、MySQL 8.0 読取専用・ODBC接続ガイド。

## Capabilities

### New Capabilities

- `windows-environment-automation`: Windows 11向けの診断、WinGet+公式フォールバックによるOSS/開発環境導入（`uv tool` によるCopier固定版含む）、Cursor拡張機能/設定、SAS CP932バッチ実行ラッパー（`invoke-sas.ps1`）、および検証スクリプトの自動化。
- `macos-expert-rwd-pipeline`: Mac専門家向けの環境診断、教室内MySQL 8.0読取専用接続（Python/R直接接続 ＆ 任意ODBC/DSN接続プロファイル）、macOS Keychain認証管理、Swift CLI + PythonオーケストレーターによるApple Vision / ローカルVLM / `gpt-oss-120b` 手書き医療PDF構造化パイプライン、オフライン事前確認。
- `analysis-project-governance`: SAS CP932とPython/R/TS UTF-8の分離ディレクトリ構造、`outputs/private/` と `outputs/release/`（`release-manifest.yml` 含む）のデータ境界分離、物理的な実データ隔離、ロックファイル（`uv.lock`, `renv.lock`, `pnpm-lock.yaml`）による環境再現性、Cursor Rules / `AGENTS.md`、AI利用境界マトリクス、合成データ（`synthetic-data/`）、ソフトウェア構成表。
- `analysis-project-factory`: CopierとPowerShell/ShellスクリプトによるCase Projectの1コマンド自動生成、`schemas/project.schema.json` による `PROJECT.yml` 検証、利用者確認付きGit初期化、テンプレート版管理、プロジェクト検証（`validate-project.py` による機械検査と人手レビューの分離）、およびテンプレート更新検知機能。

### Modified Capabilities

<!-- 初回構築のため既存仕様の変更はなし -->

## Impact

- **リポジトリ構造の拡張**:
  - `scripts/windows/`: Windows環境基盤用スクリプト群
  - `scripts/macos/`: Mac専門家基盤用スクリプト群（ODBC検査, Keychain, `ocr/vision-ocr/` Swift CLI 含む）
  - `scripts/project/`: Case Project生成・検証・更新用スクリプト群
  - `templates/analysis-project/`: Copier対応のCase Projectテンプレート（`outputs/release/release-manifest.yml` 含む）
  - `schemas/`: `project.schema.json` および `ocr-envelope.schema.json`
  - `profiles/`: `windows-standard` および `mac-rwd-expert` のプロファイル構成定義
  - `docs/`: ソフトウェア構成表、チートシート、プロジェクトライフサイクルマニュアル、MySQL/ODBC接続ガイド
  - `synthetic-data/`: 合成ダミー医療データ
  - `tests/`: 全シナリオ自動検証テストスイート
- **運用フロー・セキュリティの強化**:
  - 共通リポジトリ（基盤・テンプレート管理）と個別の解析案件（Case Project）をGit分離。
  - 機微データ誤混入のリスクを、物理的データ分離、Git除外、秘密情報検査およびProject検証によって低減する。
  - `validate-project.py`（機械検査）と `release-manifest.yml`（人手レビュー）の役割を明確に分担し、個票混入や再識別リスクを管理。
  - MySQL接続において、Python/Rの直接接続を標準化しつつ、Excel/Office利用者向けのODBC/DSN接続手順・Keychain連携を整備し、平文パスワード保存を防止。
