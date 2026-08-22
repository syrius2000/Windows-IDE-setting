# README・初期導入・SAS任意化の整理計画

created: 2026-08-23 02:47 (JST)
update: 2026-08-23 02:47 (JST)
author: Codex (GPT-5)

## 1. 目的

初学者がWindows 11の初期導入から最初の統計プロジェクト作成、継続的なPython/R/SAS分析まで迷わず進められるように、READMEと関連手順書の導線を整理する。

併せて、SASを保有しない利用者でも、PythonまたはRを主解析言語として環境導入・Case Project作成・検証・継続作業を完了できることを明確化する。

## 2. 対象範囲

### 2.1 文書

- `README.md`
  - 「初めて使う人」と「導入済みで継続利用する人」の入口を分離する。
  - 初期導入、最初のCase Project作成、継続運用へのリンクを明確化する。
  - SAS必須と誤認されない説明に改める。
- `docs/windows-bootstrap-guide.md`
  - Cursorは手動導入・ログイン済みを前提とする。
  - SASは任意、Python/RはSASなしでも利用可能であることを明記する。
  - Python主解析・R主解析の初回導入後コマンド例を追加する。
- `docs/beginner-cheatsheet.md`
  - 初回導入後のCase Project作成例をPython/R/SASに分ける。
  - SAS未導入時に実行しない操作を明記する。
- `docs/daily-operations.md`
  - SASを使わないPython/R中心の標準フローを追加する。
  - SAS利用フローを任意の補助フローとして位置付ける。

### 2.2 導入・生成スクリプト

- `scripts/windows/05-verify.ps1`
  - SAS実行ファイルの存在を必須条件にしない。
  - SASはCP932サンプルの検査のみ、実SAS実行は存在時のみ行う構成を確認・必要最小限修正する。
- `scripts/project/New-AnalysisProject.ps1`
  - Python/R主解析の指定例と、SASなしでの検証経路を確認する。
  - `PrimaryLanguage`と`SasEncoding`の入力制約・既定値がSASなし利用者を阻害しないことを確認する。
- `templates/analysis-project/template/README.md.jinja`
  - 主解析言語に応じた初回・継続運用案内を追加する。
  - SASタスクはSAS導入済みの場合のみ使用する任意機能として説明する。

## 3. 非対象範囲

- Cursor本体のインストール処理およびログイン認証フローの変更。
- SAS、R、Python本体の配布元やバージョン方針の変更。
- MySQL、ODBC、macOS OCRパイプラインの機能変更。
- Git commit、push、archive、既存データの削除。

## 4. 実装方針

1. READMEは詳細手順を詰め込まず、利用段階別のナビゲーションに限定する。
2. 初期導入と継続的な統計PJ運用を明確な章として分離する。
3. SASは「既存SAS資産を使う場合の任意コンポーネント」と定義する。
4. Python/Rを主解析言語とするCase Project作成例を標準導線として追加する。
5. 初学者がSAS未導入のままSASタスクを実行して失敗しないよう、条件付き利用を明記する。

## 5. 検証計画

- Markdownリンクと見出し構成を確認する。
- Python/R/SAS各主解析言語のCase Project生成パラメータを静的確認する。
- SAS未導入時に初期導入を阻害する必須チェックがないことを確認する。
- 既存Pythonテストを実行する。
- PowerShell実行環境がない場合は、PowerShell実機検証を未実施として明記する。
- 文書の初学者向け導線を、以下の順で読んで確認する。
  - 初期導入
  - 最初のCase Project作成
  - Python/R中心の継続分析
  - SASを使う場合の追加手順

## 6. 承認ゲート

本計画の承認前は、計画Artifactの作成・読み取り専用調査のみ実施する。

ユーザーから「承認します」「実行して」等の明示的な承認を受けた後に、対象範囲内の文書・スクリプト・テンプレートを編集する。

