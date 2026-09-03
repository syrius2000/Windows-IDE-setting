# 依存パッケージ

`analysis.R` および `dashboard.Rmd` を実行するためには以下の R パッケージが必要です。`pacman::p_load` によって自動的にインストール・ロードされますが、環境によっては手動でのインストールが必要になる場合があります。

## 必須パッケージ

| 区分 | パッケージ | 用途 |
| :--- | :--- | :--- |
| **必須** | `dplyr` | データ前処理（集約・整形） |
| **必須** | `tidyr` | データ整形（必要に応じて） |
| **必須** | `jsonlite` | JSON 入出力（`evidence_results.json`） |
| **必須** | `DT` | 残差・エビデンス表のインタラクティブ表示 |
| **必須** | `htmlwidgets` | DT の self-contained HTML 出力（`htmlwidgets::saveWidget`） |
| **必須** | `htmltools` | キャプション等の HTML 生成（`analysis.R` / `dashboard.Rmd`） |
| **必須** | `knitr` | `dashboard.Rmd` のチャンク・サマリー knit |
| **必須** | `rmarkdown` | `dashboard.Rmd` の HTML レンダリング |
| **必須** | `pacman` | パッケージの自動インストールとロード管理 |
| **必須** | `effectsize` | Cramér's V / Fei（効果量）の算出と信頼区間 |

## インストール方法

```r
# pacman 経由（analysis.R / dashboard.Rmd setup 内で自動実行）
if (!requireNamespace("pacman", quietly = TRUE)) install.packages("pacman")
# Pass 1
pacman::p_load(dplyr, tidyr, jsonlite, DT, htmlwidgets, htmltools, effectsize)
# ダッシュボード（Pass 3）の setup チャンク
pacman::p_load(jsonlite, DT, dplyr, htmltools, knitr, rmarkdown)
```

## 補足

- ARM（support/confidence/lift）は `analysis.R` 内で重み付き集計を自前計算するため、追加パッケージは不要です。
