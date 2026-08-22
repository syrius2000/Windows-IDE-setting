# RWD Governance & Coding Rules for Cursor AI

## 1. 医療情報保護とデータ境界ルール（Strict）
- **実データのクラウド送信禁止**: 実患者データ、非匿名化医療情報、MySQL接続パスワード、または実データから生成された個票行をプロンプトやチャットに入力してはならない。
- **合成データの利用**: コード生成・テスト・検証には、必ず `data/synthetic/` 配下の合成ダミーデータを使用すること。
- **outputs/ 分離原則**: 中間集計やログは `outputs/private/`（Git除外）に出力し、外部公開用成果物は人手レビュー（`release-manifest.yml`）を経て `outputs/release/` に配置すること。

## 2. 文字コード運用ルール
- **SASプログラム（`src/sas-cp932/`）**: 必ず `CP932 (Shift-JIS)` として扱う。UTF-8へ勝手に変換・上書き保存しないこと。
- **Python / R / TypeScript / SQL / Markdown**: 必ず `UTF-8`（BOMなし）として作成・保存すること。

## 3. ディレクトリ配置原則（4大原則）
- プログラムは `src/`
- SQLクエリは `sql/`
- 報告書・プレゼンは `reports/`
- 出力結果は `outputs/`
