# 阪大・統計専門家向け AI Agent 環境構築

## 最終確認質問への回答（Answer 2）

- 作成日: 2026-08-22
- 対象: Windows一般利用者、Mac専門家、SAS・R・Python・MySQL 8.0・ローカルAIを併用する研究環境
- 前提: 実データ、認証情報、OCR中間生成物はGitリポジトリへ保存しない

## 結論

- **Q1: A′ — WinGet優先＋検証可能な公式フォールバック**
  - Aを採用する。
  - ただし、管理者権限で `irm ... | iex` を無条件に自動実行する設計にはしない。
  - 再試行、バージョン固定、公式配布元、ハッシュまたは署名確認、実行ログを組み込む。
- **Q2: A′ — Cursor内SASバッチ実行タスクを同梱し、既存SAS GUIも残す**
  - Aを採用する。
  - `.vscode/tasks.json` からPowerShellラッパーを呼び出し、SASパス検出、CP932維持、ログ判定を一元化する。
- **Q3: A + C — Apple Visionを基準系、ローカルVLMを補助系とする**
  - 提案どおりA+Cを採用する。
  - ただし「Apple Visionは日本語手書きに高精度」と事前に断定せず、対象帳票で比較試験する。
- **Q4: A — macOS Keychainを第一選択とする**
  - パスワードだけをKeychainに保存する。
  - ホスト、ポート、DB名、ユーザー名などの非秘密情報は、接続プロファイルとして分離する。
- **Q5: A′ — 統合リポジトリ＋利用者プロファイル分離**
  - 単一リポジトリを採用する。
  - Windows専用に見える `Windows-IDE-setting` は、Mac・RWD・SASを含む名称へ変更することを推奨する。

---

## Q1 — Windows自動インストールスクリプトの依存性・フォールバック設計

### 回答

- **Aを採用する。ただし「A′: WinGet優先＋統制された公式フォールバック」とする。**
- 初心者向けには、WinGetの一時的な不具合だけで全体が中断しない設計が妥当である。
- 一方、複数の公式インストーラーを独自にダウンロードするコードは保守対象を増やすため、全パッケージに同じフォールバックを実装しない。

### 実装方針

- インストール前に次を診断する。
  - Windows 11のエディション、CPUアーキテクチャ、管理者権限
  - PowerShellバージョンとExecutionPolicy
  - `winget` の存在、バージョン、ソース状態
  - HTTPS接続、プロキシ、必要空き容量
  - 既存インストールとPATH
- WinGetはパッケージIDを完全一致で指定する。

```powershell
winget install --id <Package.Id> --exact --source winget `
  --silent --disable-interactivity `
  --accept-package-agreements --accept-source-agreements
```

- WinGetの公式仕様では、`--silent`、`--disable-interactivity`、パッケージとソースの規約同意オプションを併用できる。
- 各パッケージについて、終了コードだけでなく、導入後の実行ファイルとバージョンを確認する。
- 一時的なネットワーク障害では、短い間隔を空けて最大2回再試行する。
- 失敗理由を次のように分類する。
  - WinGet自体が存在しない、または登録不良
  - ソース更新・規約同意の問題
  - ネットワークまたはプロキシの問題
  - インストーラー固有の失敗
  - 再起動待ち
- WinGet自体の不良時は、まずMicrosoft公式のApp Installer／WinGet修復手順へ誘導する。
- 公式フォールバックは、導入に不可欠で公式配布方式が安定しているツールに限定する。
  - `uv`: Astral公式インストーラー
  - Node.js: Node.js公式配布物
  - R管理ツール: rig公式配布物
- フォールバックでは次を必須とする。
  - 公式HTTPS URLのみ使用
  - 許可したバージョンをマニフェストに記録
  - 可能な場合はSHA-256またはコード署名を検証
  - 一時ディレクトリへ保存してから実行
  - タイムアウトを設定
  - URL、バージョン、終了コードをログへ記録
  - `--ignore-security-hash` 相当は使用しない
- `irm <URL> | iex` は手動導入例として資料に記載できるが、管理者権限で走る自動フォールバックの標準実装にはしない。
- フォールバック後も失敗した場合は、無限継続せず停止し、初心者が情シスまたは管理者へ渡せる診断ログを出力する。
- 各スクリプトは再実行可能にする。既に正しいバージョンがある場合はスキップし、中途半端な状態を壊さない。

### 判定

- **Proposal:** A′を採用する。
- **Critical position:** フォールバックを増やしすぎると、公式パッケージ更新のたびに保守負債が発生する。WinGet修復、再試行、必要最小限の公式フォールバックの三段階に限定する。

### 公式仕様

- [Microsoft Learn: WinGet install command](https://learn.microsoft.com/en-us/windows/package-manager/winget/install)
- [Microsoft Learn: Windows Package Manager](https://learn.microsoft.com/en-us/windows/package-manager/)
- [Astral: uv installation](https://docs.astral.sh/uv/getting-started/installation/)

---

## Q2 — Cursor内からのSASプログラム実行連携

### 回答

- **Aを採用する。ただし、既存のSAS Display Manager／Enterprise Guideも残す。**
- Cursor内実行は便利だが、一般利用者の既存操作を一度に廃止する必要はない。
- 初期段階では「Cursorで編集・タスク実行」と「SAS GUIで実行」の両方を正式な手順にする。

### 実装方針

- `.vscode/tasks.json` に複雑な処理を直接書かない。
- タスクから `scripts/windows/invoke-sas.ps1` を呼び出す。
- PowerShellラッパーが次を担当する。
  - SAS Foundationの実行ファイルをレジストリと標準インストール先から検出
  - 複数バージョン検出時の選択と表示
  - ローカル設定による `sas.exe` パス上書き
  - 現在開いている `.sas` ファイルの受け取り
  - `-SYSIN`、`-LOG`、`-PRINT` などの起動オプション設定
  - 引数とパスの安全な引用符処理
  - 実行時刻別の出力先作成
  - 実行後のログ確認
- 出力はソースと同じ場所へ散在させず、次のように分離する。

```text
.run/sas/<program-name>/<yyyyMMdd-HHmmss>/
├─ program.log
├─ program.lst
└─ run-metadata.json
```

- `.run/`、`.log`、`.lst` は原則Git除外とする。
- SASソースはCP932を前提に扱い、Cursor側でUTF-8へ暗黙変換しない。
- SAS用ディレクトリとPython／R／TypeScript用UTF-8ディレクトリを分離する。
- 保存時エンコーディング、改行コード、文字化け確認をチートシートに明記する。
- SASプロセスの終了コードだけで成功判定しない。
  - ログ内の `ERROR:`、異常終了、入力ファイル不在などを検出する。
  - `WARNING:` は失敗扱いにせず、件数と該当箇所を表示する。
  - 誤検出を避けるため、単純な文字列検索だけでなく判定ルールをテストする。
- `Ctrl+Shift+B` は「現在のSASファイルを実行」に割り当てる。
- 追加タスクとして次を用意する。
  - SAS実行
  - 最新ログを開く
  - 最新LSTを開く
  - SASパス診断
  - CP932保存状態の確認
- 実RWDの保存場所をリポジトリ配下にしない。タスクは外部データパスをローカル設定から参照する。

### 受入条件

- 空白と日本語を含むWindowsパスで実行できる。
- CP932の日本語コメント、ラベル、フォーマット名が文字化けしない。
- SAS未導入時、複数版導入時、ライセンス切れ時に理解可能なエラーを出す。
- 成功、SAS構文エラー、データ不在、異常終了を区別できる。
- SAS GUIで同じプログラムを再実行できる。

### 判定

- **Proposal:** A′を採用し、CursorタスクとSAS GUIを併存させる。
- **Critical position:** 「ワンクリックで動いた」ことと「解析が正しい」ことは別である。ログ確認を省略する自動化は導入しない。

### 公式仕様

- [SAS Help Center: Files Used by SAS under Windows](https://documentation.sas.com/doc/en/pgmsascdc/9.4_3.3/hostwin/p0bmj7wjme32ayn1h4wim7trkhp6.htm)
- [SAS Help Center: SAS options under Windows](https://documentation.sas.com/doc/en/hostwin/9.4/p1ktqb6146fz65n1ga49hcf0rm2v.htm)

---

## Q3 — Mac専門家版の手書き医療PDF用ローカルOCR

### 回答

- **A + Cを採用する。**
- Apple Vision Frameworkを軽量な第一段階、ローカルVision-Language Model（VLM）を難読箇所の第二段階とする。
- Tesseractは削除せず、活字帳票のOSS基準系および比較対象として任意導入にする。

### 重要な修正

- Apple Vision Frameworkが日本語・英語の手書き医療文書で常に高精度、という断定は現時点では避ける。
- Apple公式APIでは、認識リクエストのリビジョンごとに対応言語を照会できる。実行時に対応言語を確認する。
- 対象となる実際の帳票、筆跡、スキャン品質、略語で小規模ベンチマークを行ってから主経路を確定する。
- `gpt-oss-120b` はテキスト入出力モデルであり、公式モデル仕様では画像入力をサポートしない。そのため、画像を直接渡すのではなく、OCRまたはVLMの出力を構造化する最終段として用いる。

### 推奨パイプライン

1. PDFをページ画像へローカル変換する。
2. 傾き補正、回転、コントラスト調整を行う。
3. Apple Visionで文字列、座標、信頼度を抽出する。
4. 低信頼領域または重要項目だけをローカルVLMへ渡す。
5. OCR結果とVLM結果を `gpt-oss-120b` で定義済みJSON Schemaへ整形する。
6. 型、日付範囲、単位、コード表、必須項目で決定論的に検証する。
7. 不一致、低信頼、欠測は自動確定せず、人手確認キューへ送る。
8. 承認済みデータだけを分析用領域へ移す。

### 保存すべき監査情報

- 元PDFの管理IDまたはハッシュ。ただし患者識別子をファイル名にしない。
- ページ番号、領域座標、前処理条件
- OCRエンジン、モデル名、バージョン、プロンプト版
- 生OCR結果、構造化前後の値、信頼度
- 自動検証結果、人手修正履歴
- 実行日時とパイプラインのGitコミットID

### 比較評価指標

- 項目単位の完全一致率
- 数値、日付、単位、否定表現の誤抽出率
- 重要項目の再現率と適合率
- 欠測を欠測として拒否できた割合
- 1帳票あたりの人手修正時間
- 誤りを含んだまま自動確定した件数

### 運用上の制約

- OCR/VLM/LLMの推論は、秘匿化されない医療情報について完全ローカルで行う。
- モデル取得のために一時的にネット接続する場合、患者PDFや中間生成物を開かない状態で実施する。
- モデル取得後はオフライン確認スクリプトで外向き通信、クラウドAPI設定、同期フォルダを検査する。
- ローカルVLMの具体名は固定せず、MacBook Pro 128GB上の精度、速度、モデルライセンス、Ollama対応状況を比較して固定する。

### 判定

- **Proposal:** A+Cを採用し、Tesseractを比較用OSS基準系として残す。
- **Critical position:** OCR精度の印象評価だけで本番採用しない。医療情報では、もっとも危険なのは「もっともらしい誤読」である。自動棄却と人手確認を必須にする。

### 公式仕様

- [Apple Developer: Recognizing text in images](https://developer.apple.com/documentation/vision/recognizing-text-in-images)
- [Apple Developer Videos: Vision framework](https://developer.apple.com/videos/ai-machine-learning/)
- [OpenAI: gpt-oss-120b model specification](https://developers.openai.com/api/docs/models/gpt-oss-120b)

---

## Q4 — MySQL 8.0認証情報の安全な管理

### 回答

- **Aを採用し、macOS Keychainを第一選択とする。**
- PythonとRから同じOS資格情報ストアを利用できる構成にする。
- `.env` やJSONへパスワードを平文保存しない。

### 情報の分離

- Keychainへ保存する秘密情報:
  - MySQLパスワード
  - 必要な場合のみクライアント証明書の秘密鍵に関する参照情報
- ローカル接続プロファイルへ保存できる非秘密情報:
  - ホスト名または教室内IPアドレス
  - ポート
  - データベース名
  - ユーザー名
  - TLS利用条件
  - 読み取り専用設定
- リポジトリへ置くもの:
  - 値を含まない設定テンプレート
  - Keychain登録・確認・削除ユーティリティ
  - Python／Rの接続例
  - `.gitignore` と秘密情報検査

### 実装方針

- Pythonは `keyring`、Rも `keyring` を利用する。
- macOSではR keyringの標準バックエンドがネイティブKeychain APIを使用する。
- サービス名はプロジェクトと接続用途が判別できる固定形式にする。
- 初回登録時だけ対話的にパスワードを受け取る。
- パスワードを次へ出力しない。
  - コンソール
  - PowerShell／shell履歴
  - Python／R例外メッセージ
  - SQLログ
  - CursorのチャットまたはAgentログ
- 接続時にKeychainからメモリ上へ読み出し、使用後に不要な参照を保持しない。
- DBアカウントは分析用の読み取り専用ユーザーを原則とする。
- `SELECT` 対象スキーマと接続元端末または教室内ネットワークを制限する。
- MySQLサーバーがTLSを提供できる場合は証明書検証を有効にする。
- `B` のファイル方式は、Keychainを利用できない自動処理などの例外時だけに限定する。
  - `.env.local` 等はGit除外
  - 所有者のみ読み書き
  - 起動時に権限を検査
  - サンプル値のみをリポジトリへ保存

### 受入条件

- リポジトリ全体を検索しても実パスワードが存在しない。
- PythonとRの両方から同一プロファイルで読み取り専用接続できる。
- Keychain項目がない場合、平文フォールバックせず明示的に停止する。
- パスワード変更、資格情報削除、接続テストの手順が初心者向けに記載されている。

### 判定

- **Proposal:** Aを採用し、非秘密設定との分離を追加する。
- **Critical position:** Keychainを使っても、広すぎるDB権限やログへのデータ出力は防げない。最小権限、接続元制限、実データをGitへ置かない運用を別途強制する。

### 公式仕様

- [Python keyring documentation](https://keyring.readthedocs.io/)
- [R keyring documentation](https://keyring.r-lib.org/)
- [R keyring: macOS Keychain backend](https://keyring.r-lib.org/reference/backend_macos.html)

---

## Q5 — 成果物ディレクトリ構造

### 回答

- **Aを採用する。ただし、利用者プロファイルと共通プロジェクトテンプレートを分離する。**
- 現時点では利用者が少なく、SAS、文字コード、AI入力基準などの共通ルールが多いため、別リポジトリ化は過剰である。
- 将来、Mac側のRWD/OCRパイプラインが独立した運用責任、アクセス権、リリース周期を持った時点で分割を再検討する。

### リポジトリ名

- `Windows-IDE-setting` はMac、MySQL、OCR、RWDを含む実態を表さない。
- 第一候補: `sas-rwd-agent-environment`
- 第二候補: `stat-ai-agent-starter`
- 既存URLや説明資料との互換性を優先する場合は、当面旧名を維持し、README先頭で対象範囲を明記する。

### 推奨構成

```text
sas-rwd-agent-environment/
├─ README.md
├─ AGENTS.md
├─ scripts/
│  ├─ windows/
│  │  ├─ 00-diagnose.ps1
│  │  ├─ 01-install-common.ps1
│  │  ├─ 02-install-analysis.ps1
│  │  ├─ 03-install-reporting.ps1
│  │  ├─ 04-configure.ps1
│  │  └─ 05-verify.ps1
│  └─ macos/
│     ├─ diagnose.sh
│     ├─ configure-keychain.sh
│     ├─ mysql-readonly-test.sh
│     ├─ ollama-test.sh
│     └─ offline-check.sh
├─ profiles/
│  ├─ windows-standard/
│  └─ mac-rwd-expert/
├─ templates/
│  └─ analysis-project/
│     ├─ .cursor/rules/
│     ├─ .vscode/tasks.json
│     ├─ sas-cp932/
│     ├─ python-utf8/
│     ├─ r-utf8/
│     ├─ typescript-utf8/
│     ├─ sql/
│     └─ tests/
├─ config/
│  └─ examples/
├─ docs/
│  ├─ software-matrix.md
│  ├─ beginner-cheatsheet.md
│  ├─ daily-operations.md
│  ├─ sas-cp932.md
│  ├─ mysql-readonly.md
│  ├─ ai-data-boundary.md
│  └─ incident-response.md
├─ synthetic-data/
├─ tests/
└─ .gitignore
```

### 構造上のルール

- `scripts/`: OSそのものの診断、導入、検証だけを置く。
- `profiles/`: Windows一般利用者とMac専門家で異なる導入項目・設定値を宣言する。
- `templates/analysis-project/`: 個々の解析案件を始めるための共通雛形を置く。
- SASソース領域はCP932、Python／R／TypeScript／Markdown／JSONはUTF-8とし、境界を明示する。
- `synthetic-data/` には合成データだけを置く。
- 次はリポジトリへ置かない。
  - RWD実データ、SAS実データ、MySQLダンプ
  - 患者PDF、OCR画像、OCR中間テキスト
  - `.env`、パスワード、秘密鍵、APIキー
  - SASログ、LST、一時成果物
- GitHub個人アカウントのPrivateリポジトリであっても、実医療データの保存先として扱わない。
- OSS系開発ツールはインストールスクリプトとソフトウェア構成表で管理する。
  - Git、Git LFS
  - PowerShell 7
  - Windows Terminal
  - `uv`、Python
  - R、rig、renv
  - Node.js LTS、Corepack、pnpm
  - MySQL ShellまたはMySQL Client
  - DuckDB CLI
  - Ollama
  - Pandoc、QuartoまたはSlidev
  - Ruff、pytest、pre-commit
- すべてを一律に入れず、`common`、`analysis`、`reporting`、`local-ai` のプロファイル単位で選択できるようにする。

### 判定

- **Proposal:** A′として単一リポジトリを採用し、名称変更とプロファイル分離を行う。
- **Critical position:** ワンストップ化は便利だが、全ツールの一括強制導入は初心者の認知負荷と保守負担を増やす。リポジトリは統合し、導入内容はプロファイルで絞る。

---

## 次工程へ進む際の確定事項

- Windows一般利用者:
  - Windowsネイティブを第一環境とする。
  - WSL2は別教育計画とし、初回必須にしない。
  - Cursor、SAS、R、Python、報告作成ツールを段階導入する。
- Mac専門家:
  - 秘匿化されない医療情報の処理はローカル・オフラインを原則とする。
  - 教室内MySQL 8.0へ読み取り専用で接続する。
  - 認証情報はmacOS Keychainで管理する。
  - OCRはApple Vision＋ローカルVLM＋人手確認で構成する。
- 共通:
  - SAS CP932と、それ以外のUTF-8領域を明示的に分離する。
  - Gitにはコード、設定テンプレート、文書、合成データだけを保存する。
  - AIへの入力可否は「匿名化」という名称だけでなく、再識別可能性と利用規程を確認して決める。
  - 各自動化には診断、ログ、再実行性、検証、手動フォールバックを備える。

## 最終判断

- この5点は、上記の修正を条件として実装開始可能である。
- 最優先は、`00-diagnose`、秘密情報境界、CP932テスト、MySQL読み取り専用テスト、OCR精度評価用の合成または許可済みサンプルである。
- これらの検証前に、全ツールの一括導入や実RWDを使ったAgent自動処理へ進まない。
