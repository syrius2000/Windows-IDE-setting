# AI Development & Architecture Memo (AI-memo.md)

本ドキュメントは、AI Agent（Google Antigravity / Cursor / Claude等）を用いた開発・保守運用における知見、メトリクス、およびアーキテクチャ上の重要決定事項を記録するメモです。

---

## 🤖 Antigravity セクション

### 1. オフライン対応インタラクティブQuarto解析環境の構築（2026-08-23）

#### 概要と課題
院内・閉域網（オフライン）環境において、臨床医や共同研究者がWebサーバー不要・ダブルクリック（`file://`）起動で閲覧・操作できる対話型解析レポート機能（Quarto）の標準化を実施。

#### 解決した技術的課題
1. **Zero-CDN / Zero-WASM アーキテクチャへの刷新**:
   - Quartoの `{ojs}` / Observable Runtime / DuckDB-WASM 内部による動的外部通信（jsdelivr, unpkg, observableusercontent 等 94〜152件）を完全撤廃。
   - インライン埋め込みJSON（`<script id="offline-cohort-data" type="application/json">`）＋ Pure Local JavaScript ＋ 動的SVGチャート ＋ DOM集計テーブルによる完全自己完結・外部通信ゼロのダッシュボードへ刷新。
2. **期間・治療群・性別の3軸動的フィルタリング**:
   - 観察期間（`<1年 (365日未満)` / `1年以上 (365日以上)`）、治療群（`Active` / `Control`）、性別（`男性` / `女性`）の3軸連動によるリアルタイム再集計・再描画を完備。
3. **厳格な開示統制（小セル全集計値抑制）**:
   - 5例未満（`<5`）のセルは、患者数・イベント数・発生率・平均観察期間（`mean_followup` 含む）の全集計メトリクス列を `None`（`— (<5抑制)`）に自動マスキング。
4. **出力先ディレクトリ統制**:
   - 中間集計JSONを `outputs/private/interactive_cohort_summary.json`、HTMLを `outputs/private/interactive_summary.html` に統一。
   - `reports/quarto/` はソースコード（`.qmd`）のみ管理し、生成成果物の誤コミットを完全防止。
5. **Headless Chrome / CDP による実機ブラウザ自動テスト**:
   - `pytest` スイート内で一時サンドボックス環境（`QUARTO_DATA_DIR` 等）および動的エフェメラルポート・待機ポーリング機構を実装。
   - `file://` 起動、初期描画（タイトル・10行テーブル・8本SVGバー・サマリーカード）、および動的フィルタ操作によるリアルタイム再描画を自動検証（25/25 PASS）。

---

### 2. エージェント開発サイクルと実行メトリクス（実測 ＆ 推定）

OpenSpecワークフロー（`add-offline-interactive-quarto-report`）を通じて実施された開発サイクルの実測値：

| 項目 | 実測値 / 推定値 | 備考 |
|:---|:---:|:---|
| ⏱️ **総所要時間** | **約 25 分** | 03:57 〜 04:22（JST） |
| 💬 **対話ターン数** | **11 ターン** | フィードバック・指示回数 |
| 🤖 **AIアクションステップ数** | **169 ステップ** | 思考（Chain-of-Thought）＋ツール呼び出し |
| 🛠️ **ツール実行総数** | **158 回** | コマンド（77）、ファイル参照（53）、編集（29） |
| 🪙 **累積入力トークン（Input）** | **約 4.2 M トークン** | 1ステップあたり平均 25k tokens |
| ✍️ **生成トークン（Output）** | **約 85 k トークン** | 思考・引数・回答文 |
| 🧪 **テスト合格率** | **100% (25/25)** | `pytest -q` |

---

### 3. クォータ・レートリミット（5時間枠・週間枠）の運用知見

AIモデルの利用枠を最大限に活かすための重要メカニズム：

- **二重制限の構造**:
  - **5-hour limit（5時間枠）**: 短時間のバーストアクセスを平滑化し、グローバルリソースを公平分配するための枠（時間経過で順次回復）。
  - **Weekly limit（週間枠）**: ユーザーの契約Tierに紐づく1週間あたりの総利用枠。
- **コスト比例（重み付き）消費**:
  - クォータは会話の「回数」ではなく「トークンの金銭的コスト」に比例して消費される。
  - 軽量・高速なモデル（Flash/Sonnet等）を通常の調査やコード編集に使い、大規模な推論やアーキテクチャ設計に上位モデル（Pro/Opus等）を組み合わせることで、クォータを最も長く維持できる。

---

### 関連ドキュメント（相対パス）
- [日常運用マニュアル](docs/daily-operations.md)
- [初心者向けチートシート](docs/beginner-cheatsheet.md)
- [メイン仕様書: interactive-offline-reporting](openspec/specs/interactive-offline-reporting/spec.md)
- [アーカイブされた変更計画](openspec/changes/archive/2026-08-23-add-offline-interactive-quarto-report/proposal.md)
