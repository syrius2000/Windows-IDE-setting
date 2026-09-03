---
name: vcd-categorical-reporting
description: Use when consulting legacy categorical-analysis reporting templates; use vcd-categorical-analysis for new analyses.
license: MIT
metadata:
  author: vcd-categorical-reporting-skill
  version: "2.1"
  deprecated: true
  superseded_by: vcd-categorical-analysis
---

> [!WARNING]
> **非推奨**: 本スキルを単独の必須後続として使わない。`vcd-categorical-analysis` の Step 2 で `executive_summary.md`（必要なら `vcd_analysis_report.md`）を生成すること。以下は **report-template / evaluation-criteria 参照用** の履歴ドキュメント。

**IRON LAW**: `summary_*.json` と `data_profile_post.json` を読まずに、印象ベースで結論を書かない。必ず数値根拠（残差、有意セル数、層別指標）を併記する。

`vcd-categorical-analysis` が生成した統計成果物を AI が読み取り、**判断ファースト**形式のレポートを構成する。

## 前提スキル

- **先行**: `vcd-categorical-analysis` を先に実行し、成果物が存在すること（既定は `./skill_out/vcd_categorical/`。`--run-id` を使った場合は `./skill_out/vcd_categorical/runs/<id>/` を参照）。
- **契約**: `references/interface.md` を参照。

## 手順

### Pass 0: 分析の設計と文脈の把握
1. `analysis_config.json` が存在するか確認し、読み取る。
   - `input`: 元データのパス
   - `vars`: 分析の軸となった変数
   - `data_analysis_scope.md`: 分析の背景と意図
2. これらの情報を元に、単なる統計計算以上の「文脈に沿った考察」を準備する。

### Pass 1: データプロファイルの確認
...
1. `data_profile.json` を読み取る。
2. 次元数・水準数・疎密度を確認し、`render_config.json` を生成して `vcd-categorical-analysis` の Pass 2 を実行させる。
   - 水準数が多い場合（合計セル数 > 200）: `collapse_below_n` や `max_levels_per_var` の調整を検討
   - 3-way の場合: `strata_to_render` で注目すべき層を選択（全層を生成する場合は空配列）

### Pass 2 成果物の読み取りと判断

1. `summary_*.json` を読み取り、以下の2段階で思考すること：
   - **第1段階（全体構造の俯瞰）**: 主効果モデルの残差から、変数間の自明かつ強力な関連性を指摘
   - **第2段階（局所交互作用の洞察）**: 2-way モデルの残差から、単純な相関では説明できない特異な偏りを言語化
2. `strata_summary` を読み取り、**どの層の gt マトリックスを第2章に前面配置するか**を決定する。`max_abs_res_per_stratum` と `cramers_v_per_stratum` の値から統計的に最も注目すべき層を選ぶ。
3. `n_significant_cells_5pct` と `n_significant_cells_1pct` の比率を確認し、有意セルが多すぎる場合は注釈を付与する。

### レポート構成

`vcd_analysis_report.md` を以下の3章構成で Artifact として作成すること：

- **第1章：結論と所見** — サマリー文（1-2文）→ 箇条書き所見 → 推奨アクション（1-2文）
- **第2章：判断根拠** — モデル比較表、AI が選択した gt マトリックス、有意セル数
- **第3章：詳細データ** — DT テーブルへのリンク、全層別マトリックス、Mosaic/Assoc プロット

## 確認ゲート

- 章構成や口調を変更する前に、既定テンプレート（3章構成）を維持するか確認する。
- 先行スキル成果物が不足している場合、推測で補完せず不足ファイルを明示して再実行確認を取る。

> [!IMPORTANT]
> デザインは Mermaid シーケンス図による概況、`> [!NOTE]` / `> [!TIP]` バッジを活用し、ビジネスエグゼクティブにそのまま提示できる品質とすること。

## リソース

| パス | 役割 |
| :--- | :--- |
| `references/interface.md` | 共有契約（JSON/CSVスキーマ、命名規則） |
| `references/workflow.md` | 2パスシーケンス図 |
| `references/report-template.md` | 3章構成テンプレート |
| `references/evaluation-criteria.md` | AI判断基準（残差閾値、層別選択ロジック） |
