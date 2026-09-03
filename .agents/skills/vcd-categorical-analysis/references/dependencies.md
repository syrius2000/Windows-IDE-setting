# 依存パッケージ

`analysis.R` を実行するためには以下の R パッケージが必要です。`pacman::p_load` によって自動的にインストール・ロードされますが、環境によっては手動でのインストールが必要になる場合があります。

## 必須パッケージ

| 区分 | パッケージ | 用途 |
| :--- | :--- | :--- |
| **必須** | `vcd` | カテゴリカルデータの可視化（Mosaic, Association プロット）、Cramer's V |
| **必須** | `gt` | 残差マトリックス表の作成（HTML） |
| **必須** | `DT` | ソート可能インタラクティブ残差テーブル（`DT::datatable`） |
| **必須** | `htmlwidgets` | DT の self-contained HTML 出力（`htmlwidgets::saveWidget`） |
| **必須** | `ggplot2` | 補助的なプロット作成 |
| **必須** | `jsonlite` | JSON 形式の入出力（profile / config / summary） |
| **必須** | `pacman` | パッケージの自動インストールとロード管理 |

## インストール方法

```r
# pacman 経由（analysis.R 内で自動実行）
if (!requireNamespace("pacman", quietly = TRUE)) install.packages("pacman")
pacman::p_load(vcd, gt, DT, htmlwidgets, ggplot2, jsonlite)
```

## Rmd 向け追記

`report.Rmd`（レガシー v1.x）を使用する場合は追加で以下が必要です：

| パッケージ | 用途 |
| :--- | :--- |
| `rmarkdown` | Rmd のレンダリング |
| `knitr` | コードチャンク実行 |
