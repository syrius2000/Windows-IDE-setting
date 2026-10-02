# Case ProjectへのOpenSpec自動初期化実装タスク

created: 2026-08-24 21:22 (JST)
update: 2026-10-03 06:06 (JST)
author: Codex (GPT-6)

## 1. Windows前提ツールとバージョン設定

- [x] 1.1 Node.js LTS、npm、npxの検証項目をWindows報告・導入スクリプトへ追加し、`node --version`、`npm --version`、`npx --version`が診断結果に記録されることを確認する
- [x] 1.2 OpenSpec CLIの検証済みバージョンをリポジトリ内の設定ファイルへ追加し、JSON/YAML形式と必須キーを機械検証するテストを追加する
- [x] 1.3 Node.js、npm、npxのいずれかが利用不能な場合に、OpenSpec初期化を実行せず、再実行手順を含む診断結果を出力する処理を実装し、未導入状態のテストを通す
- [x] 1.4 OpenSpec CLIをグローバルインストールせず、設定済みバージョンを`npx --yes`で実行し、`--tools cursor --language ja`を指定するコマンド組み立てを実装する

## 2. 保存先解決と入力検証

- [x] 2.1 `New-AnalysisProject.ps1`に完全パス用の`-DestinationPath`引数を追加し、既存の`-DestinationRoot`と`-Name`の後方互換性を保ったパラメータ検証を実装する
- [x] 2.2 `-DestinationPath`、`-DestinationRoot`、`-Name`から最終Target Directoryを正規化する処理を実装し、Windowsの絶対パス・相対パス・末尾区切り文字を含むテストを通す
- [x] 2.3 保存先未指定の対話式モードで既定値を表示し、Enterで採用できる入力導線を追加し、表示された最終パスと生成先が一致することを確認する
- [x] 2.4 保存先指定が矛盾する場合にCopier、OpenSpec、Gitを実行せず、原因と正しい指定方法を表示するテストを追加する

## 3. OpenSpec初期化と状態管理

- [x] 3.1 生成Project内へ`scripts/setup-openspec.ps1`を配置するテンプレートまたはコピー処理を追加し、生成後のスクリプトが単独で存在することを検証する
- [x] 3.2 OpenSpec初期化処理を実装し、成功時にProjectルートの`openspec/`を作成してChange Artifactを自動生成しないことをテストする
- [x] 3.3 `AI_FRAMEWORK_STATUS.yml`の`success`、`skipped`、`failed`各状態、CLIパッケージ、バージョン、時刻、エラー概要、再実行コマンドを記録する処理を実装し、秘密情報が出力されないことを検査する
- [ ] 3.4 npxのネットワーク失敗、OpenSpec初期化失敗、利用者によるスキップを個別に扱い、Projectを削除せずGit初期化へ継続できるテストを追加する
- [x] 3.5 再実行時に既存`openspec/`を`.ai-backup/<JST日時>/openspec/`へ退避し、バックアップ対象を表示してから再初期化する処理を実装し、バックアップと復旧可能性を検証する
- [x] 3.6 再実行処理が`.cursor/rules/`、`README.md`、利用者コード、実データ、認証情報、`outputs/private/`を変更しないことを禁止対象テストで確認する

## 4. Case Project Factoryへの統合

- [x] 4.1 Copier生成と`validate-project.py`実行後に、OpenSpec設定内容と生成物のプレビューを表示し、利用者確認を取得する処理を実装する
- [x] 4.2 利用者確認後、OpenSpec初期化、`AI_FRAMEWORK_STATUS.yml`記録、Git初期化、初期コミット、Cursor起動の順序を実装し、処理ログで順序を検証する
- [x] 4.3 初期コミットの明示的ステージング対象へ`openspec/`、`AI_FRAMEWORK_STATUS.yml`、`scripts/setup-openspec.ps1`を追加し、`outputs/private/`と秘密情報がステージングされないことをテストする
- [x] 4.4 Gitユーザー情報未設定時に自動コミットを停止し、OpenSpec状態とGit設定手順を表示する既存フローとの整合性を確認する

## 5. 初学者向け案内とテンプレート

- [x] 5.1 生成ProjectのREADMEへ、OpenSpec初期化成功時のCursor起動、最初のテーマ入力、proposalからtasksまでの確認手順を日本語で追加する
- [x] 5.2 OpenSpec初期化失敗・スキップ時のREADME案内へ、Projectを継続利用できること、`AI_FRAMEWORK_STATUS.yml`、再実行スクリプト、GitHubへPushしていないことを追加する
- [x] 5.3 セットアップ完了画面に成功・スキップ・失敗ごとの次アクションと再実行コマンドを表示し、初学者向けの表示文テストを追加する
- [x] 5.4 CC-SDD、macOSスクリプト、MySQL/ODBC、SAS任意利用の既存導線が今回のWindows OpenSpec統合で変更されていないことを差分確認する

## 6. 統合検証と引き渡し

- [ ] 6.1 クリーンなWindows 11相当の環境で、Node.js/npm/npx診断からCase Project生成、OpenSpec初期化、Git初期コミット、Cursor起動案内までの成功シナリオを実行して記録する
- [ ] 6.2 保存先矛盾、Node.js/npm/npx未導入、ネットワーク失敗、OpenSpecスキップ、Gitユーザー未設定、再実行の各異常シナリオを実行して、Project保持と状態記録を確認する
- [ ] 6.3 `openspec validate "add-openspec-case-project-bootstrap" --type change --json`、関連自動テスト、Markdownリンク検査、`git diff --check`を実行し、結果を実装報告へ記録する
