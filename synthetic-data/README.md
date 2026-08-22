# Synthetic Datasets for Testing & Verification

このディレクトリ（`synthetic-data/`）には、**患者個人情報を含まない合成医療コホートデータ**を格納しています。

## 概要
- **`synthetic_cohort.csv`**: 患者20例（年齢、性別、治療群、ベースラインスコア、追跡日数、イベント発生フラグ）のダミーコホート。
- **用途**:
  - `05-verify.ps1` におけるエンドツーエンド検証
  - Case Project作成直後の動作テスト（SAS, Python, R, Quarto, PPTX）
  - Cursor AIとのペアプログラミング・プロンプト作成時の安全な入力データ
