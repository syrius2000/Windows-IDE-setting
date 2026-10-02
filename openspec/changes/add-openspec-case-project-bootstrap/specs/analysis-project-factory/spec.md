## MODIFIED Requirements

### Requirement: ワンコマンドによるCase Project自動生成

システムは、Windows（`New-AnalysisProject.ps1`）およびmacOS（`new-analysis-project.sh`）において、プロジェクト名、プロファイル（`windows-standard` / `mac-rwd-expert`）、データ分類（`synthetic` / `deidentified` / `sensitive`）、および保存先を指定して、CopierテンプレートからCase Projectディレクトリを自動生成しなければならない（SHALL）。Windowsでは、保存先を対話式入力または引数で指定でき、完全パス指定が他の保存先指定と矛盾する場合は生成を開始してはならない（SHALL NOT）。

#### Scenario: Windows上でのCase Project対話的/引数生成

- **WHEN** ユーザーが`New-AnalysisProject.ps1`を実行し、プロジェクト名、プロファイル、データ分類、保存先を対話式または引数で指定した時
- **THEN** システムは事前インストールされたCopierを呼び出して指定された保存先へプロジェクトディレクトリを生成し、`PROJECT.yml`を構成する

#### Scenario: 完全パスと保存先指定の不整合

- **WHEN** ユーザーが`-DestinationPath`と`-DestinationRoot`または`-Name`を指定し、それらから求められる最終パスが一致しない時
- **THEN** システムは生成、既存ファイル変更、Git初期化を行わず、不整合の内容と正しい指定方法を表示する

#### Scenario: 既存ディレクトリの保護と中断時ロールバック

- **WHEN** 生成先ディレクトリが既に存在する場合、またはテンプレート生成途中でエラーが発生した時
- **THEN** システムは利用者作成ファイルを保護し、エラー時は新たに作成した不完全な生成物をクリーンアップして安全に再実行できる状態を保つ

### Requirement: validate-project.py によるプロジェクト整合性検査とGit初期化フロー

システムは、プロジェクト生成直後に`validate-project.py`を実行して、標準ディレクトリ（`src/`, `sql/`, `reports/`, `outputs/`）、禁止拡張子、Git追跡除外設定、文字コードを機械検査し、生成結果のプレビュー、OpenSpec初期化結果の確認、およびユーザーの明示的確認を経て`git init`と初期コミットを実行しなければならない（SHALL）。

#### Scenario: 機械検査合格後のユーザー確認付きGit初期化

- **WHEN** プロジェクトが正常に生成され、`validate-project.py`の機械検査に合格した時
- **THEN** システムは生成内容とOpenSpec設定内容のサマリーを表示してユーザーに確認（Y/n）を求め、承認後にOpenSpecを初期化してから`git init`とローカル初期コミットを実行し、Cursorを自動起動する（GitHubへのPushは行わない）

#### Scenario: Gitユーザー情報未設定時の安全な停止

- **WHEN** `git config user.name`または`user.email`が未設定の環境で実行された時
- **THEN** システムは自動コミットを停止し、Git設定コマンドとOpenSpecの現在状態を案内して、ユーザー自身によるコミットまたは再実行を促す

## ADDED Requirements

### Requirement: Case ProjectへのOpenSpec初期化

システムは、Windows 11で生成したCase Projectのルートに、検証済みバージョンのOpenSpec CLIをプロジェクト単位で実行して`openspec/`を初期化し、Cursor統合のみを設定し、日本語をArtifactの既定言語としなければならない（SHALL）。利用者が最初のテーマ入力後にChange Artifactを作成できる状態を提供する。

#### Scenario: OpenSpecの正常初期化

- **WHEN** プロジェクト生成、`PROJECT.yml`検証、プレビュー、利用者確認が完了し、Node.js/npm/npxが利用可能な時
- **THEN** システムはプロジェクトルートへ`openspec/`を初期化し、proposal等のChange Artifactを自動生成せず、次の利用手順を表示する

#### Scenario: Cursor専用・日本語での非対話初期化

- **WHEN** システムが検証済みOpenSpec CLIを実行する時
- **THEN** システムはCursor統合だけを選択し、Artifactの既定言語を日本語に設定して、AIツール選択の対話入力を要求しない

#### Scenario: OpenSpec初期化のネットワーク失敗

- **WHEN** npxによるOpenSpec取得または初期化がネットワークエラー等で失敗した時
- **THEN** システムは生成済みCase Projectを削除せず、Git初期化を継続可能とし、`AI_FRAMEWORK_STATUS.yml`へ`failed`状態、エラー概要、再実行方法を記録する

#### Scenario: OpenSpec初期化の明示的スキップ

- **WHEN** ユーザーが対話式確認でOpenSpec初期化をスキップする、または非対話モードで初期化条件を満たさない時
- **THEN** システムはプロジェクトを保持し、`AI_FRAMEWORK_STATUS.yml`へ`skipped`状態と再実行方法を記録して、Git初期化を継続する

### Requirement: OpenSpec設定の再実行と状態表示

システムは、OpenSpec初期化を再実行できるスクリプトを生成プロジェクト内に提供し、実行前に管理対象ファイルをバックアップして対象を表示しなければならない（SHALL）。

#### Scenario: OpenSpec初期化の再実行

- **WHEN** ユーザーが生成プロジェクト内の再実行スクリプトを実行した時
- **THEN** システムは現在の`AI_FRAMEWORK_STATUS.yml`を確認し、OpenSpec管理対象を`.ai-backup/<日時>/`へバックアップしてから再初期化を行い、結果と対象ファイルを表示する

#### Scenario: 利用者ファイルの保護

- **WHEN** 再初期化対象に`README.md`、利用者作成の解析コード、実データ、認証情報、または`outputs/private/`が含まれる時
- **THEN** システムはそれらをOpenSpec管理対象として扱わず、上書き・バックアップ対象から除外する

### Requirement: 初学者向けOpenSpec完了案内

システムは、OpenSpec初期化の成否にかかわらず、初学者が次に行う操作を画面と生成プロジェクトのREADMEの両方で日本語により案内しなければならない（SHALL）。

#### Scenario: OpenSpec初期化成功後の案内

- **WHEN** OpenSpec初期化が成功した時
- **THEN** システムはCursorでプロジェクトを開くこと、最初のテーマをOpenSpecへ入力すること、proposalからtasksまでを確認してから実装することを案内する

#### Scenario: OpenSpec初期化失敗・スキップ後の案内

- **WHEN** OpenSpec初期化が失敗またはスキップされた時
- **THEN** システムはプロジェクトが利用可能であること、再実行スクリプトの場所、`AI_FRAMEWORK_STATUS.yml`の確認方法、およびGitHubへPushしていないことを案内する
