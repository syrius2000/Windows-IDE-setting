## Purpose

Windows 11環境において、IT初心者の統計専門家が迷うことなくモダンな解析環境（Git, Python/uv, R/rig, Node.js/pnpm, Quarto, DuckDB, Gitleaks, Cursor設定）を自動セットアップ・診断・検証し、既存のローカルSAS（CP932）資産をCursor内から安全にバッチ実行できるようにする。

## ADDED Requirements

### Requirement: Windows環境診断スクリプト
システムは、セットアップ開始前にWindows 11のCPU、RAM、GPU、VRAM、空きストレージ容量、管理者権限、PowerShellバージョン、WinGet状態、ファイアウォールを非破壊的に診断し、結果レポートを出力しなければならない（SHALL）。

#### Scenario: 診断の正常実行とレポート出力
- **WHEN** ユーザーが管理者権限のPowerShellで `00-diagnose.ps1` を実行した時
- **THEN** システムはハードウェア仕様と前提ツールの状態を検査し、適合判定と推奨アクションを含むログファイルを `.run/reports/diagnose-report.json` に出力する

#### Scenario: 管理者権限不足または前提不適合の検出
- **WHEN** 一般ユーザー権限または要件を満たさないWindowsバージョンで実行された時
- **THEN** システムはエラー理由を明示してスクリプトを停止し、管理者昇格または情シス相談用の案内を表示する

### Requirement: WinGet優先＋統制公式フォールバックによるツール導入
システムは、開発共通ツール（Terminal, PS7, Git, 7-Zip）、統計解析ツール（`uv`, Python 3.12, `rig`, R, Rtools, Quarto, DuckDB）、報告自動化ツール（Node.js LTS, `pnpm`, Slidev, PptxGenJS）をWinGet経由でサイレント導入し、WinGet失敗時は公式HTTPSインストーラーのハッシュ検証付きフォールバックを実行しなければならない（SHALL）。また、Copier固定バージョンを `uv tool` 経由で事前導入しなければならない（SHALL）。

#### Scenario: WinGetによるサイレント一括導入
- **WHEN** `01-install-common.ps1` 〜 `03-install-reporting.ps1` が順次実行された時
- **THEN** システムは各ツールを完全一致ID・規約自動同意で導入し、導入後にバージョンコマンドを実行して正常インストールを検証する

#### Scenario: WinGet失敗時の統制公式フォールバック
- **WHEN** WinGetによる特定パッケージ（`uv` や `rig` 等）の導入がタイムアウトまたはエラーとなった時
- **THEN** システムは公式配布元URLから署名・ハッシュ付きインストーラーを一時領域に取得してサイレント実行し、ログに取得元URL・バージョン・終了コードを記録する

### Requirement: Cursor設定と文字コード自動マッピング
システムは、Cursorに必要な推奨拡張機能（Python, Jupyter, R, Quarto, EditorConfig, Gitleaks等）を導入し、`.sas` ファイルを `shiftjis (CP932)`、その他ソースコード・Markdownを `utf8` として自動認識する設定を構成しなければならない（SHALL）。

#### Scenario: Cursor拡張機能と文字コードの自動構成
- **WHEN** `04-configure.ps1` が実行された時
- **THEN** システムはCursorの設定ファイル（`settings.json`）およびキーバインドを更新し、CP932とUTF-8の拡張子マッピングを適用する

### Requirement: ローカルSASバッチ実行ラッパー（invoke-sas.ps1）
システムは、ローカルSASの実行ファイルパスを自動検出し、現在開いている `.sas`（CP932）ファイルをバッチ実行して、ログおよび出力（LST）をプロジェクト内の `.run/sas/<program>/<timestamp>/` に分離出力し、`ERROR:` および `WARNING:` を自動解析して結果を返さなければならない（SHALL）。

#### Scenario: CursorタスクからのSASプログラム実行
- **WHEN** ユーザーがCursor上で `.sas` ファイルを開き、`Ctrl+Shift+B`（またはSAS実行タスク）を実行した時
- **THEN** `invoke-sas.ps1` が起動してSASをバッチ実行し、コンソールに実行成否・ERROR件数・WARNING件数をサマリー表示し、生成された `.log` と `.lst` のパスを案内する

#### Scenario: SAS構文エラーまたはデータ不在エラーの検知
- **WHEN** SAS実行ログ内に `ERROR:` が含まれる時
- **THEN** スクリプトは終了コード0であっても失敗と判定し、該当エラー行をハイライト表示してユーザーに修正を促す

### Requirement: Windows環境エンドツーエンド検証
システムは、導入された全ツールチェーン（Git, uv, Python, R, Node.js, DuckDB, Quarto, SAS文字コード読込）の稼働を合成データを用いて自動検証し、合格判定を出力しなければならない（SHALL）。

#### Scenario: 全ツールの統合検証実行
- **WHEN** `05-verify.ps1` が実行された時
- **THEN** システムは合成データを用いてSASファイルの読み込み、Python/DuckDBでの集計、Rによる記述統計、およびPPTX/Excel出力を順次実行し、すべての工程が成功したことを確認して総合判定を表示する
