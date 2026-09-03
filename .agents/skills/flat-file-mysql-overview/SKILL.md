---
name: flat-file-mysql-overview
description: Use when planning or explaining the three-step workflow for loading CP932 CSV files into MySQL, including choosing the DDL and validation skills.
license: MIT
metadata:
  author: flat-file-to-mysql-ddl-creator
  version: "1.0"
---

CP932 の CSV を MySQL 8.0 に投入するまでの 3 ステップの流れと、各ステップで利用する Skill の概要。

## 実行前提・注意

- 実行 cwd は **プロジェクトルート**。
- 出力は `./skill_out` 配下のサブディレクトリで管理する（各ステップの成果物は `run_<id>/` に隔離）。
  - `./skill_out/step1_sample_sql`（`step1_report.json` は `run_<id>/` 配下）
  - `./skill_out/step2_complete_sql`
  - `./skill_out/step3_report`（`step3_report.json` は `run_<id>/` 配下）
- 実行前に前提条件（DB 名、mysql コマンド可用性、対象 CSV）をユーザーに示して確認する。
- Step 1 で不具合を見つけた場合は Step 1 から再実行し、Step 2・Step 3 も再実行する。
- 再実行時もレポート類は別 `run_<id>/` に保存される（`--run-id` 未指定時は JST タイムスタンプ）。SQL ファイル（step1 の `<stem>Import.sql`）は stem 由来で上書きされる。
- 大容量 CSV では件数バリデーション（ステップ 3）をスキップできる。エージェントが確認する。

## フロー概要

```
ステップ 1: サンプル SQL + レポート  →  ステップ 2: 完成版 SQL（DB 名指定）  →  ステップ 3: 対象 DB へ実行
        Skill B + CLI                       エージェント + プロンプト                  Skill C + CLI
```

1. **ステップ 1**: CSV を読み、エンコードを確認し、数行の DDL 用サンプル SQL を作成。レコード数・重複数・ユニーク数をレポート（total / duplicates / unique。複数 CSV 対応）。**Skill B**（flat-file-mysql-ddl-generation）に従い、`python3 .agent/skills/flat-file-mysql-ddl-generation/scripts/step1_cli.py ... -o ./skill_out/step1_sample_sql` を実行する。
2. **ステップ 2**: ステップ 1 の出力と保存プロンプト（`{{database_name}}` 指定可能）に従い、完成版インポート SQL を生成。**DB 名が未指定の場合はここでストップ**し、「DB名を明示してから実行してください」と表示。完成版 SQL は `./skill_out/step2_complete_sql` に保存する。
3. **ステップ 3**: 完成した SQL を指定した対象 DB へ実行。ステップ 3 は任意。エージェントが件数バリデーションの実施有無をユーザーに確認し、『はい』の場合のみ **Skill C**（flat-file-mysql-load-validation）に従い `python3 .agent/skills/flat-file-mysql-load-validation/scripts/step3_cli.py ... --report-dir ./skill_out/step3_report` を実行し、`run_<id>/step3_report.json` を出力する。

## 関連 Skill

| Skill | 役割 |
|-------|------|
| flat-file-mysql-ddl-generation | ステップ 1: サンプル SQL 生成＋レポート（CLI 呼び出し） |
| flat-file-mysql-load-validation | ステップ 2 の DB 名確認・完成版 SQL 生成、ステップ 3: 投入・件数比較（CLI 呼び出し） |

## プロンプト

- ステップ 2 用: `.agent/skills/flat-file-mysql-load-validation/prompts/step2-complete-sql.prompt.md`（DB 名は `{{database_name}}`）

## 次のステップ: Query 作成支援

DB構築後に分析目的に応じた SQL を作る場合は `mysql-create-query-support` を使う。
この支援では、自然文の問いを粒度・JOIN・期間・検証観点に分解し、`sql/drafts/<topic>/main_query.sql`、`validation_query.sql`、`query_note.md` を作成する。
