# OpenSpec Case Project初期化統合の実装計画

created: 2026-08-24 21:31 (JST)
update: 2026-08-24 21:31 (JST)
author: Codex (GPT-5)

## 目的

OpenSpec Change `add-openspec-case-project-bootstrap` に基づき、Windows 11のCase Project生成時にOpenSpecを自動初期化できるようにする。初学者が保存先を迷わず選択でき、OpenSpecの失敗時にもProjectを失わず再実行できる状態を実現する。

## 対象範囲

- Node.js LTS、npm、npxの導入・診断・検証
- 検証済みOpenSpec CLIバージョンの設定管理
- `New-AnalysisProject.ps1`の保存先入力・完全パス検証
- OpenSpec初期化、`AI_FRAMEWORK_STATUS.yml`、再実行スクリプト
- `.ai-backup/<日時>/`へのOpenSpec管理対象バックアップ
- Git初期化前のOpenSpec設定、明示的ステージング、初学者向け案内
- 合成データおよび異常系を含む自動検証

## 対象外

- CC-SDDその他AIフレームワーク
- macOSスクリプト
- OpenSpec Change Artifactの自動生成
- GitHubへのPush、リモートリポジトリ操作
- 実データ、認証情報、`outputs/private/`の変更

## 実装対象ファイルの想定

- `scripts/windows/03-install-reporting.ps1`
- `scripts/windows/05-verify.ps1`
- `scripts/project/New-AnalysisProject.ps1`
- `scripts/project/`内のOpenSpec再実行補助スクリプト
- `templates/analysis-project/template/README.md`
- `templates/analysis-project/template/scripts/setup-openspec.ps1`
- OpenSpecバージョン設定ファイル
- 関連テスト・検証スクリプト

## 実装順序

1. 既存スクリプト、テンプレート、テストの現状を再確認する。
2. Node.js/npm/npxとOpenSpecバージョン設定を追加する。
3. 保存先解決と完全パス矛盾検証を実装する。
4. OpenSpec初期化、状態記録、バックアップ、再実行を実装する。
5. Case Project Factoryの生成・確認・初期化・Git順序を統合する。
6. READMEと完了案内を更新する。
7. 正常系・異常系・機密情報除外・OpenSpec検証を実行する。

## 完了条件

- OpenSpec tasks 1.1〜6.3が実装され、tasks.mdで完了になる。
- `openspec validate "add-openspec-case-project-bootstrap" --type change --json`が`valid: true`になる。
- Node.js/npm/npx未導入、npx失敗、OpenSpecスキップ、再実行、保存先矛盾を検証できる。
- OpenSpec失敗時もCase Projectが保持され、`AI_FRAMEWORK_STATUS.yml`に状態と再実行方法が残る。
- 実データ、認証情報、`outputs/private/`がGitステージング対象にならない。
- macOS、CC-SDD、既存のMySQL/ODBC/SAS任意利用導線に意図しない差分がない。

## 承認・実行境界

本計画は、ユーザーが明示した`openspec-apply-change`指示の対象範囲に限定する。対象範囲外の依存関係変更、外部システムへの書き込み、Git commit、remote pushは別途確認する。
