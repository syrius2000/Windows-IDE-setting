## 1. 事前集約データ生成パイプラインと厳格な開示統制

- [x] 1.1 `sample_rwd_pipeline.py` に、ブラウザ配布用の事前集計データ（`outputs/private/interactive_cohort_summary.json`）を生成する集約関数と、5例未満時の全集計値抑制（`mean_followup` 含む全メトリクスのマスキング）ロジックを実装する
- [x] 1.2 DuckDBおよび標準ライブラリ（SQLite）のフォールバックを実装し、どのような環境でも確実に事前集約データを生成できるようにする
- [x] 1.3 `reports/quarto/` への生データ・集計データ配置を廃止し、`outputs/private/` のみに出力するよう境界を統一する

## 2. 完全自己完結・Pure Local インタラクティブQuartoテンプレートの実装

- [x] 2.1 `templates/analysis-project/template/reports/quarto/interactive_summary.qmd` を実装し、外部CDN・外部WASM・Workerを一切使わない Pure Local JavaScript + SVG による動的フィルタリング（群・性別）およびグラフ・集計表描画を実装する
- [x] 2.2 `embed-resources: true` を設定し、外部通信ゼロの完全自己完結HTMLとして `outputs/private/interactive_summary.html` に出力する構成を確立する

## 3. ローカルプレビュー機能とタスク構成

- [x] 3.1 `templates/analysis-project/template/.vscode/tasks.json` および `package.json.jinja` に、`outputs/private/` を対象とするビルドタスクおよび安全なローカルプレビュー用タスク（`127.0.0.1` バインド）を整備する
- [x] 3.2 共同研究者向けの閲覧手順および配布前チェックリストを `docs/daily-operations.md` に追記する

## 4. プロジェクト検証エンジンと自動テストスイートの拡張・実ブラウザ検証

- [x] 4.1 `scripts/project/validate-project.py` に、生成されたHTML内の外部タグ（`<script src>`, `<link href>` 等）、JS動的通信（`fetch`, `import`, `Worker`）、既知CDNドメイン（jsdelivr, unpkg, observableusercontent等）、個票識別子、および不適切な成果物配置の網羅的検出ルールを実装する
- [x] 4.2 `tests/test_all_scenarios.py` に、小セル全集計値抑制、Quarto End-to-End生成、外部通信ゼロ検証、および全リークパターンの検知テストを追加する
- [x] 4.3 `tests/test_all_scenarios.py` に、Headless Chrome / CDP による実ブラウザ自動検証テスト（`file://` ダブルクリック起動、DOM要素描画、動的フィルタ操作、エラーゼロ）を追加する
