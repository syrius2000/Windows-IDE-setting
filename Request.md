# AI Agent 環境構築 Request

- 対象：阪大の統計専門家・研究者
- 目的：IT初心者でも利用できるAI Agent開発・解析環境と、専門家向けのローカルRWD処理環境を構築する
- 作成日：2026-08-22
- 状態：第1ラウンドの前提条件・回答確定版

## 1. 目的と基本方針

- 既存のSAS資産とExcel／PowerPoint報告業務を維持する。
- Python、R、Git、AI Agentを追加し、解析・検証・報告作成を再現可能にする。
- 全員を同一構成にせず、以下の二系統に分ける。
  - 一般利用者向けWindows標準環境
  - 専門家向けMacローカルRWD環境
- クラウドAIとローカルAIをデータ区分によって明示的に使い分ける。
- Windows標準環境ではOSS中心の共通開発基盤を事前導入する。
- ソフトウェアを多数インストールするだけでなく、ロックファイル、検証スクリプト、チートシートまで提供する。

## 2. 確認済みの利用環境

### 2.1 一般利用者

- 個人所有の標準的なWindows 11ノートPCを使用する。
- ローカル管理者権限がある。
- 機微情報・秘匿化RWDは扱わない。
- Cursorを購入済みで、ソフトウェアや拡張機能を自由に導入できる。
- Windowsネイティブ環境を第1段階とする。
- WSL2 Ubuntuも導入済みだが、Linuxコマンド、パス、権限について教育が必要である。

### 2.2 専門家

- 128GB RAMのMacBook Proを使用する。
- SAS、医療データ処理、Macの利用に習熟している。
- Ollama上で`gpt-oss-120b`を利用した実績がある。
- 手書き医療PDFからのデータ抽出・構造化をローカル環境で実施している。
- 非匿名化・高秘匿情報を扱う場合は、必要なモデル・パッケージをネット接続時に準備した後、ネットワークから切断して処理する。
- 高性能ローカルLLM、OCR、Agent処理の先行検証環境とする。

### 2.3 RWD・MySQL環境

- 秘匿化されたRWDの分析が頻繁に行われる。
- RWDはMySQL 8.0データベースに格納されている。
- MySQL 8.0データベースは、教室内ネットワークからMacを用いて接続・利用する。
- 教室外からの接続やクラウドAIへの直接入力は行わない。
- 「秘匿化」が法的・契約上の匿名化、仮名化、非識別化のいずれに該当するかは未確認である。設計上は再識別可能性が残るものとして慎重に扱う。
- MySQLサーバーの設置場所、TLS、認証方式、接続ポート、利用権限は次段階で確認する。

### 2.4 SAS・文字コード・報告

- SASはローカル環境で利用している。
- 現在の主要言語はSASであり、Rも使用している。
- SAS資産はCP932で管理されている。
- UTF-8で開くと文字化けするため、`.sas`や関連テキストファイルは文字コードの明示設定が必要である。
- 主な成果物はExcelおよびPowerPointである。
- Python、R、TypeScriptの新規ソースは原則UTF-8とする。

### 2.5 Git・AIツール

- GitHub Enterpriseは利用していない。
- 個人GitHubアカウントを使用する。
- リポジトリは原則Privateとする。
- Cursorは全員購入済みである。
- Cursorを共通のエディタ・Agent UIとする。

## 3. Frontier Questionsに対するAnswer

### Q1：Windows 11の管理者権限およびセキュリティポリシー

- **Answer：A**
- PCは個人所有である。
- 完全なローカル管理者権限がある。
- Cursor、Git、Python、R、Ollama、WSL2、VS Code拡張機能等を自由に導入できる。
- 組織管理PCに由来するExecutionPolicy、仮想化、ポート、インストール制限は想定していない。
- セットアップ開始時には、`winget`、PowerShell、WSL2、仮想化、ファイアウォール、空き容量を診断する。

### Q2：WindowsネイティブとWSL2 Ubuntu

- **Answer：Windowsネイティブを第1段階として採用する。**
- ローカルSAS、Excel、PowerPoint、Windowsファイルとの連携を優先する。
- 一般利用者のプロジェクトはWindows側に配置する。
- WSL2 Ubuntuは第2段階の選択肢とする。
- WSL2の利用には、Linuxコマンド、`C:\...`と`/mnt/c/...`の違い、権限、改行コード、ファイル配置について別途教育計画を作成する。
- 128GB MacBook ProはWindows／WSLとは別の上級者用環境として扱う。

### Q3：ハードウェアとローカルAI

- **Answer：利用者別の二層構成とする。**
- 一般利用者：
  - 標準的なWindowsノートPCを使用する。
  - CursorのクラウドAIを中心に利用する。
  - 機微情報は扱わない。
  - ローカルLLMはRAM、CPU、GPU、VRAM、空き容量を診断した後、必要に応じて追加する。
  - ローカルLLMを必須要件にはしない。
- 専門家：
  - 128GB MacBook Proを使用する。
  - Ollama＋`gpt-oss-120b`の利用実績がある。
  - ローカルAI、OCR、医療文書構造化、Agentの先行検証を担当する。
- 手書きPDF処理は以下のパイプラインとする。
  1. PDF画像入力
  2. ローカルOCR／画像認識
  3. テキスト化
  4. `gpt-oss-120b`による項目抽出・構造化・整合性確認
  5. 人による確認
  6. SAS／R／Python／MySQL用データへの変換
- `gpt-oss-120b`自体は画像入力に対応しないため、OCR／画像認識工程を分離する。

### Q4：機微医療データとAI利用方針

- **Answer：Bを修正した、統制されたハイブリッド運用とする。**
- 公開情報、一般的なコード、合成データはCursorのクラウドAIを利用できる。
- CursorではPrivacy Modeを有効にする。
- 一般利用者は機微情報を扱わない。
- 秘匿化RWDは教室内ネットワークのMySQL 8.0へMacから接続して処理する。
- 仮名化または再識別可能性のあるRWDは、クラウドAIへ入力しない。
- 非匿名化医療情報・手書き医療文書は、ネットワーク切断後のMacローカル環境で処理する。
- Cursor Privacy Modeは「学習に利用されない」ための設定であり、完全オフラインを意味しない。
- 大学、倫理委員会、データ提供元の生成AI規程は現時点で未確認である。「規程が不明」と「規制がない」は同義ではないため、実データ利用前に確認する。
- ローカル環境でも、ディスク暗号化、ログ、OCR中間ファイル、バックアップ、アクセス権、ローカルポートを管理する。

### Q5：RWD分析スタック

- **Answer：現在はCを出発点とし、B＋Cへ拡張する。**
- SASを直ちにPythonへ置換しない。
- SAS：既存解析、検証済みコード、定型帳票を担当する。
- R：統計解析、探索解析、可視化を担当する。
- Python：MySQL接続、データ処理、OCR、AI／Agent連携を担当する。
- TypeScript：Webスライド、編集可能なPowerPoint、報告自動化を担当する。
- MySQL 8.0：教室内の秘匿化RWDデータ基盤として維持する。
- DuckDB／Parquet：SAS、R、Python間のローカル中間データ形式として利用を検討する。
- Slidev：研究会、講演、Web、PDF向けとする。
- PptxGenJS、R `officer`、Python `python-pptx`：編集可能なPowerPoint向けとする。
- SAS資産はCP932、新規Python／R／TypeScriptはUTF-8として管理する。
- CP932とUTF-8はディレクトリまたはワークスペースを分離する。

### Q6：導入・セットアップの提供形態

- **Answer：C**
- 自動セットアップスクリプトと、初心者向けチートシート／運用マニュアルをセットで提供する。
- Windows標準版とMac上級版を分離する。
- Windows標準版にはOSS中心の共通開発基盤を事前導入する。
- Mac上級版には、MySQL接続、Ollama、ローカルOCR、オフライン処理手順を追加する。
- インストール、環境診断、プロジェクト作成、検証を別スクリプトに分割する。
- 各スクリプトは再実行可能、ログ出力、エラー処理、復旧可能な設計とする。

## 4. 導入対象とするOSS・開発ツール

### 4.1 Windows標準版：全員必須

- WinGet
- Windows Terminal
- PowerShell 7
- Git for Windows
- 7-Zip
- Cursor（購入済み、OSSではないが共通UIとして使用）
- `uv`
- `rig`
- R
- Rtools
- Quarto
- Node.js Active LTS
- `pnpm`
- DuckDB CLI
- Gitleaks
- `.editorconfig`
- `pre-commit`

### 4.2 Pythonプロジェクト標準候補

- `duckdb`
- `polars`
- `pandas`
- `pyarrow`
- `pyreadstat`
- `SQLAlchemy`
- `PyMySQL`または採用方針に合うMySQL 8.0ドライバー
- `openpyxl`
- `xlsxwriter`
- `python-pptx`
- `jupyterlab`
- `ruff`
- `pytest`
- `pre-commit`

### 4.3 Rプロジェクト標準候補

- `renv`
- `tidyverse`
- `data.table`
- `arrow`
- `duckdb`
- `DBI`
- `RMariaDB`または採用方針に合うMySQL 8.0ドライバー
- `haven`
- `openxlsx`
- `officer`
- `flextable`
- `styler`
- `lintr`
- `testthat`

### 4.4 TypeScript・報告自動化

- Node.js Active LTS
- `pnpm`
- TypeScript
- Slidev
- PptxGenJS
- Prettier
- ESLint
- Vitest

### 4.5 SQL・MySQL・データ確認

- MySQL 8.0既存データベース
- MySQL ShellまたはMySQL CLI
- DBeaver Community：GUIが必要な場合のみ
- DuckDB CLI
- Python：SQLAlchemy＋MySQL 8.0ドライバー
- R：DBI＋MySQL 8.0対応ドライバー

### 4.6 Mac専門家版

- Cursor
- Git
- Python／R
- Ollama
- `gpt-oss-120b`
- ローカルOCR／画像認識ツール
- MySQLクライアント
- Quarto
- Slidev／PptxGenJS
- Gitleaks
- オフライン運用確認スクリプト

### 4.7 Cursor拡張機能候補

- Python
- Jupyter
- R
- Quarto
- ESLint
- Prettier
- EditorConfig
- GitHub Pull Requests
- Continue：Ollama接続が必要な利用者のみ
- Slidev：報告自動化を行う利用者のみ
- SAS構文支援：発行元と文字コード対応を確認して採用する

### 4.8 初期標準構成に含めないもの

- Docker Desktop
- Podman Desktop
- Kubernetes
- Conda／Anaconda
- 複数のPython管理ツール
- 複数のNode.js管理ツール
- Visual Studio Build Tools
- OCR一式：一般Windows利用者には不要
- 大規模ローカルLLM：一般Windows利用者には必須としない

必要性が確認された場合にのみ、追加フェーズとして導入する。

## 5. MySQL 8.0・RWD接続要件

- RWD接続は教室内ネットワークとMacに限定する。
- 原則として分析用の読み取り専用アカウントを利用する。
- 書き込みが必要な場合は、読み取り処理と更新処理のアカウント・権限を分離する。
- 認証情報をソースコード、Notebook、Cursor Rules、Git、ログへ記録しない。
- 認証情報はOSキーチェーン、環境変数、権限を制限した設定ファイル等で管理する。
- MySQLサーバーがTLSを提供している場合はTLS接続を利用する。
- TLSがない場合は、教室内ネットワークという境界だけに依存せず、脅威と代替策を評価する。
- SQLログ、例外ログ、Notebook出力に個票データを残さない。
- 大量抽出や全テーブルダンプを既定動作にしない。
- 必要列・必要行に限定したクエリを基本とする。
- スキーマ情報、データ辞書、合成データをAgentに提供し、実レコードをクラウドAIへ提供しない。
- クエリテンプレートには、対象期間、対象集団、抽出列、重複、欠測、除外条件を明示する。
- 抽出件数、重複、NULL率、型、範囲、文字コードを自動検証する。

## 6. 文字コード要件

- SASプログラムと関連テキストはCP932として明示的に扱う。
- CP932ファイルをUTF-8として自動保存しない。
- CP932の原本は変更せず保存する。
- Python、R、TypeScript、Markdown、YAML、JSONは原則UTF-8とする。
- SAS用ワークスペースとUTF-8開発用ワークスペースを分ける。
- CSV入出力では文字コードを明示し、読み込み後の文字化け検査を行う。
- 文字コード変換を行う場合は、変換元、変換先、変換日時、変換ツール、置換不能文字数を記録する。
- Git登録前に文字コードと改行コードを検査する。

## 7. Git・ファイル管理要件

- GitHubは個人アカウントのPrivateリポジトリを使用する。
- Gitにはコード、設定、仕様書、合成データ、テストだけを登録する。
- 以下はGitへ登録しない。
  - RWD・患者データ
  - MySQLダンプ
  - SASデータセット（`.sas7bdat`等）
  - XPTファイル
  - 実データ由来のCSV／Parquet／Excel
  - OCR画像・OCR中間ファイル
  - レポートに埋め込まれた個票情報
  - APIキー、DBパスワード、接続文字列
  - `.env`
  - 実行ログ・一時ファイル
- 共通`.gitignore`を配布する。
- Gitleaksとpre-commitで、秘密情報、大容量ファイル、禁止拡張子を検査する。
- Git LFSを「RWDをGitへ置く手段」として使用しない。

## 8. 推奨ディレクトリ構成

```text
project/
├─ README.md
├─ AGENTS.md
├─ pyproject.toml
├─ uv.lock
├─ renv.lock
├─ package.json
├─ pnpm-lock.yaml
├─ .gitignore
├─ .editorconfig
├─ config/
│  ├─ examples/
│  └─ schemas/
├─ sas-cp932/
├─ python-utf8/
├─ r-utf8/
├─ typescript-utf8/
├─ sql/
│  ├─ templates/
│  └─ validation/
├─ tests/
├─ docs/
├─ reports/
├─ data/
│  └─ README.md
└─ output/
   └─ README.md
```

- 実データは上記Gitリポジトリ外、または明示的にGit除外された保護領域へ置く。
- `data/`と`output/`には取扱規則だけを登録し、実データは登録しない。

## 9. 求める成果物

### #1 Windows標準版

- `00-diagnose-windows.ps1`
  - Windowsバージョン、CPU、RAM、GPU、VRAM、空き容量、管理者権限、WinGet、PowerShell、WSL2、ファイアウォールを診断する。
- `01-install-common.ps1`
  - Terminal、PowerShell 7、Git、7-Zip等を導入する。
- `02-install-statistics.ps1`
  - `uv`、Python、`rig`、R、Rtools、Quarto、DuckDBを導入する。
- `03-install-reporting.ps1`
  - Node.js LTS、`pnpm`、Slidev、PptxGenJS関連環境を導入する。
- `04-configure-cursor.ps1`
  - 許可された拡張機能、設定、CP932／UTF-8ワークスペースを構成する。
- `05-verify-environment.ps1`
  - Python、R、Node.js、Git、Quarto、DuckDB、SAS文字コード、Excel／PPTX生成を検証する。
- 初心者向けチートシート
- 日常運用マニュアル
- トラブルシューティング表
- アンインストール／復旧手順

### #2 Mac専門家・RWD版

- Mac環境診断スクリプト
- MySQL 8.0読み取り専用接続サンプル
- PythonおよびRからのMySQL接続サンプル
- 認証情報をGit・Notebook・ログに残さない設定例
- 接続前後のネットワーク状態確認手順
- Ollamaおよび`gpt-oss-120b`の動作確認
- OCR→テキスト→構造化→人手確認のパイプライン
- オフライン処理手順
- RWD抽出後のデータ品質検査
- 抽出・変換・検証の監査ログ仕様

### #3 共通プロジェクトテンプレート

- SAS／Python／R／TypeScript／SQLを分離したディレクトリ
- `uv.lock`、`renv.lock`、`pnpm-lock.yaml`
- `.gitignore`、`.editorconfig`、pre-commit、Gitleaks設定
- CP932とUTF-8の運用規則
- Cursor Rulesまたは`AGENTS.md`
- クラウドAIへ入力可能な情報と禁止情報の一覧
- 合成データによる最小実行例
- Excelおよび編集可能なPPTX生成例

### #4 ソフトウェア構成表

- ツール名
- 目的
- OSSライセンス
- 公式配布元
- 対応OS
- インストール方法
- 固定するバージョン
- 更新方法
- アンインストール方法
- 必須／任意の区分
- 既知の制約

## 10. 受入基準

- 新規Windows 11個人PCで、診断から導入・検証まで再現できる。
- 一般利用者がWindowsネイティブ環境だけでSAS、Python、R、Git、Cursorを利用できる。
- WSL2がなくても中核機能が動作する。
- SAS CP932ファイルを文字化け・意図しないUTF-8変換なしに開閉できる。
- `uv sync`、`renv::restore()`、`pnpm install --frozen-lockfile`で環境を復元できる。
- 合成データを用いてSAS→Python／R→Excel／PPTXの処理が実行できる。
- Macから教室内MySQL 8.0へ読み取り専用で接続できる。
- MySQL認証情報とRWDがGit、Cursorクラウド、Notebook出力、ログへ残らない。
- RWD抽出時に件数、重複、欠測、型、範囲、抽出条件を検証できる。
- 手書き文書処理では、項目別正解率、欠落率、誤抽出率、棄却率、人手修正時間を評価できる。
- Excelおよび編集可能なPowerPointを生成できる。
- 各スクリプトが再実行可能で、失敗時に原因と復旧方法を示す。

## 11. 未確認事項

- WindowsノートPCの正確なCPU、RAM、GPU、VRAM、空き容量
- Windows 11のエディションとCPUアーキテクチャ
- MacBook Proの正確なチップ、macOSバージョン、空き容量
- SASの正確な製品・バージョン・ライセンス形態
- MySQL 8.0サーバーの設置OS、ホスト、ポート、TLS、認証方式
- MySQL 8.0の読み取り専用アカウントの有無
- RWDの匿名化／仮名化／非識別化の正式区分
- 大学、倫理委員会、データ提供元の生成AI利用規程
- 現在利用しているOCR／画像認識ツール
- Excel／PowerPointのテンプレート、様式、更新頻度

未確認事項は診断またはヒアリングで取得し、取得できない場合は安全側の既定値を採用する。

## 12. 提案

- 第1段階では、Windows上で「CP932のSAS実行→ログ確認→R／Python補足解析→Excel／編集可能PPTX生成」を完成させる。
- 第2段階では、Macから教室内MySQL 8.0へ安全に接続し、RWD抽出・品質検査・解析を再現可能にする。
- 第3段階では、Mac上のOCR＋ローカルLLMによる手書き医療文書処理を独立したAgentとして構築する。
- Mac専門家環境で検証・固定した処理だけを、Windows一般利用者環境へ段階的に移植する。

## 13. 批判的立場

- 「秘匿化」という表現だけでは、クラウドAIへの入力可否を決定できない。正式な匿名化区分、再識別可能性、契約条件を確認する必要がある。
- 教室内ネットワークであることだけでは安全性を保証しない。MySQLの権限、TLS、認証情報、ログ、端末暗号化も確認する必要がある。
- 一般利用者にSAS、Python、R、WSL2、TypeScript、ローカルLLMを同時教育すると定着しにくい。段階導入を前提とする。
- OSSを多数インストールするだけでは再現可能性は得られない。ロックファイル、検証スクリプト、テスト、運用規則を成果物に含める。
- 手書き医療文書抽出は成功例だけで判断せず、誤抽出・欠落・人手修正を定量評価する。

以上の前提に基づき、具体的なツール選定、セットアップスクリプト、ディレクトリ構成、MySQL 8.0接続、SAS CP932連携、報告自動化、プロンプト／Agent設計を進めてください。
