# 文書整合性修復・実行プラン（Win11 初回検証後）

created: 2026-08-27 00:03 (JST)
update: 2026-08-27 00:20 (JST)
author: Cursor Agent (Composer)
status: implemented
source: ドキュメント整合性洗い出し（README / AGENTS / bootstrap / troubleshooting / cheatsheet / daily-ops / software-matrix）

## 1. 目的

Win11 初回実機検証あとに残っている **ユーザー向け文書の食い違い・リンク切れ・存在しないコマンド** を解消し、セットアップ〜日常運用の導線が現実のスクリプト／テンプレートと一致するようにする。

合格基準（検証の exit code 厳格化など）は緩めない。今回は主に **文書とテンプレの同期** であり、セットアップ本体の再設計は対象外とする。

## 2. 背景（現状サマリー）

### すでに整合しているもの

- WinGet ID `Posit.rig`（install としての `RProject.rig` なし）
- `Setup-Windows.bat` → `scripts/windows/Setup-WindowsEnvironment.ps1`
- SAS 任意のメッセージ
- Case 作成の python / r / sas パターン
- `docs/windows-troubleshooting.md` ↔ `docs/windows-bootstrap-guide.md`

### 要修復（洗い出し結果）

| 優先度 | 論点 |
|--------|------|
| Critical | `pnpm report:pptx` が docs にあるがテンプレ `package.json` に無い |
| Critical | README「その他は UTF-8」と AGENTS の PowerShell BOM 例外が衝突 |
| Medium | Case 生成先・実行 cwd・Git 身元の記載不足 |
| Medium | Setup 完了バナーの Case 例と README の言語パターン不一致 |
| Medium | software-matrix の Gitleaks「必須」vs Setup 未導入、SAS 行欠落 |
| Medium | LICENSE リンク切れ、ドキュメント一覧の欠落リンク |
| Minor | README 一覧途中の BOM 検査割り込み、用語 BOM 混同、相互リンク不足 |

## 3. 対象範囲

### 3.1 変更する文書・テンプレ

- [`README.md`](../../README.md)
- [`docs/beginner-cheatsheet.md`](../beginner-cheatsheet.md)
- [`docs/daily-operations.md`](../daily-operations.md)
- [`docs/windows-bootstrap-guide.md`](../windows-bootstrap-guide.md)
- [`docs/windows-troubleshooting.md`](../windows-troubleshooting.md)（必要なら短文追記のみ）
- [`docs/software-matrix.md`](../software-matrix.md)
- [`docs/sas-cp932.md`](../sas-cp932.md)（BOM 例外の脚注）
- [`docs/git-basic-workflow.md`](../git-basic-workflow.md)（Git 身元の短い案内）
- [`templates/analysis-project/template/package.json.jinja`](../../templates/analysis-project/template/package.json.jinja)
- [`scripts/windows/Setup-WindowsEnvironment.ps1`](../../scripts/windows/Setup-WindowsEnvironment.ps1)（完了バナーの Case 例のみ）

### 3.2 変更しないもの

- WinGet / インストール本体ロジックの再設計
- `05-verify.ps1` の合格基準緩和
- OpenSpec 仕様の全面改訂（必要なら別 change）
- GitHub への push（本プラン実行後、別途ユーザー承認で実施）

## 4. 実行方針

1. **Critical を先に閉じる**（壊れたコマンド・文字コード例外）。
2. **Medium は短文追記で揃える**（長文化しない）。
3. テンプレに script を足す場合は、docs のコマンドと **完全一致** させる。
4. 相対パスリンクを維持する（`AGENTS.md` ルール）。
5. Windows 用 `.ps1` を触る場合は UTF-8 BOM を保持し、`Assert-Utf8Bom.ps1` を通す。

## 5. タスク分解

### Phase A — Critical

#### A1. `pnpm report:pptx` の同期

- **方針（採用）**: テンプレ `package.json.jinja` に script を追加し、docs の記載をそのまま使えるようにする。
- 追加例:

```json
"report:pptx": "ts-node src/typescript/sample_report.ts"
```

- [`docs/beginner-cheatsheet.md`](../beginner-cheatsheet.md) / [`docs/daily-operations.md`](../daily-operations.md) のコマンドはそのまま維持できることを確認する。
- `sample_report.ts` の実行前提（依存・出力先）が README/チートシートの説明と矛盾しないか確認する。

#### A2. README / sas-cp932 に PowerShell BOM 例外を追記

- [`README.md`](../../README.md) ガバナンス「文字コード厳守」に、AGENTS と同趣旨で次を追記する:
  - Case Project 内の Python/R/TS/Markdown は UTF-8（BOMなし）
  - プラットフォームの `scripts/windows/*.ps1`・`scripts/project/*.ps1`・`Setup-Windows.bat` は UTF-8（BOMあり）
- BOM 検査コマンドはドキュメント一覧の途中から外し、「開発者向け（macOS 編集時）」小節へ移す。
- [`docs/sas-cp932.md`](../sas-cp932.md) に「プラットフォーム Windows スクリプトは BOM 例外」を1行脚注する。

### Phase B — Medium（導線）

#### B1. Case 生成先・実行 cwd

次の文書の Case 作成節に共通文を追加する:

- 実行場所: **プラットフォームリポジトリのルート**
- 既定生成先: `%USERPROFILE%\Programing\RWD-Projects\<Name>`（変更は `-DestinationRoot`）

対象: README、`windows-bootstrap-guide.md`、`beginner-cheatsheet.md`

#### B2. Git 身元（user.name / email）

- `beginner-cheatsheet.md`、`git-basic-workflow.md`、README の Case 作成節に、bootstrap Q6 / troubleshooting §10 への短いリンクを追加する。
- 「未設定だと Initial commit がスキップされる」を1文で示す。

#### B3. Setup 完了バナーと README の Case 例を揃える

- [`Setup-WindowsEnvironment.ps1`](../../scripts/windows/Setup-WindowsEnvironment.ps1) の「次のステップ」を、README のパターン A/B/C（`-PrimaryLanguage`）に合わせる。
- ファイル保存後に UTF-8 BOM を再確認する。

#### B4. software-matrix を実態に合わせる

- Gitleaks: **必須 → 推奨（任意）**（Setup 未導入のため）。文言で「手動導入可」と明記。
- SAS Foundation 9.4 行を追加: **任意・手動・セットアップ対象外**。
- タイトルの「BOM」混同を避けるため、見出しを「ソフトウェア構成表（Software Bill of Materials）」のまま維持しつつ、冒頭に「ここでの BOM は構成表の意味であり、UTF-8 の Byte Order Mark ではない」と1文注記する。

#### B5. LICENSE・ドキュメント一覧

- **方針（採用）**: ルートに簡易 `LICENSE`（MIT）を追加し、README バッジを有効化する。  
  （リポジトリ方針が MIT バッジ前提のため。内容は標準 MIT 文面。）
- README ドキュメント一覧に次を追加:
  - `docs/git-basic-workflow.md`
  - `docs/ai-prompt-recipes.md`
- bootstrap 末尾に `software-matrix.md` へのリンクを追加。
- cheatsheet から `windows-troubleshooting.md` へのリンクを追加。

### Phase C — Minor（任意だが同時実施推奨）

- bootstrap の「GitHub から ZIP」を「配布 ZIP／学内共有で可。GitHub アカウント不要」に言い換える。
- AGENTS.md の相対リンク例を実ファイル例（`[手順](docs/windows-bootstrap-guide.md)`）に差し替え可能なら実施。

## 6. 検証手順

1. 相対リンク先ファイルの存在確認（README / bootstrap / cheatsheet / daily-ops）。
2. テンプレ生成または `package.json.jinja` 上で `report:pptx` キーが存在することを確認。
3. `rg "pnpm report:pptx"` と `package.json.jinja` の突合。
4. `rg "その他はUTF-8"` / BOM 例外の記載が README・AGENTS で矛盾しないこと。
5. `rg "Gitleaks"` で必須/推奨の表記が実態と一致すること。
6. Windows スクリプトを変更した場合: `Assert-Utf8Bom.ps1` PASS。
7. （任意）既存 Case テンプレから `pnpm report:pptx --help` 相当が解決するかの目視。

## 7. 完了条件

- Critical 2件が解消されている。
- Medium（生成先/cwd、Git 身元、バナー、matrix、LICENSE、一覧リンク）が文書上揃っている。
- ユーザーが README → bootstrap → cheatsheet → daily-ops の順で読んでも、存在しないコマンドや矛盾した文字コード規則にぶつからない。

## 8. 成果物チェックリスト

- [x] A1 `report:pptx` script 追加＋docs 突合
- [x] A2 README / sas-cp932 の BOM 例外
- [x] B1 生成先・cwd 追記
- [x] B2 Git 身元リンク
- [x] B3 Setup 完了バナー更新（BOM 維持）
- [x] B4 software-matrix（Gitleaks 推奨化、SAS 行、BOM 注記）
- [x] B5 LICENSE 追加＋ドキュメント一覧拡充＋相互リンク
- [x] C Minor 言い換え（実施した場合）
- [x] 検証手順 1–6 実施記録（2026-08-27: リンク存在・report:pptx 突合・BOM例外整合・Gitleaks推奨・Assert-Utf8Bom PASS）

## 9. 実装時の注意

- コミット／Push はユーザー承認後。
- `docs/Archives/` や `openspec/archive/` の過去文書は原則触らない（現行導線のみ）。
- 本プラン自体の更新が必要になったら、このファイルの `update` 日付とチェックリストを更新する。
