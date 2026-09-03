# AI 解釈（Cursor 二段レンダリング）

このスキルは本来「統計処理と図表の生成」を扱う。ここでは追加で、**Cursor デスクトップ上のエージェント**が解釈文（Markdown）を作り、**2回目のレンダリング**で HTML に差し込むための手順を示す。

## 前提

- リポジトリに **API キーを埋め込まない**
- R/Python から外部 LLM API を呼ぶ **バッチ処理は行わない**
- 解釈文は **エージェント（このチャットの AI）**が作る

## 手順（概要）

1. **1回目レンダリング（統計のみ）**  
   `templates/report.Rmd` を通常どおりレンダリングし、`skill_out/.../report.html` と `figures/`、`.metrics.rds` を生成する。

2. **エージェントが解釈 Markdown を作成**  
   生成物を見ながら、`skill_out/<slug>/ai_interpretation.md` を作る（例: `skill_out/vcd_categorical/ucb_admit_gender_dept/ai_interpretation.md`）。

3. **2回目レンダリング（解釈を差し込み）**  
   `params$ai_interpretation_path` に 2. で作った Markdown を指定して再レンダリングする。

## 解釈 Markdown に含めると良い構成（素人向け）

- **結論（1〜2行）**: 何が重要な示唆か
- **どこがズレたか（上位セル2〜3個）**: 期待より多い/少ないの説明
- **強さ（効果量）**: Cramér の V とラベル（small 等）
- **注意（1行）**: 層別（Dept）と周辺で結論が変わりうる等

## 解釈生成のプロンプト雛形（例）

以下をエージェントに渡す。

- 入力: `report.html` の Summary / Decision summary / Residual table / Residual plot / mosaic
- 出力: `ai_interpretation.md`（日本語、見出しは `##` から。1〜2画面で）

**指示例:**

「このレポートを統計に不慣れな人に説明する解釈文を Markdown で書いて。参照している残差のモデル（例: 2-way交互作用まで）を最初に明記し、上位のズレのセルを2〜3つ挙げて、正負の意味を添えて。」

