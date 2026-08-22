## Purpose

研究プロジェクト全体において、SAS CP932とUTF-8開発領域の分離、機微データおよび認証情報のGit除外、`outputs/` の private/release 境界管理（`release-manifest.yml` 含む）、ロックファイルによる環境再現性、およびAI利用境界マトリクスを標準化し、ガバナンスを徹底する。

## ADDED Requirements

### Requirement: 文字コードとディレクトリの厳格な分離
システムは、Case Project内においてSASプログラム専用領域（`src/sas-cp932/`）と、UTF-8専用領域（`src/python/`, `src/r/`, `src/typescript/`, `sql/`, `reports/`, `tests/`）を明確に分離し、相互変換時の意図しない上書きや文字化けを防止しなければならない（SHALL）。

#### Scenario: SAS CP932コードとPython UTF-8コードの併存
- **WHEN** プロジェクト内で `.sas` ファイルおよび `.py` ファイルが保存・実行された時
- **THEN** SASソースはCP932エンコーディングで維持され、PythonソースはUTF-8で維持され、Cursor上で文字化けを起こさずに編集・実行できる

### Requirement: outputs/ のデータ境界分離と release-manifest.yml による開示統制
システムは、`outputs/` 配下をGit除外された機微な中間生成物領域（`outputs/private/`）と、人手確認済みの報告・公開可能成果物領域（`outputs/release/`）に分離し、`outputs/release/release-manifest.yml` にて開示統制（直接識別子除去、小セル抑制確認、自由記載欄確認、開示リスクレビュー）の承認履歴を記録しなければならない（SHALL）。

#### Scenario: private領域の自動Git除外
- **WHEN** SASやPythonの解析スクリプトが中間テーブルや個票ログを `outputs/private/` に出力した時
- **THEN** `.gitignore` により該当ファイルはGit追跡対象外となり、誤コミットが防止される

#### Scenario: release成果物のマニフェスト承認
- **WHEN** 集計表や図表を外部報告のために `outputs/release/` に配置する時
- **THEN** 研究責任者は `release-manifest.yml` にレビュー実施日、確認者、小セル抑制・識別子確認ステータスを記入してコミットする

### Requirement: 物理的データ隔離とGit投入禁止ガードレール
システムは、実RWDデータおよび認証情報（パスワード、APIキー、トークン）をGitプロジェクト外の保護領域に配置する運用を前提とし、プロジェクト内の `.gitignore`, `.cursorignore`, Gitleaks設定, pre-commitフックによって禁止ファイルや秘密情報の混入を検知・遮断しなければならない（SHALL）。

#### Scenario: 禁止データファイルのコミット防止
- **WHEN** ユーザーが誤って `.sas7bdat` や実患者データを含むCSVをGitステージングしようとした時
- **THEN** `.gitignore` および pre-commit フックが検知してコミットを遮断し、外部データ領域への移動を案内する

### Requirement: ロックファイルによる完全な環境再現性
システムは、Python（`uv.lock`）、R（`renv.lock`）、およびTypeScript（`pnpm-lock.yaml`）のロックファイルを提供し、新規環境や他端末において依存関係のズレなしに解析環境を復元できるようにしなければならない（SHALL）。

#### Scenario: ロックファイルからの環境復元
- **WHEN** ユーザーが `uv sync`、`renv::restore()`、`pnpm install --frozen-lockfile` を実行した時
- **THEN** システムはすべての依存ライブラリをマニフェストに記録された完全一致バージョンで再現・インストールする

### Requirement: AI利用境界マトリクスとAGENTS.md / Cursor Rules
システムは、公開情報・合成データ・仮名化データ・非匿名化生データの区分ごとに、クラウドAI（Cursor Pro Privacy Mode）およびローカルLLM（Ollama）の入力可否を定めた「AI利用境界マトリクス」と、Cursor Agentに遵守させる `.cursor/rules/` および `AGENTS.md` を提供しなければならない（SHALL）。

#### Scenario: AIプロンプトへの実データ入力防止ガイド
- **WHEN** 開発者またはAI AgentがCursorでコード生成やリファクタリングを行う時
- **THEN** `.cursor/rules/` により実データや患者識別子のクラウド送信が禁止され、合成データ（`data/synthetic/`）を用いたコード作成が誘導される
