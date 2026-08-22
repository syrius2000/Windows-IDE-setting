名称は「Case Project」または「Analysis Project」が分かりやすく、共通化すべきです。

共通ツール群は一度だけ構築する
泌尿器科、ポンペ病などはテーマごとに独立したProjectとして作る
どのProjectでも、プログラム・SQL・レポート・出力先を同じ配置にする
Projectはテンプレートからコマンドで自動生成する
実RWDと認証情報はProjectのGit管理領域から分離する
添付の proposal.md にはテンプレートがありますが、「Projectを生成・検証・更新する機能」を追加すべきです
推奨する3層構造

1. Environment層

PCに一度だけ導入します。

Cursor
Git
SAS
Python・uv
R・rig・renv
Node.js・pnpm
Slidev・Quarto
DuckDB・MySQL Client
Ollama
Ruff・pytest・pre-commit・Gitleaks 2. Template層

共通リポジトリの templates/analysis-project/ で管理します。

標準ディレクトリ
SAS CP932設定
Cursor Tasks
.cursor/rules/
AGENTS.md
.gitignore
Python・R・Node.jsの初期設定
Gitへの機微データ混入検査
レポートテンプレート
合成データ
Project検証スクリプト3. Case Project層

テーマごとにテンプレートから生成します。

RWD-Projects/
├─ case-urology/
├─ case-pompe-disease/
└─ case-next-theme/

各Caseは、原則として独立したGitリポジトリにします。共通ツールリポジトリの中へ直接Caseを作ると、テンプレート更新、Git履歴、アクセス制御が混在するためです。

Case Projectの標準構成

初心者には、言語ごとに最上位ディレクトリを分散させるより、まず「プログラムは src/」と覚えてもらう方が簡単です。

case-urology/
├─ PROJECT.yml
├─ README.md
├─ src/
│ ├─ sas-cp932/
│ ├─ python/
│ ├─ r/
│ └─ typescript/
├─ sql/
├─ tests/
├─ reports/
│ ├─ quarto/
│ ├─ slidev/
│ └─ office/
├─ outputs/
│ ├─ tables/
│ ├─ figures/
│ ├─ listings/
│ └─ logs/
├─ data/
│ └─ synthetic/
├─ config/
│ ├─ project.yml
│ └─ local.paths.example.yml
├─ docs/
├─ .cursor/
│ └─ rules/
├─ .vscode/
│ └─ tasks.json
├─ pyproject.toml
├─ renv.lock
├─ package.json
└─ .gitignore

初心者向けの基本ルールは次の4つに絞れます。

プログラムは src/
SQLは sql/
報告書は reports/
実行結果は outputs/
PROJECT.yml

Projectごとの差異は、ディレクトリ構成を変更するのではなく、設定ファイルで表現します。

project:
id: case-urology
title: 泌尿器科RWD分析
template_version: "1.0.0"

data:
classification: deidentified
source: mysql-readonly
external_storage: true

analysis:
primary_language: sas
sas_encoding: cp932
secondary_languages: - python - r

reporting:
formats: - excel - powerpoint - slidev

ai:
cloud_allowed: false
local_llm_allowed: true
human_review_required: true

ここにMySQLパスワード、患者名、実データパスなどは記載しません。

データの配置

特に機微RWDでは、Git管理Projectの中に実データを置かない方が安全です。

Windows一般利用者
C:\Users\<user>\Documents\RWD-Projects\case-urology\

秘匿情報を扱わないなら、合成データや公開データを data/synthetic/ に置けます。

Mac専門家
~/RWD-Projects/case-pompe-disease/

実データは別領域にします。

/Volumes/RWD_SECURE/case-pompe-disease/

MySQL接続情報は次のように分離します。

パスワード：macOS Keychain
非秘密の接続設定：Git除外されたローカル設定
SQLプログラム：Projectの sql/
抽出結果：安全な外部データ領域

data/ を単に .gitignore するだけでは、Project全体をZIP化・同期した場合の流出を防げません。機微データは物理的にもProject外へ置く方が堅牢です。

Project生成コマンド

Windowsでは、初心者が次の1コマンドで作れるようにします。

.\scripts\project\New-AnalysisProject.ps1 `  -Name "case-urology"`
-Profile "windows-standard" `
-DataClassification "deidentified"

Macでは同じ内部処理を呼び出します。

./scripts/project/new-analysis-project.sh \
 case-pompe-disease \
 mac-rwd-expert \
 sensitive

内部では、次を自動処理します。

Project名を検査
テンプレートを複製
PROJECT.yml を作成
Gitリポジトリを初期化
Python・R・Node.js環境を初期化
Cursor TasksとAI Rulesを設定
実データ保存先をProject外に設定
合成データで動作確認
CursorでProjectを開く
Copierの採用

テンプレートエンジンとしては、OSSのCopierが適しています。

作成時の質問に基づいてProjectを生成できる
使用したテンプレート版を記録できる
後日 copier check-update で更新を確認できる
バージョン管理されたテンプレートから既存Projectを更新できる

uvx なら隔離環境でバージョンを指定して実行できます。

uvx --from "copier==<固定バージョン>" copier copy `  <template-path>`
<project-path>

ただし、初心者にCopierを直接操作させず、PowerShell／shellラッパーの内部で使用するのがよいでしょう。Copier公式、uv公式

テンプレート更新は自動適用せず、まず次だけを通知します。

copier check-update

更新によって案件固有コードと競合する可能性があるため、レビュー後に適用します。

Cursor設定

.vscode/tasks.json では絶対パスを書かず、${workspaceFolder} を基準にします。

{
"label": "SAS: Run current program",
"type": "shell",
"command": "pwsh",
"args": [
"-File",
"${workspaceFolder}/scripts/invoke-sas.ps1",
"-SysIn",
"${file}"
]
}

VS Code/CursorのTask設定は ${workspaceFolder} や ${file} の変数置換に対応するため、Caseディレクトリを移動しても設定を再利用できます。VS Code公式

proposal.mdへの追加案

現在の analysis-project-governance に加えて、次を独立Capabilityとして追加するのがよいです。

analysis-project-factory

成果物は次の構成です。

scripts/project/
├─ New-AnalysisProject.ps1
├─ new-analysis-project.sh
├─ validate-project.py
└─ update-project-template.py

templates/analysis-project/
├─ copier.yml
├─ PROJECT.yml.jinja
└─ template/

docs/
└─ project-lifecycle.md
事実・仕様
Cursorの基盤となるVS Code Tasksでは、ワークスペース相対変数を利用できます。
Copierは、生成済みProjectとテンプレートのバージョン関係を管理できます。
uvx はPython CLIを隔離環境で実行でき、実行バージョンも指定できます。
確認日：2026-08-22
提案

proposal.md に analysis-project-factory を追加し、次の二段階で実装することを推奨します。

New-AnalysisProject.ps1 による初心者向けProject生成
Copierによるテンプレートの版管理・更新確認

名称は次のように固定すると分かりやすいです。

全体：RWD Analysis Platform
テーマ単位：Case Project
共通雛形：Analysis Project Template
批判的立場
テンプレートを細かくしすぎると、初心者が「どこへ置くか」を再び迷います。最上位の役割は src、sql、reports、outputs の4つ程度に抑えるべきです。
テンプレート更新の自動適用は、既存解析コードや報告書を破壊する可能性があります。更新確認と更新適用を分離する必要があります。
全Caseを一つのGitリポジトリにまとめると、アクセス権、履歴、データ分類が混在します。共通基盤は一つ、Caseは独立リポジトリが安全です。
ディレクトリ統一は再現性を改善しますが、解析方法の妥当性までは保証しません。各Caseには解析計画、データ定義、検証記録を別途持たせる必要があります。

