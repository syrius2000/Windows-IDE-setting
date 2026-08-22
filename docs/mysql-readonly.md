# MySQL 8.0 読取専用接続 & セキュリティ運用基準

本ドキュメントは、Mac専門家環境から教室内LANのMySQL 8.0データベースへ安全に接続・データ抽出するためのセキュリティ基準、直接接続手順、およびExcel/Office利用者向けのODBC/DSN設定手順です。

---

## 1. 接続経路のアーキテクチャ分離

```text
iMac / MacBook Pro
 ├─ 【標準経路（推奨）】
 │   ├─ Python ──── PyMySQL / mysql-connector-python ──── MySQL 8.0 (LAN)
 │   └─ R ───────── RMariaDB / DBI ────────────────────── MySQL 8.0 (LAN)
 └─ 【任意経路（Office用）】
     └─ Excel等 ─── MySQL Connector/ODBC ── DSN ───────── MySQL 8.0 (LAN)
```

- **標準経路（Python / R 直接接続）**:
  - 外部ODBCドライバやDSN設定に依存しない自己完結型の接続方式。
  - 最も高速かつエラーが少なく、解析ワークフローの標準として推奨されます。
- **任意経路（Excel / Office向け ODBC接続）**:
  - ExcelやFileMaker等のGUIツールから直接参照したい研究者向けの追加プロファイル。
  - ODBCが未導入または接続失敗した場合でも、**標準直接接続経路には一切影響を与えません**。

---

## 2. 認証情報のKeychain管理（平文ファイル保存厳禁）

データベースのパスワードは、`.env`、設定JSON、および `odbc.ini` などのファイルに平文で保存してはなりません。
必ず `scripts/macos/configure-keychain.py` を用いて、macOS Keychainに登録してください。

```bash
# Keychainへの登録 (対話的入力)
python3 scripts/macos/configure-keychain.py set --username rwd_readonly_user

# 登録確認 (パスワード自体は表示されません)
python3 scripts/macos/configure-keychain.py check --username rwd_readonly_user
```

---

## 3. 標準直接接続の実行とデータ品質検査

`scripts/macos/mysql-readonly-test.py` を使用して、接続性、安全な権限監査、およびデータ品質検査を実行します。

```bash
python3 scripts/macos/mysql-readonly-test.py --host 192.168.0.50 --db rwd_research_db
```

- **非破壊的権限監査**: `SHOW GRANTS` により、書き込み権限（`INSERT`, `UPDATE`, `DELETE`, `DROP` 等）が付与されていないことを確認します。
- **データ品質サマリー**: 総件数、主キー重複率、カラム別NULL率を算出し、個票データは画面・ログへ一切出力しません。

---

## 4. 任意ODBCプロファイルの設定手順（Excel / Office利用者向け）

### 4.1 ドライバ導入とCPUアーキテクチャの適合
1. **ドライバのダウンロード**:
   - [MySQL Connector/ODBC 公式ダウンロード](https://dev.mysql.com/downloads/connector/odbc/) より、macOS用パッケージ（`.dmg` または `.tar.gz`）を取得します。
   - **重要**: Apple Silicon（M1/M2/M3/M4）端末では必ず **`macOS (ARM, 64-bit)`** 版を導入してください。Intel (x86_64) 版と混在するとクラッシュの原因となります。
2. **ドライバ登録確認**:
   ```bash
   myodbc-installer -d -l
   ```
   - 出力に `MySQL ODBC 8.x Unicode Driver` が表示されることを確認します。

### 4.2 DSN (`odbc.ini`) の安全な設定
`~/Library/ODBC/odbc.ini` または `/Library/ODBC/odbc.ini` に以下の設定を追加します：

```ini
[rwd_research_db]
Driver      = MySQL ODBC 8.4 Unicode Driver
Server      = 192.168.0.50
Port        = 3306
Database    = rwd_research_db
User        = rwd_readonly_user
# 【厳格ルール】Password / PWD は絶対に記載しないこと！
Option      = 3
```

> [!CAUTION]
> `odbc.ini` に `Password` または `PWD` を記述することは禁止です。Excel等からの接続時にパスワード入力ダイアログで入力するか、Keychain経由で認証を行ってください。

### 4.3 ODBC DSNの監査と疎通確認
基盤に付属の `scripts/macos/test-odbc.py` を実行して、設定と安全性を検査します：

```bash
python3 scripts/macos/test-odbc.py --dsn rwd_research_db --username rwd_readonly_user
```

- CPUアーキテクチャの一致、平文パスワードの有無、および `SELECT VERSION()` 等のメタデータ取得による疎通確認が自動実行されます。
