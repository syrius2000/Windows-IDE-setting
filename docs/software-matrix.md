# ソフトウェア構成表（Software Bill of Materials / BOM）

本プラットフォームで利用・導入するツールの構成定義、ライセンス、配布元、固定バージョン、および運用手順です。

| ツール名 | 用途 | OSSライセンス | 公式配布元 | 対象OS | インストール方法 | 固定/推奨バージョン | 更新方法 | アンインストール方法 | 区分 | 既知の制約・注意点 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Git for Windows** | バージョン管理・履歴保存 | GPL v2 | [git-scm.com](https://git-scm.com/) | Win/Mac | `winget install Git.Git` / `brew install git` | 2.46+ | `winget upgrade Git.Git` | `winget uninstall Git.Git` | **必須** | 実RWDや秘密情報はコミット禁止 |
| **PowerShell 7** | 自動化スクリプト実行 | MIT | [github.com/PowerShell/PowerShell](https://github.com/PowerShell/PowerShell) | Win/Mac | `winget install Microsoft.PowerShell` | 7.4+ | `winget upgrade Microsoft.PowerShell` | `winget uninstall Microsoft.PowerShell` | **必須** | Windows PowerShell 5.1と共存 |
| **Windows Terminal** | 共通ターミナルUI | MIT | [github.com/microsoft/terminal](https://github.com/microsoft/terminal) | Win | `winget install Microsoft.WindowsTerminal` | 1.21+ | `winget upgrade Microsoft.WindowsTerminal` | `winget uninstall Microsoft.WindowsTerminal` | **必須** | PowerShell 7 を規定プロファイルに設定 |
| **uv** | Python環境・パッケージ管理 | MIT / Apache-2.0 | [astral.sh/uv](https://astral.sh/uv) | Win/Mac | `winget install astral-sh.uv` / 公式スクリプト | 0.5+ | `uv self update` | `uv cache clean` & 削除 | **必須** | 超高速・単一バイナリ。Conda不要 |
| **Python** | RWD処理・AI連携・検証 | PSF License | [python.org](https://www.python.org/) | Win/Mac | `uv python install 3.12` | 3.12.x | `uv python install <ver>` | `uv python uninstall 3.12` | **必須** | 仮想環境（.venv）で完全分離 |
| **Copier** | Case Projectテンプレート生成 | MIT | [copier.readthedocs.io](https://copier.readthedocs.io/) | Win/Mac | `uv tool install "copier==9.4.1"` | **9.4.1** (固定) | `uv tool upgrade copier` | `uv tool uninstall copier` | **必須** | テンプレート更新時は差分レビュー必須 |
| **rig** | R言語バージョンマネージャー | MIT | [github.com/r-lib/rig](https://github.com/r-lib/rig) | Win/Mac | `winget install --id Posit.rig --exact` / `brew install --cask rig` | 0.7+ | `rig self update` | `winget uninstall --id Posit.rig --exact` | **必須** | Rの複数版管理・Rtools連携。WinGet ID は `Posit.rig`（`RProject.rig` は存在しない） |
| **R** | 統計解析・生存時間解析 | GPL v2 / GPL v3 | [r-project.org](https://www.r-project.org/) | Win/Mac | `rig add 4.4.1` | 4.4.1 | `rig add <ver>` | `rig rm 4.4.1` | **必須** | パッケージは `renv` で管理 |
| **Quarto** | 統計解析レポート作成 | GPL v2 | [quarto.org](https://quarto.org/) | Win/Mac | `winget install Posit.Quarto` / `brew install quarto` | 1.5+ | `winget upgrade Posit.Quarto` | `winget uninstall Posit.Quarto` | **必須** | R/Python両方の出力を統合 |
| **DuckDB CLI** | 高速SQL中間解析 | MIT | [duckdb.org](https://duckdb.org/) | Win/Mac | `winget install DuckDB.cli` / `brew install duckdb` | 1.1+ | `winget upgrade DuckDB.cli` | `winget uninstall DuckDB.cli` | **必須** | In-MemoryでParquet/CSVを即座に集計 |
| **Node.js LTS** | プレゼン・報告自動化基盤 | MIT | [nodejs.org](https://nodejs.org/) | Win/Mac | `winget install OpenJS.NodeJS.LTS` / `brew install node` | 20.x / 22.x | `winget upgrade OpenJS.NodeJS.LTS` | `winget uninstall OpenJS.NodeJS.LTS` | **必須** | Corepackでpnpmを有効化 |
| **pnpm** | 高速Nodeパッケージ管理 | MIT | [pnpm.io](https://pnpm.io/) | Win/Mac | `corepack enable pnpm` | 9.x+ | `corepack prepare pnpm@latest --activate` | - | **必須** | `pnpm-lock.yaml` でバージョン固定 |
| **Slidev** | Webスライド作成 | MIT | [sli.dev](https://sli.dev/) | Win/Mac | `pnpm add -D @slidev/cli` (Project内) | 0.50+ | `pnpm update @slidev/cli` | - | 任意 | 研究会・発表用Markdownスライド |
| **PptxGenJS** | 編集可能PowerPoint出力 | MIT | [gitbrent.github.io/PptxGenJS](https://gitbrent.github.io/PptxGenJS/) | Win/Mac | `pnpm add pptxgenjs` (Project内) | 3.12+ | `pnpm update pptxgenjs` | - | **必須** | 成果物PowerPointをプログラム生成 |
| **Ollama** | ローカルLLM推論エンジン | MIT | [ollama.com](https://ollama.com/) | Mac (Win任意) | 公式インストーラー / `brew install ollama` | 0.5+ | `ollama update` | アプリ削除 | Mac必須 | `gpt-oss-120b` による医療JSON構造化 |
| **Gitleaks** | 秘密情報・APIキー誤混入検知 | MIT | [github.com/gitleaks/gitleaks](https://github.com/gitleaks/gitleaks) | Win/Mac | `winget install Gitleaks.Gitleaks` / `brew install gitleaks` | 8.21+ | `winget upgrade Gitleaks.Gitleaks` | `winget uninstall Gitleaks.Gitleaks` | **必須** | pre-commitフックでコミット時検査 |
| **Cursor** | AI Agent統合開発環境 | プロプライエタリ | [cursor.com](https://www.cursor.com/) | Win/Mac | 公式インストーラー (購入済み) | 最新LTS | アプリ内自動更新 | アプリ削除 | **必須** | Privacy Mode有効化が前提 |
