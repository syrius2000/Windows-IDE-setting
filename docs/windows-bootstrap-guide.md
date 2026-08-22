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

1. GitHub または学内共有フォルダから、本リポジトリのZIPファイルをダウンロードします。
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
[3/6] 02-install-analysis.ps1 # uv, Python 3.12, Copier 9.4.1, rig, R 4.4, Quarto, DuckDB の導入
[4/6] 03-install-reporting.ps1# Node.js LTS, pnpm, Slidev/TypeScript 実行環境の導入
[5/6] 04-configure.ps1        # Cursor本体の自動導入、拡張機能の一括導入、CP932/UTF-8マッピング構成
[6/6] 05-verify.ps1           # 合成データを用いたE2E全言語パイプライン自動検証
```

- **安全なエラー処理機能**:
  - 途中の工程でネットワーク切断等のエラーが発生した場合、スクリプトは勝手に「完了」とせず、**[R] 再試行 / [S] スキップ / [A] 中止** の選択肢を表示します。
  - すべての工程が正常終了した場合にのみ、緑色の完了バナーが表示され終了コード 0 が返されます。

---

## 🎯 セットアップ完了後: 最初の解析案件（Case Project）を作成する

環境構築が完了したら、主解析言語に応じたコマンドで新しい解析案件を1発生成できます：

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
- **回答**: はい、全く問題ありません。セットアップスクリプトはSASがなくてもPython 3.12、R 4.4、DuckDB、Quarto等のモダン統計環境を100%正常にセットアップします。

### Q2. `スクリプトの実行が無効になっているため...` というエラーが出る
- **対処法**: PowerShellで一時的に実行ポリシーを解除します：
  ```powershell
  Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
  ```

### Q3. WinGet が見つからない / 動作しない
- **対処法**: Microsoft Store から **「アプリ インストーラー」** を最新化するか、公式配布元 [https://aka.ms/getwinget](https://aka.ms/getwinget) からインストーラーを取得して実行してください。
