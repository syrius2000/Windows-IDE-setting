# Windows 11 初回セットアップ Troubleshoot（実機検証メモ）

macOS で開発された本リポジトリを、**初めて Windows 11 実機**で通したときの原因メモです。  
症状 → 原因 → 恒久対策の順で簡潔に記載します。

関連手順: [windows-bootstrap-guide.md](windows-bootstrap-guide.md)

---

## 1. 文字コード（UTF-8 BOM / cmd の `&`）

| 症状 | `'AI' is not recognized`、日本語が化けて PowerShell 構文エラー |
| 原因 | `.bat` の `&` がコマンド区切りと解釈された。`.ps1` が BOM なし UTF-8 のため、Windows PowerShell 5.1 が CP932 として誤読した |
| 対策 | `Setup-Windows.bat` と `scripts/windows/*.ps1` / `scripts/project/*.ps1` は **UTF-8（BOM あり）**。`Assert-Utf8Bom.ps1` で検査。`AGENTS.md` に例外を明記 |

## 2. PowerShell 構文（`$name:` / `.Count`）

| 症状 | `Variable reference is not valid` / `property 'Count' cannot be found` |
| 原因 | `"$name: $_"` がドライブ修飾変数と誤認。`Get-ChildItem` が1件のとき StrictMode 下で `.Count` 不可 |
| 対策 | `${name}:` を使う。`@(Get-ChildItem ...)` で常に配列化 |

## 3. WinGet パッケージ ID（rig）

| 症状 | `入力条件に一致するパッケージが見つかりませんでした` → R / rig 失敗 |
| 原因 | 誤 ID `RProject.rig`（存在しない）。正は `Posit.rig` |
| 対策 | `02-install-analysis.ps1` を `Posit.rig` に修正。GitHub インストーラへフォールバック。Rtools は `rig add rtools` |

## 4. 7-Zip「失敗」だが実は導入済み

| 症状 | WinGet 終了コード `-1978335189` で Step 1 失敗 |
| 原因 | `7z.exe` は導入済みだが PATH 未登録。WinGet は「アップグレード不要」を非 0 で返す |
| 対策 | 定番パスも検出。当該終了コードを成功扱い。任意パッケージは致命にしない |

## 5. リポジトリルート解決（Template / schema）

| 症状 | `scripts\templates\...` 未検出。`schemas\project.schema.json` 未検出 |
| 原因 | `New-AnalysisProject.ps1` が `scripts/` をルートと誤認（macOS は `../..`）。検証が `--schema` 未指定 |
| 対策 | `copier.yml` まで親を探索。ログはリポジトリ `.run/`。検証はプラットフォーム schema を明示。Case に schema を同梱 |

## 6. 対話 CLI ハング / 重い `uv run`

| 症状 | DuckDB の `.help` 待ちで停止。Python 検証が長時間無応答 |
| 原因 | パラメータ名 `$args`（予約変数）で `--version` が落ち、`duckdb` が対話起動。`uv run` が pyproject 全体（polars 等）を初回取得 |
| 対策 | `$args` 禁止。バージョン確認は非対話のみ。検証は `uv run --no-project --with ...`。タイムアウト付き実行 |

## 7. Git ignore 判定（CRLF）

| 症状 | `outputs/private/` / `.run/` が ignore されていないと誤判定 |
| 原因 | Windows で `subprocess` の `\n` → `\r\n` 変換により `git check-ignore` が不一致 |
| 対策 | stdin を bytes で渡し、結果パスを正規化（`validate-project.py`） |

## 8. 検証の終了コード取りこぼし / pnpm

| 症状 | 中身は PASS なのに全体 FAIL。または Step 05 が即終了コード 2 |
| 原因 | `Start-Process` の ExitCode 不安定。pnpm が拡張子なしシムで `%1 is not a valid Win32 application`。非同期出力ハンドラが不安定 |
| 対策 | `&` + `$LASTEXITCODE` で厳格判定（文字列 PASS では通さない）。`.cmd`/`.exe` を優先。PPTX 未生成は FAIL |

## 9. TEMP ロック / Cursor 自動起動

| 症状 | 再実行時に生成先が空でない / Count 例外 |
| 原因 | 検証が Cursor を開き TEMP をロック |
| 対策 | `-NonInteractive` では Cursor 起動しない。TEMP 削除失敗時は別名ディレクトリへ |

---

## 合格の定義（緩めない）

- ツール確認・E2E は **プロセス終了コード 0** を必須とする  
- 表示文言の「PASS」だけで成功にしない  
- Windows 固有の起動・文字コード問題は「計測・起動方法」を直し、検査項目自体は下げない  

最終的に本環境では `.run/reports/verify-report.json` が **status: PASS** となることを確認済みです。

---

## 10. Git 身元未設定で初回コミットがスキップされる

| 症状 | Case Project 生成は成功するが Initial commit が作られない |
| 原因 | `git config user.name` / `user.email` 未設定 |
| 対策 | `00-diagnose.ps1` が WARN。グローバルに設定してから再生成、または手動コミット |

---

## CI で見るもの / ローカル E2E で見るもの

| 層 | 内容 | 実行場所 |
|---|---|---|
| **Windows static gate (CI)** | UTF-8 BOM 検査、全 `scripts/**/*.ps1` 構文パース、`Posit.rig` 文字列ゲート | GitHub Actions `windows-latest`（`.github/workflows/windows-static-gate.yml`） |
| **ローカル E2E** | `Setup-Windows.bat` → 診断〜導入〜`05-verify.ps1`（管理者・WinGet 依存） | 実機 Win11 のみ。CI では回さない |

### macOS で Windows 用スクリプトを触ったとき

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\windows\Assert-Utf8Bom.ps1
```

BOM が欠けると Windows PowerShell 5.1 で再発します。CI の static gate が最終防衛線です。
