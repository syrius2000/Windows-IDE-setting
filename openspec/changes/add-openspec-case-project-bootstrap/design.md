# Case ProjectへのOpenSpec自動初期化設計

created: 2026-08-24 21:19 (JST)
update: 2026-10-03 06:06 (JST)
author: Codex (GPT-6)

## Context

現在のWindows用Case Project Factoryは、Copierによる雛形生成、`PROJECT.yml`検証、生成結果のプレビュー、利用者確認、Git初期化、Cursor起動までを一連の処理として提供している。一方、生成後にOpenSpecを使い始めるためのNode.js/npm/npx検証、`openspec/`初期化、失敗時の状態記録、再実行導線は存在しない。

本設計は、[proposal.md](proposal.md)および差分仕様に従い、Windows 11のCase Project生成フローへOpenSpec初期化を組み込む。CC-SDDや他のAIフレームワークは対象外とし、CursorでOpenSpecを利用する初学者向け導線に集中する。

## Goals / Non-Goals

**Goals:**

- Node.js LTS、npm、npxをWindows環境の前提ツールとして診断・導入・検証する。
- `New-AnalysisProject.ps1`で対話式保存先指定と引数指定を両立する。
- `-DestinationPath`を完全パス指定として扱い、他の保存先指定との矛盾を生成前に検出する。
- プロジェクト生成と機械検証の後、利用者確認を経てGit初期化前にOpenSpecを初期化する。
- OpenSpec CLIをグローバルインストールせず、検証済みバージョンを`npx`で実行する。
- 初期化の成功・スキップ・失敗を`AI_FRAMEWORK_STATUS.yml`へ記録し、失敗しても生成済みProjectを保持する。
- 生成Project内に再実行スクリプトと日本語の次アクション案内を提供する。
- Git初期コミットの対象へ、OpenSpec関連の安全な設定・状態ファイルを含める。

**Non-Goals:**

- CC-SDD、Claude Code、Codex CLI、Antigravity等の追加フレームワーク対応。
- macOSの`new-analysis-project.sh`やmacOS環境診断の変更。
- OpenSpecのproposal、spec、design、tasks等のChange Artifactを自動生成すること。
- GitHubリポジトリ作成、認証、Push、Pull Request作成。
- 実データ、認証情報、`outputs/private/`の自動収集・移動・コミット。

## Decisions

### 1. WindowsセットアップとCase Project Factoryの責務を分離する

Windows環境セットアップはNode.js/npm/npxの導入と稼働確認までを担当する。OpenSpecの`openspec/`初期化は、新規Case Projectの文脈と保存先が確定した後にCase Project Factoryが担当する。

**理由**：環境全体のセットアップと案件固有の初期化を分離することで、環境セットアップの再実行が既存Case Projectを変更せず、Case ProjectごとにOpenSpecの初期化結果を追跡できる。

**代替案**：Windows環境セットアップ時にOpenSpecをグローバル導入する方式は、バージョン衝突と利用者ごとの環境差を生むため採用しない。

### 2. 検証済みバージョンを設定ファイルで管理し、npxで実行する

リポジトリ内にOpenSpec CLIの検証済みバージョンを記載する設定ファイルを置く。Case Project Factoryはこの値を読み取り、次の形式でプロジェクトルートからOpenSpec初期化を実行する。

```text
npx --yes @fission-ai/openspec@<検証済みバージョン> init --tools cursor --language ja
```

`--tools cursor`でCursor統合だけを設定し、`--language ja`で生成Artifactの日本語を既定にする。実際のバージョン値は実装時に公式配布物の動作確認と既存テストを通じて確定し、設定値を変更する場合は別の差分レビュー対象とする。

**理由**：グローバル環境を汚さず、実行バージョンを再現可能にし、初学者がnpm installの詳細を判断しなくてよい。

**代替案**：`@latest`は将来のCLI変更により生成結果が変わるため採用しない。グローバルインストールは複数Project間のバージョン衝突を避けられないため採用しない。

### 3. 保存先解決を単一の正規パスへ正規化する

保存先は次の優先順位で解決する。

1. `-DestinationPath`が指定された場合は、それを完全パスとして採用する。
2. `-DestinationPath`が未指定で`-DestinationRoot`と`-Name`が指定された場合は、`DestinationRoot\Name`を採用する。
3. 対話式モードで未指定の値がある場合は、既定の保存先を表示し、Enterで既定値を採用できるようにする。
4. 複数指定から得られる最終パスが一致しない場合は、Copier、OpenSpec、Gitのいずれも実行せず終了する。

正規化後のTarget Directoryについて、親ディレクトリは必要に応じて作成する。新規生成では空ディレクトリだけを許可し、既存Projectの再設定は生成処理と分離した再実行スクリプトで扱う。

**理由**：初学者には対話式の既定値を提供し、上級利用者には完全パスを提供しつつ、曖昧な保存先による誤生成を防止する。

### 4. OpenSpec初期化を利用者確認とGit初期化の間に置く

処理順序を次のように固定する。

```text
前提ツール検証
  ↓
保存先解決・パス検証
  ↓
CopierでCase Project生成
  ↓
PROJECT.yml・ディレクトリ・除外設定検証
  ↓
生成内容とOpenSpec設定のプレビュー
  ↓
利用者確認
  ↓
OpenSpec初期化
  ↓
AI_FRAMEWORK_STATUS.yml記録
  ↓
git init・対象ファイルの初期コミット
  ↓
Cursor起動と次アクション案内
```

**理由**：OpenSpec設定をProjectの初期コミットへ含めるため、Git初期化前に実行する。ただしOpenSpecが失敗しても生成物を削除せず、状態を明示してGit初期化を継続する。

### 5. 状態記録をYAMLでProject内に保持する

生成Project直下に`AI_FRAMEWORK_STATUS.yml`を作成し、少なくとも次の情報を保持する。

```yaml
openspec:
  status: success # success | skipped | failed
  cli_package: "@fission-ai/openspec"
  cli_version: "検証済みバージョン"
  initialized_at: "YYYY-MM-DDTHH:MM:SS+09:00"
  command: "npx --yes ... init --tools cursor --language ja"
  message: ""
  retry_command: ".\\scripts\\setup-openspec.ps1"
```

パスワード、APIキー、接続文字列、実データの内容は状態ファイルへ保存しない。失敗時は終了コードと利用者が復旧に必要な短いエラー概要だけを記録する。

### 6. 再実行スクリプトはOpenSpec管理対象だけを扱う

生成Projectへ`scripts/setup-openspec.ps1`を配置する。再実行時は次の順序で処理する。

1. 現在の`AI_FRAMEWORK_STATUS.yml`とNode.js/npm/npxを診断する。
2. 既存の`openspec/`がある場合は`.ai-backup/<JST日時>/openspec/`へコピーする。
3. バックアップ先と上書き対象を画面表示する。
4. 検証済みバージョンでOpenSpecを再初期化する。
5. `AI_FRAMEWORK_STATUS.yml`を更新し、再実行結果と次の操作を表示する。

この再実行スクリプトは`.cursor/rules/`、`README.md`、利用者作成コード、実データ、認証情報、`outputs/private/`を変更対象に含めない。CC-SDDを導入しないため、`.cursor/skills/`や`.kiro/`は本Changeの管理対象にしない。

### 7. Git初期コミットは明示的な対象リストで行う

既存の広範な自動ステージングに依存せず、テンプレート生成物、`openspec/`、`AI_FRAMEWORK_STATUS.yml`、`scripts/setup-openspec.ps1`等の安全な管理対象を明示してステージングする。`outputs/private/`、実データ、秘密情報は`.gitignore`と検証スクリプトで除外されていることを確認する。

**理由**：OpenSpecの初期化を追加しても、個人データや機密情報が初期コミットへ混入しないことを既存ガバナンスと同時に保証する。

## Risks / Trade-offs

- **[npx実行時のネットワーク依存]** → 初期化に失敗してもProjectを保持し、`failed`状態と再実行コマンドを記録する。Node.js/npm/npxの事前診断で原因を早期表示する。
- **[OpenSpec CLI更新による生成物の変化]** → 検証済みバージョンを設定ファイルで固定し、バージョン更新時は専用テストと差分レビューを要求する。
- **[保存先の誤指定]** → 完全パスを正規化し、矛盾検出、最終パス表示、利用者確認を実施する。
- **[再初期化による利用者設定の上書き]** → OpenSpec管理対象を`openspec/`に限定し、上書き前に`.ai-backup/<日時>/`へ退避する。
- **[OpenSpec失敗状態のままGit初期化される]** → `AI_FRAMEWORK_STATUS.yml`を必須の状態記録とし、成功・スキップ・失敗を初期コミット前に表示する。
- **[既存のGitステージング対象との不整合]** → 初期コミット対象を明示的に見直し、生成後の機械検査で禁止拡張子、秘密情報、`outputs/private/`の追跡を検査する。

## Migration Plan

1. Windows環境スクリプトにNode.js/npm/npxの診断・導入・検証を追加する。
2. OpenSpec検証済みバージョン設定を追加し、Windows環境の検証スクリプトで確認する。
3. Case Project Factoryに保存先解決、OpenSpec初期化、状態記録、再実行、案内表示を追加する。
4. テンプレートへ再実行スクリプト、状態ファイルの雛形、README案内を追加する。
5. 合成データを用いた新規Project生成、OpenSpec成功、スキップ、ネットワーク失敗、再実行、Git初期コミットのテストを行う。
6. 既存のmacOSスクリプト、既存Case Project、実データ領域に対して変更を適用しないことを確認する。

ロールバック時は、未コミットの生成Projectを削除せず、Gitのコミット前であれば追加ファイルを利用者が確認して除去する。既存Projectの再実行で作成した`.ai-backup/`は復旧用に保持し、OpenSpecの再初期化前の`openspec/`へ戻せる状態を維持する。
