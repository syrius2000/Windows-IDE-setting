---
name: flat-file-mysql-load-validation
description: Use when generating final import SQL, specifying a database, executing SQL, or comparing loaded row counts for import steps 2-3.
license: MIT
metadata:
  author: flat-file-to-mysql-ddl-creator
  version: "1.0"
---

ステップ 2（完成版 SQL 生成）とステップ 3（指定 DB へ実行・件数比較）を担う。エージェントがプロンプトで完成版 SQL を生成し、ステップ 3 実行前にユーザーに確認し、依頼に応じて **Python CLI**（ステップ 3 用）を呼び出す。

## 実行前提

- 実行 cwd は **プロジェクトルート**。
- ステップ 2 の成果物は `./skill_out/step2_complete_sql` に保存する。
- ステップ 3 のレポートは `./skill_out/step3_report/run_<id>/step3_report.json` に保存する（`--report-dir` は親ディレクトリ、`--run-id` 未指定時は JST タイムスタンプで自動隔離）。

## 実行前の前提条件・注意・確認事項

- `mysql` コマンドが PATH にあることを確認する。
- DB 名が指定されていることを確認する（未指定なら停止）。
- Step 1 で不具合を見つけた場合は原因修正後に **Step 1 から再実行**し、続けて Step 2・Step 3 も再実行する。
- 再実行時は同一 `--report-dir` でも別 `run_<id>/` サブディレクトリに保存される（上書きしない）。明示的な run 名が必要な場合は `--run-id` を指定する。

## DB 名の扱い

- **検知**: Step 2 に進む前に、エージェントが DB 名の有無を確認する。未指定なら「DB名を明示してから実行してください」と表示し、**ステップ 2 の前でストップ**する。
- **渡し方**: ユーザーから受け取った DB 名を、ステップ 2 用プロンプトの `{{database_name}}` に渡して完成版 SQL を生成する。

## 手順（ステップ 2）

1. DB 名が指定されているか確認。未指定なら上記メッセージでストップ。
2. ステップ 1 の出力（サンプル SQL ファイル）と、保存されたプロンプト（`.agent/skills/flat-file-mysql-load-validation/prompts/step2-complete-sql.prompt.md`）を用い、`{{database_name}}` にユーザー指定の DB 名を渡して完成版インポート SQL を生成する。
3. 完成版 SQL を `./skill_out/step2_complete_sql` に保存する。複数 CSV の場合は CSV ごとに 1 本。

## ステップ 3 の実行前確認（問い合わせ）

- ステップ 2 まで完了したら、ステップ 3（件数比較）に進む**前に**、ユーザーに **「件数バリデーション（投入後の件数比較）を実施しますか？ はい／いいえ（スキップ）」** と必ず尋ねる。
- **解釈**: 「はい」「する」「実施する」等 → ステップ 3 を実行（step3_cli を呼ぶ）。「いいえ」「しない」「スキップ」「不要」等 → ステップ 2 で終了し、step3_cli は呼ばない。
- 大容量 CSV（例: 数 GB）では件数カウントに時間がかかるため、ユーザーがスキップを選べるようにする。

## 手順（ステップ 3）

1. 上記の問い合わせでユーザーが実施すると答えた場合のみ、エージェントが **Python CLI**（ステップ 3 用：SQL 実行・件数比較）を呼び出す。CLI に完成版 SQL のパスと対象 DB 接続情報を渡す。
   - `python3 .agent/skills/flat-file-mysql-load-validation/scripts/step3_cli.py <complete.sql> -d <database> --table <table> --expected-count <n> --report-dir ./skill_out/step3_report`
2. CLI が指定 DB に対して SQL を実行し、投入後の件数カウントと件数比較バリデーション（元件数・重複件数・投入件数）を行う。バリデーション完了＝ステップ 1 のユニーク数と DB レコード数が一致したとき。
3. レポート出力（`run_<id>/step3_report.json`）を確認し、成功/失敗をユーザーに報告する。

## 参照

- `scripts/step3_cli.py`
- `prompts/step2-complete-sql.prompt.md`
