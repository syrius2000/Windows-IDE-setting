---
name: mysql-create-query-support
description: Use when translating a natural-language analysis request into MySQL/MariaDB exploration, production, validation, or dataset-extraction SQL.
license: MIT
metadata:
  author: rwd-mysql-skill-toolkit
  version: "1.0"
---

# MySQL Create Query Support

自然文の分析目的を、実行可能で検証可能な SQL に分解するためのスキル。

## 目的

若手エンジニアが「望む Query」を作れるように、いきなり完成 SQL を出すのではなく、問いを分解し、探索 SQL、検証 SQL、本 SQL、分析用抽出 SQL の順に進める。

## 入力

- 分析目的または自然文の問い
- 対象 DB 名
- 主要 ID 列。既定は `PATIENTNO`
- 期間条件。未指定なら「期間未指定」と明記する
- アウトカム、曝露、イベント、属性、除外条件
- 既存成果物。利用できる場合は ER 図、dictionary CSV、cardinality 結果、entity matrix 結果

## スキーマ確認方針

- AI は SQL または利用可能な MCP で Table Schema を確認し、テーブル・カラム一覧を把握してから SQL を設計する。
- ER 図、dictionary CSV、cardinality 結果、entity matrix 結果がある場合は、それらを優先的に参照し、SQL に必要なテーブル・カラム・JOIN キー候補を特定する。
- 既存成果物がない場合は、`SHOW TABLES`、`DESCRIBE <table>`、または `INFORMATION_SCHEMA.COLUMNS` を使って、テーブルとカラムを確認する方法を提示する。
- テーブル数が多い、JOIN キーが不明、カテゴリ値や日付カラムが不明な場合は、先に `mysql-er-diagram`、`mysql-table-cardinality`、`mysql-entity-matrix` の利用を勧める。
- スキーマ確認なしに本 SQL を作らない。最初に探索 SQL と検証 SQL を作る。

## 出力

原則として repo root の `sql/` 配下に保存する。

| 出力 | 保存先 | 目的 |
|---|---|---|
| 本 SQL | `sql/drafts/<topic>/main_query.sql` | 目的に対する主クエリ |
| 検証 SQL | `sql/drafts/<topic>/validation_query.sql` | 件数、NULL、重複、期間、カテゴリ値を確認 |
| ノート | `sql/drafts/<topic>/query_note.md` | 目的、粒度、JOIN 根拠、未確認リスクを記録 |

検証済みになった SQL は、ユーザー確認後に `sql/validated/<topic>/` へ移す。

## 必須ワークフロー

1. 目的を分解する: 誰を、何を、いつからいつまで、何で判定するかを明文化する。
2. 粒度を決める: 患者単位、受診単位、処方単位、検査単位、イベント単位のどれかを明記する。
3. スキーマを確認する: 既存成果物、MCP、SQL の順に利用可能な情報を確認し、テーブル・カラム一覧を把握する。
4. 候補テーブルを挙げる: ER 図、dictionary、cardinality、entity matrix を参照する。
5. JOIN 方針を説明する: ID、日付、コード、施設、イベント番号など、結合根拠を明記する。
6. 探索 SQL を作る: テーブル件数、カラム値、日付範囲、コード値を確認する。
7. 本 SQL を作る: 抽出条件にはコメントを付ける。
8. 検証 SQL を作る: `COUNT(*)`、`COUNT(DISTINCT id)`、NULL、重複、期間範囲、カテゴリ値を確認する。
9. 分析系へ渡す: 出力データセットの単位と制約を `query_note.md` に残す。

## SQL 作成原則

- `SELECT *` は探索初期以外では使わない。
- JOIN 前後で `COUNT(*)` と `COUNT(DISTINCT PATIENTNO)` を比較する。
- WHERE 条件は意図が分かるコメントを付ける。
- 日付条件は閉区間・半開区間を明記する。
- コード値は直接固定せず、候補値確認 SQL を先に作る。
- 分析用データセットは一行の単位を先頭コメントに書く。

## テンプレート

- `templates/main_query.sql`
- `templates/validation_query.sql`
- `templates/query_note.md`
- `references/query_design_checklist.md`
