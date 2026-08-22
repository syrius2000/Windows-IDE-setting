# AGENTS.md - Agent Context & Operational Guidelines

## Platform Context
本リポジトリは、阪大の統計専門家および研究者向け「RWD 解析・AI Agent 開発環境基盤」のマスターリポジトリです。

## 3層アーキテクチャの役割
1. **Environment層 (`scripts/windows/`, `scripts/macos/`)**: PCへの共通ツールチェーンの診断・導入・検証。
2. **Template層 (`templates/analysis-project/`, `schemas/`, `profiles/`)**: Copierベースの標準Case Project雛形。
3. **Case Project層 (`scripts/project/`)**: テーマごとに独立したGitリポジトリとして生成される解析案件。

## 厳格な運用ルール（Strict）
- **相対パスリンクの徹底**: Markdownドキュメント内のリポジトリ内相互リンクは、必ず相対パス（`[text](docs/...)`）で記述すること。
- **実データのGit混入防止**: 実患者データ、MySQLパスワード、APIキー、`.sas7bdat` をGitコミット・ステージングしてはならない。
- **文字コードの境界分離**: SASコードはCP932、それ以外のPython/R/TypeScript/MarkdownはUTF-8（BOMなし）を厳守すること。
- **4大ディレクトリ原則**: Case Project内ではプログラムを `src/`、SQLを `sql/`、報告書を `reports/`、出力を `outputs/` に配置すること。
- **開示統制の遵守**: `outputs/release/` に成果物を配置する場合は、必ず `release-manifest.yml` による人手確認記録を伴うこと。
