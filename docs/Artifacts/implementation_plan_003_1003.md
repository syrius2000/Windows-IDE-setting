# OpenSpec初期化スクリプトと回帰確認の修正計画

created: 2026-10-03 05:53 (JST)
update: 2026-10-03 05:53 (JST)
author: Codex (GPT-6)

## 目的

コミット`5bc1fab`のレビューで確認した、Windows PowerShell 5.1向け文字コード、OpenSpecのCursor専用・日本語初期化指定、自動テストの期待値不一致を修正する。

## 対象範囲

1. `scripts/project/setup-openspec.ps1`をUTF-8 BOM付きで保存し、Windows PowerShell 5.1で日本語文字列を含むスクリプトとして読める状態にする。
2. OpenSpec初期化コマンドへCursorのみを指定するオプションと日本語指定（`--tools cursor --language ja`）を渡し、対話的なツール選択に依存しないようにする。
3. `tests/test_openspec_case_project_bootstrap.py`のnpm/npx検証期待値を、`05-verify.ps1`の名前付き引数形式に合わせる。Cursorおよび日本語の初期化指定も回帰検査対象に加える。
4. 必要な範囲でOpenSpec Changeの設計・仕様・タスク記述を実装と一致させる。今回の単体修正に関係する項目のみ扱う。

## 対象外

- Windows 11実機での成功・失敗シナリオ、総合テスト、実機結果の記録（OpenSpec tasks 6.1〜6.3）。利用者が後日実施して結果を報告する。
- OpenSpecネットワーク失敗・再実行等の未完了統合シナリオ（tasks 3.4）。
- 他のPowerShellファイルの文字コード変更、既存機能の整理、OpenSpec Changeのarchive。
- commitおよびpush。

## 実施・確認方法

- 変更開始前後にGit差分を確認し、現在の作業ツリーがcleanであることを基準状態として扱う。
- スクリプトの先頭バイトがUTF-8 BOMであること、初期化コマンドの引数がCursorおよび日本語を指定すること、テスト期待値が実コードと一致することを静的に確認する。
- 利用者からテスト実行も依頼された場合を除き、自動テストやWindows実機テストは実行しない。
- `openspec/changes/add-openspec-case-project-bootstrap/tasks.md`の6.1〜6.3は未完了のまま維持する。

## リスクと判断事項

- `--language ja`の対応状況は、固定対象のOpenSpec CLI v1.7.0の仕様に合わせて実装前に確認する。未対応なら、バージョンを勝手に変更せず、その制約を仕様・計画へ記録して別途判断を求める。
- OpenSpec初期化オプションを固定すると、他のエージェント設定は生成されなくなる。これはCursorのみを対象とする既定方針に沿う。
- Windows PowerShell 5.1上での最終動作確認は、本計画では未実施であり、利用者の実機結果を待つ。

## 承認境界

本計画の承認後に限り、記載したスクリプト、テスト、OpenSpec関連Artifactを変更する。対象範囲や実装方式を広げる場合は本計画を更新し、再承認を得る。
