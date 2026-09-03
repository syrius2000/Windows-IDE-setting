---
name: mysql-table-cardinality
description: Use when inspecting MySQL table structure, row counts, or per-column cardinality for a named database table or all tables.
license: MIT
metadata:
  author: mysql-table-cardinality-skill
  version: "1.0"
---

指定 DB・テーブルからカラム一覧、テーブル総行数、カラムごとの濃度数（COUNT(DISTINCT col)）を取得し、`./skill_out/mysql_table_cardinality` へ CSV と JSON を出力する。MCP (user-dbhub) が利用可能なら `execute_sql` を、利用できない場合は CLI を実行する。

## 実行前提

- 実行 cwd は **プロジェクトルート**。
- 出力先は `./skill_out/mysql_table_cardinality/run_<id>/`（`-o` は親ディレクトリ、`--run-id` 未指定時は JST タイムスタンプで自動隔離）。
- エージェントが本 Skill に従い、MCP または `scripts/get_cardinality_cli.py` を呼び出す。
- 正本は `.agent/skills/mysql-table-cardinality/` です。旧ミラーは廃止済みのため参照しません。

## 動作の流れ

1. 入力（DB 名・テーブル名）を受け取る
2. **MCP 利用可**: `execute_sql` で SQL を実行（先頭で `USE db;` を実行して DB 指定）
3. **MCP 利用不可**: `get_cardinality_cli.py` を実行（内部で `mysql` コマンド使用）
4. カラム取得 → 総行数取得 → 各カラム濃度数取得 → CSV/JSON 出力
5. **バグ修正済み**: `INFORMATION_SCHEMA` クエリ時にリテラル（シングルクォート）を正しく使用するように修正。

## 出力の場所

- `./skill_out/mysql_table_cardinality/run_<id>/<db>_<table>_columns_cardinality.csv` … カラム一覧＋濃度数
- `./skill_out/mysql_table_cardinality/run_<id>/<db>_<table>_report.json` … database, table, total_rows, columns_count, timestamp

## 覚えておくこと

1. **`-t` は必須**。全テーブルは `-t '*'` で明示
2. 全テーブル時は **事前に「全○テーブルを処理します。続行しますか？」とユーザーに確認**する
3. **VIEW は対象外**（BASE TABLE のみ）
4. 大テーブルでは **COUNT が重い**ため注意
5. 認証は **.env（chmod 600）または ~/.my.cnf** を推奨。`.env` は `.gitignore` に含め、コミットしない

## 入力

- **database**（必須）: DB 名
- **table**（必須）: テーブル名。全テーブルは `*`

## 実行前の確認

- `.env` または ~/.my.cnf に認証情報が設定されているか確認する
- `mysql` コマンドが PATH にあることを確認する（CLI 利用時）
- 出力先ディレクトリ (`./skill_out`) への書き込み権限があることを確認する
- 全テーブル指定時はユーザーに確認を取る

## 手順（MCP 優先）

1. MCP user-dbhub の `execute_sql` が利用可能か確認する
2. **MCP 利用可**:
   - SQL の先頭で `USE db;` を実行して DB を指定
   - カラム取得: `SELECT COLUMN_NAME, ORDINAL_POSITION, DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='db' AND TABLE_NAME='table' ORDER BY ORDINAL_POSITION`
   - 総行数: `SELECT COUNT(*) FROM \`db\`.\`table\``
   - 各カラム濃度数: `SELECT COUNT(DISTINCT \`col\`) FROM \`db\`.\`table\``
   - 識別子はバッククォートでエスケープ（` 内の ` は `` に二重化）
   - 取得結果を CSV/JSON 形式で `./skill_out/mysql_table_cardinality/` に出力する
3. **MCP 利用不可**: CLI を呼び出す
   - `.agent`: `python3 .agent/skills/mysql-table-cardinality/scripts/get_cardinality_cli.py -d <db> -t <table> -o ./skill_out/mysql_table_cardinality`
   - 全テーブル: `-t '*'`

## コマンド例

単一テーブル:
```
python3 .agent/skills/mysql-table-cardinality/scripts/get_cardinality_cli.py -d mydb -t mytable -o ./skill_out/mysql_table_cardinality
```

全テーブル（事前にユーザー確認）:
```
python3 .agent/skills/mysql-table-cardinality/scripts/get_cardinality_cli.py -d mydb -t '*' -o ./skill_out/mysql_table_cardinality
```

## 参照

- `scripts/get_cardinality_cli.py`

## 次のステップ: Query 作成支援

DB構造、テーブル分布、ID所在を確認した後、分析目的に応じた SQL を作る場合は `mysql-create-query-support` を使う。
この支援では、自然文の問いを粒度・JOIN・期間・検証観点に分解し、`sql/drafts/<topic>/main_query.sql`、`validation_query.sql`、`query_note.md` を作成する。
