---
name: flat-file-mysql-ddl-generation
description: Use when converting CP932 CSV files into sample DDL SQL or record-count and duplicate reports for the first database-import step.
license: MIT
compatibility: Python 3 標準ライブラリのみ。仮想環境不要。
metadata:
  author: flat-file-to-mysql-ddl-creator
  version: "1.0"
---

CP932 の CSV を読み、エンコードを確認し、数行の DDL 用サンプル SQL を作成する。あわせて対象 CSV のレコード数・重複数をレポートする（複数 CSV 対応）。ステップ 1 用。重複数（duplicates）は重複している出現回数（余分な行の数）。ユニーク行数 = total − duplicates。レポートには unique（ユニーク件数）も含む。

## 実行前提

- 実行 cwd は **プロジェクトルート**。
- 出力先は `./skill_out/step1_sample_sql`（`-o/--out-dir` 未指定時の既定）。`<stem>Import.sql` は親ディレクトリ直下、`step1_report.json` は `run_<id>/` 配下（`--run-id` 未指定時は JST タイムスタンプで自動隔離）。
- エージェントがこの Skill に従い、次の CLI を呼び出す（Antigravity では .agent 配下を参照）。
  - `python3 .agent/skills/flat-file-mysql-ddl-generation/scripts/step1_cli.py <csv1> [csv2 ...] -o ./skill_out/step1_sample_sql`
- 入力: CSV ファイル（複数可）。エンコーディングは CP932 想定。標準ライブラリの TRY_ENCODINGS 方式で検証する。

## 実行前の前提条件・注意・確認事項

- CSV パスが存在することを確認する。
- 実行前に `./skill_out/step1_sample_sql` へ出力されることをユーザーに明示する。
- Step 1 で不具合を見つけた場合は原因修正後に **Step 1 から再実行**し、続けて Step 2・Step 3 も再実行する。
- 再実行時も SQL は stem 由来で上書きされるが、`step1_report.json` は別 `run_<id>/` に保存される。

## 手順

1. **エンコーディング検証**: CSV が CP932 として読めるか確認。失敗時はここで停止し、エラーを報告する。
2. **CLI 呼び出し**: 次のコマンドでステップ 1 用 CLI を実行する。
   - `python3 .agent/skills/flat-file-mysql-ddl-generation/scripts/step1_cli.py <csv1> [csv2 ...] -o ./skill_out/step1_sample_sql`
3. **成果物の確認**:
   - 各 CSV に対し、数行の DDL 用サンプル SQL ファイル（`*Import.sql`）が出力されていること。
   - レコード数・重複数レポート（`step1_report.json`）が出力されていること。
4. **次ステップ**: これらのサンプル SQL はステップ 2（完成版 SQL 生成）の入力として、保存プロンプトとともにエージェントに渡す。

## 参照

- `scripts/step1_cli.py`（当スキル配下）
