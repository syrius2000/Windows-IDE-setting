# ワークフロー（2パス方式）

このスキルはデータ特性に応じた最適な可視化を行うため、以下の2パス方式を採用しています。

```mermaid
sequenceDiagram
    participant AI as AI Agent (Reporting)
    participant R as analysis.R
    participant Out as skill_out/

    Note over AI,R: Pass 1: プロファイリング（軽量）
    AI->>R: analysis.R --profile
    R->>Out: data_profile.json
    Out->>AI: 次元数・水準数・セル数・疎密度を確認

    Note over AI: AI がデータ特性に基づき表示パラメータを決定
    Note over AI: 例: 水準集約・層選択・表示モード

    Note over AI,R: Pass 2: 本生成（パラメータ付き）
    AI->>R: analysis.R --render --config render_config.json
    R->>Out: JSON, CSV, gt HTML, DT HTML, PNG
    Out->>AI: 成果物読取

    Note over AI: AI 判断フェーズ
    AI->>AI: 第1段階 主効果残差の俯瞰
    AI->>AI: 第2段階 交互作用の洞察
    AI->>AI: 層別判断 前面配置する層を選択

    Note over AI: レポート構成
    AI->>Out: vcd_analysis_report.md 作成
```

## `render_config.json` の判断ガイド

AI は `data_profile.json` を読んだ後、以下の目安で `config` を構成します。

| 条件 | 対策 |
| :--- | :--- |
| `total_cells` > 200 | `collapse_below_n` または `max_levels_per_var` で水準を集約 |
| 水準数が多すぎる（>15等） | `max_levels_per_var: 10` などを設定 |
| 3-way の層が多い（>5等） | `strata_to_render` に特に重要な1〜3層のみを指定 |
| 疎密度（`sparsity_ratio`）が低い | セル数が多くても0が多いなら集約を強める |
