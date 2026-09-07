# Windows 11 OpenSpec初期化スモークテスト手順書

created: 2026-08-24 22:00 (JST)
update: 2026-08-24 22:00 (JST)
author: Codex (GPT-5)

この手順書は、Windows 11実機でCase Project生成時のOpenSpec初期化を確認するためのものです。

初学者向けの確認ですので、実患者データは使用しません。すべて合成データとテスト用フォルダで実施してください。

## 1. テスト前の準備

次を確認してください。

- Windows 11の管理者権限がある
- Cursor本体を事前に手動インストール済みである
- Cursor Proへのログイン認証が完了している
- インターネットに接続できる
- SASがなくてもテスト可能。今回はPython中心で確認する
- 本リポジトリの最新ファイルをWindows 11へコピー済みである

GitHubから取得できない場合は、Mac側のリポジトリフォルダをZIPにしてUSB等でコピーしても構いません。

> 注意：このテスト中は、GitHubへのPush、実データの配置、MySQLへの接続を行いません。

## 2. リポジトリを開く

1. リポジトリを、例えば次の場所へ展開します。

   ```text
   C:\Users\<ユーザー名>\Desktop\Windows-IDE-setting
   ```

2. PowerShellを開きます。
3. リポジトリのルートへ移動します。

   ```powershell
   cd "$env:USERPROFILE\Desktop\Windows-IDE-setting"
   ```

4. 現在地を確認します。

   ```powershell
   Get-Location
   Test-Path .\Setup-Windows.bat
   ```

`True`が表示されれば、正しいリポジトリルートです。

## 3. Node.js・npm・npxを確認する

まず、次を実行します。

```powershell
node --version
npm --version
npx --version
```

3つともバージョン番号が表示されれば合格です。

### 表示されない場合

リポジトリルートで、次を実行します。

```powershell
.\scripts\windows\03-install-reporting.ps1
```

完了後、PowerShellを一度閉じて開き直し、もう一度バージョン確認を行います。

## 4. Windows環境セットアップを確認する

初回導入を確認する場合は、次の方法を使います。

1. `Setup-Windows.bat`を右クリックします。
2. **「管理者として実行」**を選択します。
3. 画面の指示に従い、処理が完了するまで待ちます。

PowerShellから実行する場合は次のとおりです。

```powershell
.\scripts\windows\Setup-WindowsEnvironment.ps1
```

完了後、次のコマンドでNode.js/npm/npxを再確認します。

```powershell
node --version
npm --version
npx --version
```

## 5. Case Projectを作成する（成功シナリオ）

既存の解析フォルダを汚さないよう、デスクトップ上にテスト用Projectを作成します。

```powershell
$testProject = "$env:USERPROFILE\Desktop\case-openspec-smoke"

.\scripts\project\New-AnalysisProject.ps1 `
  -Name "case-openspec-smoke" `
  -DestinationPath $testProject `
  -DataClassification "synthetic" `
  -PrimaryLanguage "python" `
  -NonInteractive
```

### 成功時の確認

次を順番に実行します。

```powershell
Test-Path "$testProject\PROJECT.yml"
Test-Path "$testProject\openspec"
Test-Path "$testProject\AI_FRAMEWORK_STATUS.yml"
Test-Path "$testProject\scripts\setup-openspec.ps1"
Get-Content "$testProject\AI_FRAMEWORK_STATUS.yml"
```

次の結果になれば成功です。

```text
PROJECT.yml                 True
openspec                    True
AI_FRAMEWORK_STATUS.yml     True
setup-openspec.ps1          True
```

`AI_FRAMEWORK_STATUS.yml`の中に、次のような記録があればOpenSpec初期化成功です。

```yaml
openspec:
  status: 'success'
```

## 6. OpenSpecの最低限の利用確認

生成されたProjectへ移動します。

```powershell
cd $testProject
Get-ChildItem .\openspec
Get-Content .\README.md
```

ここでは、Change Artifactを自動生成していないことを確認します。OpenSpecは初期化済みですが、実際の`proposal.md`等は利用者が最初のテーマを入力した後に作成する設計です。

## 7. スキップ・再実行シナリオ

### 7.1 明示的にスキップする

```powershell
.\scripts\setup-openspec.ps1 -ProjectRoot $testProject -Skip
Get-Content "$testProject\AI_FRAMEWORK_STATUS.yml"
```

次の記録になれば成功です。

```yaml
openspec:
  status: 'skipped'
```

### 7.2 再実行する

```powershell
.\scripts\setup-openspec.ps1 -ProjectRoot $testProject -NonInteractive
Get-Content "$testProject\AI_FRAMEWORK_STATUS.yml"
```

初期化前に既存の`openspec/`がバックアップされ、次のようなフォルダが作成されれば成功です。

```powershell
Get-ChildItem "$testProject\.ai-backup" -Recurse
```

### 7.3 バックアップ対象の確認

テスト用のファイルをOpenSpec配下に作成してから再実行します。

```powershell
New-Item -ItemType Directory -Path "$testProject\openspec" -Force | Out-Null
Set-Content -Path "$testProject\openspec\smoke-test.txt" -Value "backup-test" -Encoding utf8
.\scripts\setup-openspec.ps1 -ProjectRoot $testProject -Skip
Get-ChildItem "$testProject\.ai-backup" -Recurse
```

`.ai-backup`配下に`smoke-test.txt`があれば、バックアップ処理は動作しています。

## 8. Git初期化の確認

```powershell
git -C $testProject status --short
git -C $testProject log --oneline -1
```

確認ポイント：

- GitHubへのPushは実行されていない
- `outputs/private/`がコミット対象になっていない
- `AI_FRAMEWORK_STATUS.yml`がProject内にある
- `scripts/setup-openspec.ps1`がProject内にある
- 実患者データやパスワードが存在しない

## 9. 問題が起きた場合

画面のエラーを消さず、次の情報を保存してください。

```powershell
node --version *> node-version.txt
npm --version *> npm-version.txt
npx --version *> npx-version.txt
Get-Content "$testProject\AI_FRAMEWORK_STATUS.yml" *> ai-framework-status.txt
Get-ChildItem "$testProject\.ai-backup" -Recurse *> backup-list.txt
```

保存したテキストファイルと、次の項目を報告してください。

- Windows 11のエディション
- `node --version`、`npm --version`、`npx --version`の結果
- どの手順番号で停止したか
- 画面に表示されたエラー全文
- `AI_FRAMEWORK_STATUS.yml`の内容
- `openspec/`の有無
- `.ai-backup/`の有無

## 10. テスト結果報告テンプレート

```markdown
# Windows 11 OpenSpec初期化テスト結果

実施日：YYYY-MM-DD
実施者：
Windows 11エディション：

## ツールバージョン

- node:
- npm:
- npx:

## 結果

- [ ] Node.js/npm/npx確認
- [ ] Case Project生成
- [ ] PROJECT.yml生成
- [ ] openspec/初期化
- [ ] AI_FRAMEWORK_STATUS.yml確認
- [ ] README案内確認
- [ ] OpenSpecスキップ確認
- [ ] OpenSpec再実行確認
- [ ] .ai-backup/確認
- [ ] Git初期化確認
- [ ] GitHubへPushしていないことを確認

## 問題・エラー

なし / あり：

## 添付ログ

- node-version.txt
- npm-version.txt
- npx-version.txt
- ai-framework-status.txt
- backup-list.txt
```

このテストは、OpenSpecを使い始めるための初期化確認です。実際の統計解析や実データ処理は、テスト完了後に別のCase Projectで開始してください。
