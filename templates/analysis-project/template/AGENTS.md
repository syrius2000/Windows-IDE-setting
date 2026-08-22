# Agent Context & Operational Guidelines

## Project Context
本プロジェクトは、阪大の統計専門家向けRWD（Real World Data）解析環境の個別解析案件リポジトリ（Case Project）です。

## 4大ディレクトリ配置原則
1. **`src/`**: 解析ソースコード
   - `src/sas-cp932/`: SASコード (CP932)
   - `src/python/`: Pythonコード (UTF-8, uv)
   - `src/r/`: Rコード (UTF-8, renv)
   - `src/typescript/`: TypeScriptコード (UTF-8, pnpm)
2. **`sql/`**: SQLクエリ・抽出スクリプト
3. **`reports/`**: 報告書（`quarto/`, `slidev/`, `office/`）
4. **`outputs/`**: 出力成果物
   - `outputs/private/`: 機微な中間集計・個票・ログ（Git完全除外）
   - `outputs/release/`: 人手承認済み公開成果物（`release-manifest.yml` 必須）

## AI Agent 行動原則
- 機微データや実患者レコードをクラウドLLMへ送信しないこと。
- SASコードはCP932、その他はUTF-8を厳守すること。
- 検証・テストには `data/synthetic/` の合成データを使用すること。
