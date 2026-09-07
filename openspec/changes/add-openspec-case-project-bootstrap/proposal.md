# Case ProjectへのOpenSpec自動初期化導入

created: 2026-08-24 20:27 (JST)
update: 2026-08-24 20:27 (JST)
author: Codex (GPT-5)

## Why

現在のCase Project Factoryは、標準ディレクトリ、`PROJECT.yml`、Cursor設定、Git初期化までを整備するが、仕様駆動開発を開始するためのOpenSpec環境は利用者が別途手作業で設定する必要がある。初学者が新規統計プロジェクトの作成直後からOpenSpecを使って安全に要件定義を始められるよう、Windows 11のNode.js/npm/npx環境を検証し、Case Project生成フローにOpenSpec初期化を組み込む。

## What Changes

- Windows 11の共通環境セットアップで、Node.js LTS、npm、npxの導入・診断・バージョン検証を行う。
- `New-AnalysisProject.ps1`に、対話式入力と引数指定の両方で保存先を選択できる導線を追加する。
- `-DestinationPath`による完全パス指定を追加し、`-DestinationPath`と`-DestinationRoot`または`-Name`が矛盾する場合は生成前にエラーとする。
- プロジェクト生成、`PROJECT.yml`検証、生成結果プレビュー、利用者確認の後、Git初期化前に検証済みバージョンのOpenSpec CLIを`npx`で実行し、プロジェクトルートへ`openspec/`を初期化する。
- OpenSpecのChange Artifactは自動生成せず、利用者が最初のテーマを入力した後に作成できる状態までを整備する。
- OpenSpecのバージョンをリポジトリ内の設定で管理し、グローバルインストールに依存しない。
- OpenSpecの初期化結果を`AI_FRAMEWORK_STATUS.yml`へ記録し、成功・スキップ・失敗を区別する。
- OpenSpec初期化がネットワーク等で失敗しても、生成済みCase Projectを削除せず、Git初期化を継続できるようにする。
- 初期化失敗・スキップ後に、生成プロジェクト内の再実行用PowerShellスクリプトと画面表示から復旧手順を案内する。
- OpenSpec初期化後の次の行動を、セットアップ完了画面と生成プロジェクトのREADMEの両方に日本語で表示する。
- 本ChangeではCC-SDDを導入しない。OpenSpecを正式な仕様駆動開発フレームワークとして一本化する。
- 対象はWindows 11に限定し、既存のmacOSプロジェクト生成スクリプトは変更しない。
- 既存のフレームワーク管理対象を再設定する場合は、上書き前に`.ai-backup/<日時>/`へバックアップし、対象を画面表示する。利用者作成ファイルは管理対象外として保護する。

## Capabilities

### New Capabilities

なし。新規の独立Capabilityではなく、既存のWindows環境自動化とCase Project Factoryの要件を拡張する。

### Modified Capabilities

- `openspec/specs/windows-environment-automation/spec.md`: Node.js/npm/npxの診断・導入・検証、およびWindows 11でのOpenSpec CLI実行前提を追加する。
- `openspec/specs/analysis-project-factory/spec.md`: 保存先の対話式・引数指定、完全パス検証、OpenSpec初期化、状態記録、再実行、Git初期化前の利用者確認フローを追加する。

## Impact

- **Windowsスクリプト**: `scripts/windows/03-install-reporting.ps1`、`05-verify.ps1`、必要に応じてマスターセットアップの検証項目を拡張する。
- **Case Project Factory**: `scripts/project/New-AnalysisProject.ps1`に保存先入力、OpenSpec初期化、状態記録、再実行案内、Git初期化順序の変更を追加する。
- **生成テンプレート**: OpenSpec状態ファイル、再実行スクリプト、初学者向けREADME案内、およびバックアップ境界を追加する。
- **設定・依存関係**: OpenSpecの検証済みバージョンを設定ファイルで管理し、Node.js/npm/npxを実行前提とする。OpenSpecおよびCC-SDDのグローバルインストールは行わない。
- **Git・データ安全性**: OpenSpec初期化失敗時も生成物を保持するが、実データ、認証情報、`outputs/private/`の内容をコミット対象へ追加しない既存ガードレールを維持する。
- **対象範囲**: Windows 11のみ。macOSの既存スクリプト、既存のMySQL直接接続・ODBC任意プロファイル、SAS任意利用方針には影響を与えない。
