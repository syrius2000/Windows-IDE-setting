# AI データ境界マトリクス（AI Data Boundary Policy）

本ドキュメントは、Cursor Pro（クラウドAI）およびローカルLLM（Ollama / gpt-oss-120b）へ入力可能なデータと禁止事項を定義したものです。

---

## 📊 データ分類とAI利用判定マトリクス

| データ分類 | 定義・具体例 | 保存場所 | Cursor Pro (Cloud AI) | ローカルLLM (Ollama) | オフライン処理 |
| :--- | :--- | :--- | :---: | :---: | :---: |
| **公開情報 / ドキュメント** | OSSコード, 一般的なアルゴリズム, 公開仕様書 | リポジトリ内 | **許可** (Privacy Mode) | 許可 | 不要 |
| **合成データ (Synthetic)** | `data/synthetic/` 内のダミーデータ（乱数生成） | リポジトリ内 | **許可** (Privacy Mode) | 許可 | 不要 |
| **仮名化 / 秘匿化RWD** | 教室内MySQL 8.0内のRWDデータ | 外部保護領域 / LAN | **禁止** (送信不可) | **許可** (教室内LAN) | 推奨 |
| **非匿名化 / 機微医療PDF** | 手書き医療文書, カルテ生画像, 未加工テキスト | 外部保護領域 (`RWD_SECURE`) | **厳禁** (完全遮断) | **許可** (ローカル推論) | **必須** (`offline-check.sh`) |
| **認証情報 / シークレット** | DBパスワード, APIキー, クライアント秘密鍵 | macOS Keychain | **厳禁** | **厳禁** | - |

---

## 🔒 ガードレールの仕組み

1. **`.cursorignore`**: 機微ファイル（`.sas7bdat`, `.env`, `outputs/private/`）をCursor AIのインデックス・コンテキストから自動除外。
2. **`.cursor/rules/rwd-governance.md`**: Cursor Agentに対して、実データのクラウド送信禁止と合成データ活用のプロンプトルールを強制。
3. **`Gitleaks` & `validate-project.py`**: コミット前および検証時に、APIキーや禁止拡張子の混入を自動検知してブロック。
