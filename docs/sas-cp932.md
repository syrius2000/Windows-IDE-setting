# SAS CP932 文字コード管理マニュアル

本ドキュメントは、SAS資産のCP932（Shift-JIS / Windows-31J）文字コードを破損・文字化けさせずに運用するための基準です。

---

## 1. なぜ文字コード分離が必要か

- 日本の医療機関・大学で運用されているSAS Foundation環境は、長年の資産互換性のため **CP932** を基本エンコーディングとしています。
- 一方、Python, R, TypeScript, Markdown, JSON は **UTF-8 (BOMなし)** が現代の標準です。
- UTF-8対応エディタで不用意に `.sas` を開いて保存すると、日本語コメント、変数ラベル、フォーマット名が文字化けし、SAS実行時に構文エラーを引き起こします。

---

## 2. ワークスペースおよびCursor設定

Case Project内の `.vscode/settings.json` により、以下が強制設定されています：

```json
{
  "files.encoding": "utf8",
  "files.associations": {
    "*.sas": "sas"
  },
  "[sas]": {
    "files.encoding": "shiftjis"
  },
  "files.autoGuessEncoding": false
}
```

- `src/sas-cp932/*.sas` を開いた場合、自動的に `shiftjis (CP932)` として読み書きされます。
- `src/python/*.py`, `src/r/*.R`, `*.md` を開いた場合、自動的に `utf-8` として読み書きされます。

---

## 3. データ読込・変換時のベストプラクティス

1. **Python (`pyreadstat`)**:
   必ず `encoding="cp932"` を指定します。
   ```python
   df, meta = pyreadstat.read_sas7bdat(filepath, encoding="cp932")
   ```
2. **R (`haven`)**:
   必ず `encoding="cp932"` を指定します。
   ```r
   df <- haven::read_sas(filepath, encoding="cp932")
   ```
3. **CSVエクスポート**:
   中間CSVをPython/Rに渡す場合は、SASの `PROC EXPORT` で文字コードを指定するか、Python側で `pd.read_csv(filepath, encoding="cp932")` を指定してください。
