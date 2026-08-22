## Purpose

統計専門家や研究者が、解析テーマごとに標準化された独立Gitリポジトリ（Case Project）を1コマンドで安全に生成・検証し、PROJECT.ymlによるスキーマ検証、安全なGit初期化、およびCopierテンプレート更新候補の検知を行えるファクトリ機能を提供する。

## ADDED Requirements

### Requirement: ワンコマンドによるCase Project自動生成

システムは、Windows（`New-AnalysisProject.ps1`）およびmacOS（`new-analysis-project.sh`）において、プロジェクト名、プロファイル（`windows-standard` / `mac-rwd-expert`）、およびデータ分類（`synthetic` / `deidentified` / `sensitive`）を指定して、CopierテンプレートからCase Projectディレクトリを自動生成しなければならない（SHALL）。

#### Scenario: Windows上でのCase Project対話的/引数生成

- **WHEN** ユーザーが `.\scripts\project\New-AnalysisProject.ps1 -Name "case-urology" -Profile "windows-standard" -DataClassification "deidentified"` を実行した時
- **THEN** システムは事前インストールされたCopierを呼び出してプロジェクトディレクトリを生成し、`PROJECT.yml` を構成する

#### Scenario: 既存ディレクトリの保護と中断時ロールバック

- **WHEN** 生成先ディレクトリが既に存在する場合、またはテンプレート生成途中でエラーが発生した時
- **THEN** システムは既存ファイルを上書きせず処理を中断し、エラー時は不完全な生成物をクリーンアップして安全に再実行できる状態を保つ

### Requirement: schemas/project.schema.json による PROJECT.yml 検証

システムは、生成されたCase Projectの `PROJECT.yml` が `schemas/project.schema.json` に適合しているかを検証し、プロジェクトIDの命名規則、テンプレートバージョン、データ分類Enum、SAS文字コード、AI利用区分、および外部ストレージ要件が厳格に満たされていることを確認しなければならない（SHALL）。

#### Scenario: PROJECT.ymlのスキーマ適合検査

- **WHEN** プロジェクト生成時または検証スクリプト実行時
- **THEN** スキーマバリデータが `PROJECT.yml` を検査し、不正なEnum値や必須項目欠落があればエラーを出力して次の工程への移行をブロックする

### Requirement: validate-project.py によるプロジェクト整合性検査とGit初期化フロー

システムは、プロジェクト生成直後に `validate-project.py` を実行して、標準ディレクトリ（`src/`, `sql/`, `reports/`, `outputs/`）、禁止拡張子、Git追跡除外設定、文字コードを機械検査し、生成結果のプレビュー表示およびユーザーの明示的確認を経て `git init` と初期コミットを実行しなければならない（SHALL）。

#### Scenario: 機械検査合格後のユーザー確認付きGit初期化

- **WHEN** プロジェクトが正常に生成され `validate-project.py` の機械検査に合格した時
- **THEN** システムは生成内容サマリーを画面に表示してユーザーに確認（Y/n）を求め、承認後に `git init` とローカル初期コミットを実行し、Cursorを自動起動する（GitHubへのPushは行わない）

#### Scenario: Gitユーザー情報未設定時の安全な停止

- **WHEN** `git config user.name` または `user.email` が未設定の環境で実行された時
- **THEN** システムは自動コミットを停止し、Git設定コマンドを案内してユーザー自身によるコミットを促す

### Requirement: テンプレート更新の安全な検知・レビューフロー

システムは、共通テンプレートが更新された際に `copier check-update` を用いて既存Case Projectに適用可能な更新候補を検知・差分提示し、Case固有ファイルとの競合を防止するために自動上書きを行わず、ユーザーのレビューを経て適用する仕組みを提供しなければならない（SHALL）。

#### Scenario: テンプレート更新の検知と手動レビュー

- **WHEN** ユーザーが既存Case Project内でテンプレート更新チェックを実行した時
- **THEN** システムはGit作業ツリーがクリーンであることを確認した上で更新差分を表示し、競合が発生した場合は自動解決せず手動マージを促す
