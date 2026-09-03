# 文献・パッケージ参照リスト

## 1. 主要文献

| 著者 | タイトル | 年 | 関連トピック |
| :--- | :--- | :--- | :--- |
| Agresti, A. | *Categorical Data Analysis* (3rd ed.) | 2013 | 対数線形モデル、Poisson GLM |
| Meyer, D. et al. | *Visualizing Categorical Data* (vcd vignette) | — | モザイクプロット、Pearson 残差 |
| Friendly, M. | *Mosaic Displays for Loglinear Models* | 1994 | モザイク図の解釈 |
| Zeileis, A. et al. | *Residual-based Shadings for Visualizing* | 2007 | 残差の可視化（`vcd` 論文） |

## 2. R パッケージ詳細

### vcd（カテゴリカルデータ可視化）

```r
# モザイクプロット（残差のシェーディング付き）
vcd::mosaic(tab, shade = TRUE)

# アソシエーションプロット（2-way 専用）
vcd::assoc(tab, residuals_type = "Pearson", shade = TRUE)

# 条件付きモザイクプロット（3-way）
vcd::cotabplot(tab, panel = vcd::cotab_mosaic, shade = TRUE)

# 連関統計量（χ²、Cramér's V、Phi 等）
vcd::assocstats(tab)
```

### gt（テーブル作成）

```r
# 残差マトリックスの色付き表
gt::gt(data) |>
  gt::data_color(domain = c(-mx, mx), palette = c("#D73027", "#FFFFFF", "#4575B4")) |>
  gt::gtsave("output.html")
```

### DT（インタラクティブテーブル）

```r
# ソート・フィルタ可能テーブル
DT::datatable(df, filter = "top", options = list(pageLength = 50)) |>
  DT::formatRound(columns = c("pearson_res"), digits = 3) |>
  DT::formatStyle("pearson_res", backgroundColor = DT::styleInterval(brks, clrs))

# self-contained HTML として保存
htmlwidgets::saveWidget(widget, "output.html", selfcontained = TRUE)
```

### jsonlite（JSON 入出力）

```r
# 書き込み（null 値を明示的に出力）
jsonlite::write_json(obj, path, auto_unbox = TRUE, pretty = TRUE, null = "null")

# 読み込み
raw <- jsonlite::read_json(path)
```

## 3. 関連ドキュメント

- `references/glm-gnm-goodness.md` — モデル適合度・残差解釈の詳細
- `references/ordinal-likert-advanced.md` — 序数変数の取り扱い
- `references/interface.md` — 共有契約（スキル間インターフェース）
