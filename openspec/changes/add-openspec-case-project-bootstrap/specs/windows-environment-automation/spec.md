## MODIFIED Requirements

### Requirement: WinGet優先＋統制公式フォールバックによるツール導入

システムは、開発共通ツール（Terminal, PS7, Git, 7-Zip）、統計解析ツール（`uv`, Python 3.12, `rig`, R, Rtools, Quarto, DuckDB）、報告自動化ツール（Node.js LTS, npm, npx, `pnpm`, Slidev, PptxGenJS）をWinGet経由でサイレント導入し、WinGet失敗時は公式HTTPSインストーラーのハッシュ検証付きフォールバックを実行しなければならない（SHALL）。また、Copier固定バージョンを`uv tool`経由で事前導入し、OpenSpec CLIはグローバルインストールしてはならない（SHALL NOT）。

#### Scenario: WinGetによるサイレント一括導入

- **WHEN** `01-install-common.ps1` 〜 `03-install-reporting.ps1` が順次実行された時
- **THEN** システムは各ツールを完全一致ID・規約自動同意で導入し、導入後に`node --version`、`npm --version`、`npx --version`を含むバージョンコマンドを実行して正常インストールを検証する

#### Scenario: WinGet失敗時の統制公式フォールバック

- **WHEN** WinGetによる特定パッケージ（`uv` や`rig`等）の導入がタイムアウトまたはエラーとなった時
- **THEN** システムは公式配布元URLから署名・ハッシュ付きインストーラーを一時領域に取得してサイレント実行し、ログに取得元URL・バージョン・終了コードを記録する

#### Scenario: Node.js/npm/npxの利用不能検出

- **WHEN** Node.js、npm、またはnpxが見つからない、またはバージョン検証に失敗した時
- **THEN** システムはOpenSpec初期化を実行せず、原因と再実行に必要なセットアップ手順を診断レポートへ記録する

### Requirement: Windows環境エンドツーエンド検証

システムは、導入された全ツールチェーン（Git, uv, Python, R, Node.js, npm, npx, DuckDB, Quarto, SAS文字コード読込）の稼働を合成データを用いて自動検証し、合格判定を出力しなければならない（SHALL）。

#### Scenario: 全ツールの統合検証実行

- **WHEN** `05-verify.ps1` が実行された時
- **THEN** システムは合成データを用いてSASファイルの読み込み、Python/DuckDBでの集計、Rによる記述統計、およびPPTX/Excel出力を順次実行し、Git、Node.js、npm、npxを含むすべての工程が成功したことを確認して総合判定を表示する

## ADDED Requirements

### Requirement: OpenSpec実行前提の検証済みバージョン管理

システムは、Windows 11上でCase ProjectへOpenSpecを初期化するために必要な検証済みOpenSpec CLIバージョンをリポジトリ内の設定で管理し、グローバルインストールに依存せずプロジェクト単位の実行に利用できなければならない（SHALL）。

#### Scenario: 検証済みOpenSpecバージョンの参照

- **WHEN** Case Project FactoryがOpenSpec初期化を開始した時
- **THEN** システムはリポジトリ内のバージョン設定を読み取り、設定されたバージョンを使う実行方法を選択し、未設定または不正な設定の場合は初期化を開始せず原因を表示する

