## Context

現在のCase Projectでは、Quarto（`reports/quarto/summary.qmd`）による静的HTML、PDF、およびPowerPointスライドの自動生成に対応している（詳細は `proposal.md` 参照）。しかし、臨床医や共同研究者がブラウザ上で期間、群、年齢層などの集計条件を動的に切り替えながら探索できるインタラクティブな報告書は標準装備されていなかった。

本設計では、外部インターネット通信（CDN/unpkg/jsdelivr/Observable/DuckDB-WASM等）を一切行わない、完全ローカル自己完結型（Pure Local / Zero-External-Dependency）のインタラクティブ報告書アーキテクチャを定義する。

## Goals / Non-Goals

**Goals:**

- **自己完結型テンプレートの提供**: `templates/analysis-project/template/reports/quarto/interactive_summary.qmd` を新設し、Quartoビルドで単一自己完結型HTML（`embed-resources: true`）を `outputs/private/interactive_summary.html` へ生成する。
- **Pure Local インラインUIによる `file://` ダブルクリック動作の 100% 保証**: 外部CDN、動的import、fetch、Web Worker、WASM依存を完全排除したピュアローカル JavaScript + SVG 描画を採用し、Windows 11 / macOS の Edge および Chrome における `file://` ダブルクリック起動を 100% 確実に動作させる。
- **データ開示統制の物理的保証**: 生の個票（`synthetic_cohort.csv` や実データ）をブラウザに渡さず、Python/DuckDB/SQLiteで事前集計・小セル全集計値抑制（5例未満マスキング：患者数・イベント数・発生率・平均観察期間など全メトリクスをNone化）・識別子除去を行った集約データ（`outputs/private/interactive_cohort_summary.json`）のみをインライン埋め込む。
- **完全オフライン動作（外部通信ゼロ）**: CDN（unpkg, jsdelivr, observableusercontent）、外部フォント、Google Analytics等の外部リクエストを0件にし、院内閉域網で安全に閲覧可能にする。
- **出力場所統制の遵守**: レンダリングされたHTMLおよびデータ成果物は `reports/quarto/` ではなく `outputs/private/`（配布時は承認を経て `outputs/release/`）に配置する。
- **実ブラウザCDP自動検証**: 自動テストスイート（`tests/test_all_scenarios.py`）内で Headless Chrome を起動し、`file://` プロトコル下でのレンダリング、動的フィルタ操作、および外部通信ゼロを実機検証する。

**Non-Goals:**

- **外部CDN / DuckDB-WASM の採用**: Web Worker や `.wasm` ファイルの `fetch()` がブラウザの `file://` CORS ポリシーでブロックされるリスク、および意図しない外部CDN通信リークを完全回避するため、外部CDNおよびDuckDB-WASMは一切採用しない。
- 閲覧者による外部生データベースへのリアルタイム書き込み機能。
- クラウドサーバー（AWS, Vercel等）への外部ホスティング。

## Decisions

### 1. レンダリングエンジン: Pure Local インラインJS + SVG によるゼロ外部依存アーキテクチャ

- **決定**: **インライン埋め込みJSON ＋ Pure Local JavaScript ＋ SVG動的チャート ＋ DOM集計テーブル** を標準エンジンとする。
- **理由**:
  - `embed-resources: true` により HTML 1 ファイルに JavaScript、CSS、集計データが完全に内包される。
  - Quarto OJSで発生していた Observable Runtime や DuckDB-WASM 内部の CDN 文字列（`cdn.jsdelivr.net`, `cdn.observableusercontent.com` 等）や動的ロードを根絶。
  - Web Worker や WASM バイナリのロードが一切発生しないため、Edge / Chrome の厳格な `file://` セキュリティ環境下でも、ダブルクリックするだけで 100% エラーなく即座に起動・操作可能。
- **代替案（不採用理由）**:
  - _Quarto `{ojs}`_: Observable standard library が内部で jsdelivr / unpkg / observableusercontent を動的解決しようとし、外部通信やCORSエラーの原因となるため不採用。
  - _DuckDB-WASM_: 大規模SQLには有利だが、`.wasm` ファイルのロードが `file://` でブラウザにブロックされ、ダブルクリック運用の成立性を損なうため除外。

### 2. データペイロードと開示統制: 5例未満全集計値抑制

- **決定**: `src/python/sample_rwd_pipeline.py` で集約・小セル全集計値抑制（5例未満時は `n_patients`, `n_events`, `event_rate`, `mean_followup` 等の全メトリクスを `None` 化）されたJSONデータを生成し、`<script id="offline-cohort-data" type="application/json">` でHTML内にインライン埋め込み。
- **理由**: ブラウザの開発者ツールでDOMやソースコードを解析しても、5例未満のセルや平均観察期間などの派生統計、および患者識別子が存在しない状態を物理的に担保する。

### 3. 出力ディレクトリ統制

- **決定**: インタラクティブHTML報告書の出力先を `outputs/private/interactive_summary.html` に統一。共同研究者への配布時は `outputs/release/` へコピーし、`release-manifest.yml` による人手承認記録を義務付ける。`reports/quarto/` はソース（`.qmd`）のみ管理する。

### 4. 外部通信・セキュリティ監査の自動化と実ブラウザ検証

- **決定**:
  - `scripts/project/validate-project.py`: 生成されたHTML内の外部タグ、JS動的 `fetch()` / `import()` / Worker、既知CDNドメイン、患者識別子、および不適切な配置を網羅的に検出。
  - `tests/test_all_scenarios.py`: QuartoによるEnd-to-End生成、外部通信ゼロ検証に加え、Chrome DevTools Protocol (CDP) による実ブラウザ自動テストを実装。

## Risks / Trade-offs

- **[Risk 1: ブラウザセキュリティによる `file://` でのスクリプト実行拒否]**
  - → **Mitigation**: WASM/Worker/CDNに一切依存しない Pure Local インライン構造とすることで、`file://` の制約を根本的に排除。
- **[Risk 2: 集計データ生成時の小セル抑制漏れ]**
  - → **Mitigation**: 5例未満のセルに対してすべての集計列（`mean_followup` 含む）を `None` にマスキングするロジックを実装し、テストで検証。
- **[Risk 3: Quarto拡張機能による外部CDNリンクの自動混入]**
  - → **Mitigation**: `validate-project.py` でHTML内の全CDN・外部リソースタグ・通信関数をスキャンし、機械的にブロック。
