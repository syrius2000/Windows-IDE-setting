# 初学者向け Git 基本ワークフロー

この文書は、GitHubアカウントを持たない統計・RWD初心者が、まずPC内だけで安全にGitを使い始め、必要になった段階でGitHubなどの共有先へ移行するための手引きです。

## 1. まず覚える言葉

| 用語 | 意味 |
| --- | --- |
| `commit` | PC内のリポジトリに変更履歴を保存すること。GitHubへの送信ではありません。 |
| `WIP` | Work In Progress。まだ作業途中であることを示す一時的な保存です。 |
| `squash` | 複数の小さな履歴を、意味のまとまった1つの履歴に整理することです。 |
| `push` | ローカルのcommitをGitHubなどの共有先へ送信することです。 |
| `pull` | 共有先の最新変更をローカルへ取り込むことです。 |

GitHubアカウントがない間は、`commit`までを使います。`push`と`pull`は、GitHubなどの共有先を設定した後に使います。

## 2. GitHubなしで始めるローカル運用

初回コミットには `git config --global user.name` / `user.email` が必要です。未設定だと Case 作成時の Initial commit がスキップされます（[bootstrap FAQ Q6](windows-bootstrap-guide.md#q6-case-project-はできたがinitial-git-commitがスキップされる) / [Troubleshoot §10](windows-troubleshooting.md#10-git-身元未設定で初回コミットがスキップされる)）。

Case Projectを作成して`Y`を選ぶと、プロジェクト内にローカルGitリポジトリが作られます。以後、Cursorのターミナルで次を確認します。
```powershell
git status
git log --oneline -5
```

最初の変更を保存する基本形は次のとおりです。

```powershell
git add src reports
git status
git commit -m "解析手順を追加"
git status
```

`git status`で意図したファイルだけが対象になっていることを確認してからcommitします。実データ、パスワード、APIキー、`outputs/private/`の個票や機微な中間データはcommitしません。

## 3. 日常の基本順序

### 3.1 共有先がある場合の標準フロー

共同研究者とGitHubリポジトリを共有している場合は、通常次の順序で進めます。

```text
pull → 作業 → status確認 → commit → push
```

実際のコマンド例です。

```powershell
# 1. 共有先の最新変更を取り込む
git pull --ff-only

# 2. Cursorで解析コード・報告書を編集し、合成データで検証する

# 3. 変更内容を確認する
git status
git diff -- src reports

# 4. 意図したファイルだけをcommitする
git add src reports
git commit -m "生存時間解析レポートを更新"

# 5. 共有先へ送信する
git push
```

`git pull --ff-only`が失敗した場合は、勝手に解決せず、表示された差分を確認します。わからない場合は、作業を止めて共同研究者または管理者に相談してください。

### 3.2 作業途中をWIPとして保存する場合

長い解析や報告書編集では、途中経過を保存しておくとPC障害や操作ミスから戻りやすくなります。

```powershell
git add src/python/sample_rwd_pipeline.py
git commit -m "WIP: 生存時間解析の途中経過"
```

WIP commitは「完成版」ではありません。共有先へpushする前に、必要なら履歴を整理します。ローカルだけで作業している場合は、WIPのまま保存しても問題ありません。

## 4. WIP履歴をsquashする

WIP commitが3つあり、最後に1つの意味のあるcommitへまとめたい場合の例です。

```powershell
git log --oneline -5
git rebase -i HEAD~3
```

エディタが開いたら、最初のcommitを`pick`として残し、後続のcommitを`squash`または`s`に変更して保存します。その後、まとまったcommitメッセージに直します。

```text
pick   1111111 解析用データの読み込みを追加
s      2222222 WIP: 欠測処理を追加
s      3333333 WIP: グラフを調整
```

履歴を書き換える操作です。すでに他の人が取得したcommitをsquashしないでください。共有済みの履歴を変更する必要がある場合は、先に関係者へ確認します。

## 5. GitHubを後から使い始める場合

GitHubアカウントを作成しただけでは、ローカルリポジトリとの接続は完了しません。組織のルールに従って、次の準備を行います。

1. GitHubアカウントを作成し、二要素認証を設定する。
2. GitHub上で空のリポジトリを作成する。
3. 学内・研究室の公開範囲、Private設定、共同研究者の権限を確認する。
4. ローカルリポジトリに共有先を登録する。

```powershell
git remote add origin https://github.com/組織名/リポジトリ名.git
git remote -v
git push -u origin main
```

医療・RWDプロジェクトでは、GitHubへ実データを送信しないでください。GitHubにはコード、設定例、合成データ、レビュー可能な公開成果物だけを置き、実データは保護領域に残します。

## 6. 困ったときの安全な停止方法

次の状態では、追加操作をせず画面を保存して相談します。

- `git pull`で競合が発生した
- どのファイルをcommitしてよいかわからない
- `git push`で認証や権限のエラーが出た
- 実データや秘密情報をcommitした可能性がある
- `rebase`や`squash`の途中で操作がわからなくなった

特に、実データやパスワードをcommitした可能性がある場合は、単にファイルを削除してcommitするだけでは不十分です。作業を止め、管理者にインシデントとして報告してください。

## 7. 最小チェックリスト

- [ ] 今日の作業開始時に`git status`を確認した
- [ ] 合成データまたは承認済みデータで検証した
- [ ] commit前に対象ファイルを確認した
- [ ] 実データ・個人情報・秘密情報を含めていない
- [ ] GitHubを使わない場合は`commit`までで完了した
- [ ] GitHubを使う場合は`pull → 作業 → commit → push`の順序を守った

