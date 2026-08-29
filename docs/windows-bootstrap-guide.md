# クリーンな Windows 11 向け初期セットアップ手順書（Zero-to-One Setup Guide）

本手順書は、**クリーンな Windows 11 PC** に、RWD解析およびAI Agent（Cursor）を活用したモダンな開発環境を一括導入するためのマニュアルです。

> ℹ️ **SASの有無について**: **SAS 9.4 を保有していないPCでも、Python / R を用いた解析環境が100%自動でセットアップされます。** SASは必須要件ではありません。

---

## 📋 事前準備（前提条件の確認）

1. **PCの権限**: 個人所有PCであり、ローカル管理者権限（Administrator）があること。
2. **導入済みソフトウェア**:
   - **Cursor IDE**: [Cursor 公式サイト](https://www.cursor.com/) からインストールし、Cursor Pro アカウントでログインを完了しておくこと。
   - *(任意)* **SAS 9.4 (Foundation)**: 既存のSAS資産・マクロを利用する場合のみ。保有していなくてもPython/R環境は100%利用可能です。
3. **インターネット接続**: 初回ツール群（Git, uv, Python, R, Quarto, Node.js等）のダウンロードのため、インターネットに接続されていること。

---

## 🚀 導入手順（わずか 3 ステップ）

### ステップ 1: 本リポジトリの配置

1. 配布 ZIP または学内共有から本リポジトリを入手します（GitHub アカウントは不要です）。
2. ZIPファイルを右クリックして「すべて展開」を選択し、任意の場所（例: `C:\RWD-Platform` または `C:\Programing\Windows-IDE-setting`）に展開します。

---

### ステップ 2: 自動セットアップの実行（ワンクリック）

#### 方法 A: バッチファイルから実行（最も簡単・推奨）
1. 展開したフォルダ内の **`Setup-Windows.bat`** を右クリックします。
2. **「管理者として実行」** をクリックします。
3. 自動的にPowerShellが起動し、全ツールの導入と環境設定が順番に実行されます。

#### 方法 B: PowerShell から実行する場合
1. `Windowsキー + X` を押し、メニューから **「ターミナル (管理者)」** または **「PowerShell (管理者)」** を開きます。
2. 展開先ディレクトリへ移動し、以下のコマンドを実行します：
   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   .\scripts\windows\Setup-WindowsEnvironment.ps1
   ```

---

### ステップ 3: 自動導入されるツールと進行状況の確認

セットアップスクリプトは以下の順序で自動実行されます：

```text
[1/6] 00-diagnose.ps1         # ハードウェア、OS、管理者権限、WinGetの非破壊診断
[2/6] 01-install-common.ps1   # Windows Terminal, PowerShell 7, Git, 7-Zip のサイレント導入
[3/6] 02-install-analysis.ps1 # uv, Python 3.12.14, Copier 9.4.1, rig, R 4.6.1, Quarto, DuckDB の導入
[4/6] 03-install-reporting.ps1# Node.js LTS, pnpm, Slidev/TypeScript 実行環境の導入
[5/6] 04-configure.ps1        # Cursor設定・拡張機能の一括導入、CP932/UTF-8マッピング構成
[6/6] 05-verify.ps1           # 合成データを用いたE2E全言語パイプライン自動検証
```

- **安全なエラー処理機能**:
  - 途中の工程でネットワーク切断等のエラーが発生した場合、スクリプトは勝手に「完了」とせず、**[R] 再試行 / [S] スキップ / [A] 中止** の選択肢を表示します。
  - すべての工程が正常終了した場合にのみ、緑色の完了バナーが表示され終了コード 0 が返されます。

---

## 🎯 セットアップ完了後: 最初の解析案件（Case Project）を作成する

環境構築が完了したら、**本リポジトリ（プラットフォーム）のルート**で主解析言語に応じたコマンドを実行します。  
既定の生成先は `%USERPROFILE%\Programing\RWD-Projects\<Name>`（変更は `-DestinationRoot`）。  
`git config --global user.name` / `user.email` が未設定だと初回コミットがスキップされます（[Q6](#q6-case-project-はできたがinitial-git-commitがスキップされる) / [Troubleshoot §10](windows-troubleshooting.md#10-git-身元未設定で初回コミットがスキップされる)）。

### パターン A: Python 主解析プロジェクト（SAS不要・推奨）
```powershell
.\scripts\project\New-AnalysisProject.ps1 `
    -Name "case-urology" `
    -PrimaryLanguage "python"
```

### パターン B: R 主解析プロジェクト（SAS不要・推奨）
```powershell
.\scripts\project\New-AnalysisProject.ps1 `
    -Name "case-urology" `
    -PrimaryLanguage "r"
```

### パターン C: 既存SAS資産併用プロジェクト（SAS保有時のみ）
```powershell
.\scripts\project\New-AnalysisProject.ps1 `
    -Name "case-urology" `
    -PrimaryLanguage "sas" `
    -SasEncoding "cp932"
```

- 画面のプレビューを確認し、`Y` を入力すると、独立したGitリポジトリが初期化され、Cursorが自動起動します。

---

## ❓ トラブルシューティング ＆ FAQ

### Q1. SASを持っていませんが、問題なく使えますか？
- **回答**: はい、全く問題ありません。セットアップスクリプトはSASがなくてもPython 3.12.14、R 4.6.1、DuckDB、Quarto等のモダン統計環境を100%正常にセットアップします。

### Q2. `スクリプトの実行が無効になっているため...` というエラーが出る
- **対処法**: PowerShellで一時的に実行ポリシーを解除します：
  ```powershell
  Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
  ```

### Q3. WinGet が見つからない / 動作しない
- **対処法**: Microsoft Store から **「アプリ インストーラー」** を最新化するか、公式配布元 [https://aka.ms/getwinget](https://aka.ms/getwinget) からインストーラーを取得して実行してください。

### Q4. `'AI' is not recognized` や文字化けしたあと構文エラーになる
- **原因**: `Setup-Windows.bat` 内の `&` がコマンド区切りと解釈された、または `.ps1` が UTF-8（BOMなし）のまま Windows PowerShell 5.1 に読まれ CP932 誤解釈された。
- **対処法**: 本リポジトリの最新版（UTF-8 BOM 付きスクリプト）を使う。開発者は `scripts/windows/*.ps1` を macOS で保存し直したあと、BOM が消えていないか確認する（詳細は `AGENTS.md` の Windows PowerShell 例外）。

### Q5. `Variable reference is not valid. ':' was not followed by...` が出る
- **原因**: ダブルクォート文字列内の `$name: $_` を PowerShell がドライブ修飾変数と誤認する。
- **対処法**: `${name}:` のように波括弧で変数名を区切る（本リポジトリでは修正済み）。

### Q6. Case Project はできたが「Initial Git commit」がスキップされる
- **原因**: `git config --global user.name` / `user.email` が未設定。
- **対処法**: 診断（`00-diagnose.ps1`）で WARN が出ます。次を設定してから Case Project を作り直すか、手動で初回コミットしてください。
  ```powershell
  git config --global user.name "Your Name"
  git config --global user.email "you@example.com"
  ```

### 追加の実機トラブル一覧
初回 Win11 検証で踏んだ原因の要約は [windows-troubleshooting.md](windows-troubleshooting.md) を参照してください。

### macOS で Windows 用 `.ps1` を編集したら
必ず BOM 検査を実行してください（CI でも同じ検査が走ります）:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\windows\Assert-Utf8Bom.ps1
```

---

## 📚 関連ドキュメント

- [ソフトウェア構成表（Software Bill of Materials）](software-matrix.md)
- [初心者向けチートシート](beginner-cheatsheet.md)
- [日常運用マニュアル](daily-operations.md)
