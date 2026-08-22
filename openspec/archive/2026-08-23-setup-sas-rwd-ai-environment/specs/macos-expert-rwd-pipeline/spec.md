## Purpose

MacBook Pro（128GB RAM）を利用する専門家向けに、教室内MySQL 8.0への安全な読み取り専用接続（標準Python/R直接接続および任意ODBC/DSN接続プロファイル）、macOS Keychainによる認証情報管理、Apple Vision（Swift CLI）＋ローカルVLM（`qwen2.5-vl:32b`）＋`gpt-oss-120b`による手書き医療PDF構造化、およびオフライン運用事前確認パイプラインを提供する。

## ADDED Requirements

### Requirement: macOS環境診断スクリプト
システムは、Apple Siliconチップ、RAM容量（128GB等）、macOSバージョン、Ollama稼働状態、ローカルモデル一覧、MySQLネットワーク疎通性、Keychain登録状態、およびSwiftコンパイラ/Vision CLIの実行可否を非破壊的に診断しなければならない（SHALL）。

#### Scenario: Mac専門家環境の診断実行
- **WHEN** ユーザーが `scripts/macos/diagnose.sh` を実行した時
- **THEN** システムはハードウェアリソース、Ollama、MySQL接続性、Keychain状態、OCR基盤の健全性を検査し、構造化診断レポートを出力する

### Requirement: macOS KeychainによるMySQL認証情報管理と読取専用直接接続（標準経路）
システムは、MySQL 8.0接続用パスワードを平文ファイルや環境変数に保存せず、macOS Keychainにのみ安全に格納・取得するPython/R連携ユーティリティを提供し、分析用読み取り専用ユーザーでの接続とデータ品質自動検査（件数、重複、NULL率、安全な権限監査）を実行しなければならない（SHALL）。

#### Scenario: Keychainへのパスワード対話的登録
- **WHEN** ユーザーが `configure-keychain.py` を実行してパスワードを入力した時
- **THEN** システムはOS Keychain API（`keyring`）を通じてパスワードを安全に保存し、コンソールやログに平文を出力しない

#### Scenario: 読み取り専用MySQL 8.0への接続と非破壊的品質検査
- **WHEN** `mysql-readonly-test.py` が実行された時
- **THEN** システムはKeychainからパスワードをメモリ上のみに読み出してMySQL 8.0へ直接接続し、権限監査（書き込みを行わない安全な検査）および品質検査（行数・重複・欠測率）を実施して個票データを画面やログに出力せずにサマリーを表示する

### Requirement: MySQL Connector/ODBC ＆ DSN 接続プロファイル（任意経路）
システムは、ExcelやFileMaker等のOffice系ツールを利用する研究者向けに、MySQL Connector/ODBCおよびiODBC/DSNによる任意接続プロファイルを提供し、アーキテクチャ適合性（Apple Silicon ARM64 vs Intel x86_64）検査、DSNへのパスワード保存禁止、およびメタデータ限定の疎通テストをサポートしなければならない（SHALL）。

#### Scenario: ODBC未導入環境での標準直接接続の独立性
- **GIVEN** macOS環境に MySQL Connector/ODBC がインストールされていない
- **WHEN** Python（`PyMySQL`）または R（`RMariaDB`）による直接接続スクリプトが実行された時
- **THEN** システムはODBCの非存在による影響を受けず、直接接続により正常にクエリを実行できる

#### Scenario: ODBCドライバおよびDSN設定の非破壊的検査
- **GIVEN** MySQL Connector/ODBC が導入された環境
- **WHEN** ユーザーがODBC設定検査を実行した時
- **THEN** システムは `myodbc-installer` によるドライバ登録状態、`odbc.ini` のDSN設定、およびCPUアーキテクチャ（arm64/x86_64）の一致を検証する

#### Scenario: DSNパスワード非保持と安全な疎通確認
- **WHEN** ODBC経由での疎通テストが実行された時
- **THEN** システムはDSN設定ファイルに平文パスワードが含まれていないことを確認し、Keychainまたは対話入力された認証情報を用いて `SELECT VERSION()`, `SELECT CURRENT_USER()` 等のメタデータ確認のみを実行して接続可否を判定する

#### Scenario: ODBC接続失敗時のフォールトアイソレーション
- **WHEN** ODBCドライバやDSN設定の不備によりODBC接続が失敗した時
- **THEN** システムはODBC固有のエラー詳細を提示しつつ、Python/R直接接続経路への影響を与えない

### Requirement: Swift CLI + Pythonオーケストレーターによる手書き医療OCRパイプライン
システムは、Apple Vision Frameworkによる文字・座標・信頼度抽出を行うSwift CLIと、PDF前処理・低信頼領域に対するローカルVLM（`qwen2.5-vl:32b`）フォールバック・`gpt-oss-120b`構造化・人手確認キュー管理を行うPythonオーケストレーターを分離実装し、抽出結果を `ocr-envelope.schema.json` に準拠した監査メタデータ付きで出力しなければならない（SHALL）。

#### Scenario: 手書き医療PDFのOCR抽出とVLMフォールバック
- **WHEN** `ocr-pipeline.py` にテスト用医療PDFが渡された時
- **THEN** システムはページ画像をSwift CLIに渡してVision OCRを実行し、信頼度 `< 0.75` のブロックについてローカルVLMによる再認識を試み、`ocr-envelope.schema.json` 形式で中間結果を保存し、未解決項目を `review-queue.json` に永続化する

### Requirement: オフライン運用事前確認スクリプト
システムは、非匿名化・機微医療データをローカル処理する前に、全アクティブインターフェース（Wi-Fi/Ethernet/Thunderbolt）の切断状態、外向き接続の遮断、DNS解決、およびクラウド同期プロセス（iCloud bird, Dropbox等）の対象外であることを検査するスクリプトを提供しなければならない（SHALL）。

#### Scenario: オフライン状態の事前検査
- **WHEN** ユーザーが機微データ処理前に `offline-check.sh` を実行した時
- **THEN** システムはアクティブなネットワークインターフェース、DNS解決、外向きソケット、クラウド同期プロセスを検査し、安全にオフライン処理を開始できる状態かを判定して結果を提示する
