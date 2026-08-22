## Purpose

事前集計および開示統制（小セル全集計値抑制・直接識別子除去等）が完了した安全なデータを用い、外部インターネット通信を一切行わずに院内・ローカルブラウザ（Microsoft Edge / Google Chrome）内で対話的な集計条件フィルタリングと図表切替を行えるQuarto自己完結型インタラクティブ報告書機能を提供する。

## ADDED Requirements

### Requirement: 自己完結型インタラクティブQuartoテンプレートの提供（Pure Local / 外部通信ゼロ）

システムは、Case Project内の `reports/quarto/` において、インライン自己完結型インタラクティブ報告書テンプレート（`reports/quarto/interactive_summary.qmd`）を提供し、外部CDN（unpkg/jsdelivr/Observable等）、外部Web Worker、および外部WASMに一切依存しない完全自己完結HTMLを `outputs/private/` または `outputs/release/` へ生成できなければならない（SHALL）。

#### Scenario: 自己完結インタラクティブ報告書の生成とダブルクリック起動（file://）

- **WHEN** ユーザーがインタラクティブ報告書をレンダリングし、生成された単一HTML（`outputs/private/interactive_summary.html`）を Edge または Chrome でダブルクリック（`file://`）した時
- **THEN** レポートは外部通信・外部CDNを行わずにインライン埋め込みデータとPure Localスクリプトのみで起動し、期間・群・性別のフィルタリングおよびSVGグラフ・集計表の動的再描画が即座に動作する

#### Scenario: 外部ネットワーク遮断環境での完全動作

- **WHEN** ネットワークが完全に切断されたオフラインPC上で生成されたインタラクティブ報告書をブラウザで開いた時
- **THEN** システムは通信エラーやCORSブロックを起こすことなく起動し、すべての対話操作がローカルメモリ上で完結する

### Requirement: ブラウザ配布前の開示統制（全集計値抑制）とデータ境界適合検査

システムは、ブラウザに渡すデータが個票・未加工の生データではなく、事前集計・小セル全集計値抑制（5例未満時の患者数・イベント数・発生率・平均観察期間など全メトリクスのマスキング）・直接識別子除去が施された安全な集計データであることを機械的および人手（`release-manifest.yml`）に検査・保証しなければならない（SHALL）。

#### Scenario: 個票データおよび直接識別子の混入防止

- **WHEN** インタラクティブ報告書の生成前またはプロジェクト検証スクリプト実行時
- **THEN** システムは埋め込みデータ内に患者ID、氏名、または小セル未加工の生データが含まれていないことを検証し、違反があれば生成・検証をブロックする

#### Scenario: 5例未満セルの全集計値抑制

- **WHEN** 事前集計パイプラインが実行された時
- **THEN** 患者数が5例未満のセルは、患者数だけでなくイベント数、発生率、平均観察期間等のすべての集計値が `None`（マスキング）に抑制される

#### Scenario: release成果物の開示統制記録

- **WHEN** インタラクティブ報告書を共同研究者への配布用に `outputs/release/` に配置する時
- **THEN** 研究責任者は `release-manifest.yml` に小セル抑制・識別子除去等の確認結果を記録してコミットする

### Requirement: 外部通信ゼロ（完全オフライン）の保証と網羅的静的検証

システムは、生成されたインタラクティブHTML報告書内に外部CDN（unpkg, jsdelivr, observableusercontent等）、外部フォント、動的 `fetch()` / `import()`、外部Worker/WASM等の外部ネットワークリクエストが含まれていないことを機械的に検証できなければならない（SHALL）。また、生成HTMLが `reports/quarto/` ではなく `outputs/private/` または `outputs/release/` に配置されていることを検証する。

#### Scenario: 外部URL混入および不適切配置の自動検知

- **WHEN** プロジェクト整合性検証スクリプト（`validate-project.py`）が実行された時
- **THEN** システムは生成物内の `<script>`, `<link>`, `fetch()`, `import`, CDNホスト名、および出力ディレクトリ配置を検査し、外部通信依存や不適切な成果物配置があればエラーを出力する

### Requirement: 127.0.0.1 ローカルプレビューと静的HTMLフォールバックの提供

システムは、厳格なブラウザ制約環境向けの安全なローカルプレビュー機能（`127.0.0.1` バインドで `outputs/private/` を対象）を提供するとともに、従来の静的 Quarto HTML（`reports/quarto/summary.qmd`）および PDF / PowerPoint 報告書の生成能力を損なうことなく維持しなければならない（SHALL）。

#### Scenario: 127.0.0.1 ローカルプレビューの実行

- **WHEN** ユーザーがCursorタスクまたはコマンドからローカルプレビューを実行した時
- **THEN** システムは外部公開されない `127.0.0.1` 上で一時プレビューサーバーを起動し、安全に報告書を表示できる

#### Scenario: 従来の静的レポート生成の継続性

- **WHEN** ユーザーが既存の `reports/quarto/summary.qmd` をレンダリングした時
- **THEN** システムはインタラクティブ機能の追加による影響を受けず、軽量な静的レポートを正常に出力する
