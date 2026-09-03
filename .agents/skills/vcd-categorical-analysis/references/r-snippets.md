# R コードスニペット集

`analysis.R` の各関数で使用する典型的なコードパターンをまとめたリファレンス。

## 1. データ読み込みと前処理

```r
# UTF-8 CSV の読み込み（列名・文字列の trimws）
df <- read.csv("data.csv", fileEncoding = "UTF-8", stringsAsFactors = FALSE)
names(df) <- trimws(names(df))
for (v in vars) df[[v]] <- trimws(df[[v]])

# 非集計データの自動集計
tab <- table(df[, vars, drop = FALSE])
df_agg <- as.data.frame(tab)

# 因子化と droplevels
df[[v]] <- droplevels(factor(df[[v]]))
```

## 2. クロス表の作成

```r
# xtabs による度数クロス表
tab <- xtabs(as.formula(paste(freq_col, "~", paste(vars, collapse = " + "))), data = df)

# 周辺表（2-way の場合）
margin.table(tab, c(1, 2))

# 疎密度の計算
n_nonzero <- sum(as.vector(tab) > 0)
sparsity  <- n_nonzero / prod(dim(tab))
```

## 3. Poisson GLM フィッティング

```r
# 主効果モデル
fit_main <- glm(Freq ~ A + B + C, family = poisson, data = df)

# 2-way 交互作用モデル
fit_2way <- glm(Freq ~ (A + B + C)^2, family = poisson, data = df)

# 飽和モデル
fit_sat <- glm(Freq ~ A * B * C, family = poisson, data = df)

# モデル比較（Deviance 検定）
anova(fit_main, fit_2way, fit_sat, test = "Chisq")

# Pearson 残差の取得
df$pearson_res     <- residuals(fit_main, type = "pearson")
df$abs_pearson_res <- abs(df$pearson_res)
```

## 4. 水準集約（apply_aggregation パターン）

```r
# collapse_below_n: 合計度数が閾値以下の水準を "Other" に集約
freq_by_level <- tapply(df[[freq_col]], df[[v]], sum, na.rm = TRUE)
minor_levels  <- names(freq_by_level[freq_by_level <= threshold])
df[[v]] <- ifelse(df[[v]] %in% minor_levels, "Other", as.character(df[[v]]))

# max_levels_per_var: 上位 K 水準のみ残し他は "Other"
sorted_levels <- names(sort(freq_by_level, decreasing = TRUE))
keep_levels   <- head(sorted_levels, K)
df[[v]] <- ifelse(df[[v]] %in% keep_levels, as.character(df[[v]]), "Other")
```

## 5. gt 残差マトリックス

```r
# ピボット（wide format）
agg  <- aggregate(pearson_res ~ A + B, data = sub_df, FUN = mean, na.rm = TRUE)
wide <- reshape(agg, idvar = "A", timevar = "B", direction = "wide")
names(wide) <- gsub("^pearson_res\\.", "", names(wide))

# gt テーブル + 色付き + 有意セル太枠
mx <- max(abs(unlist(wide[, -1])), na.rm = TRUE)
tbl <- gt::gt(wide, rowname_col = "A") |>
  gt::fmt_number(decimals = 3) |>
  gt::data_color(
    columns = names(wide)[-1],
    domain  = c(-mx, mx),
    palette = c("#D73027", "#FFFFFF", "#4575B4")
  ) |>
  gt::tab_style(
    style     = gt::cell_borders(sides = "all", weight = gt::px(2), color = "#333333"),
    locations = gt::cells_body(
      columns = names(wide)[-1],
      rows    = apply(wide[, -1], 1, function(r) any(abs(r) >= 1.96, na.rm = TRUE))
    )
  )
gt::gtsave(tbl, "output.html")
```

## 6. DT インタラクティブテーブル

```r
# スタイル付き DT + self-contained HTML 保存
brks   <- seq(-mx, mx, length.out = 100)
clrs   <- colorRampPalette(c("#D73027", "#FFFFFF", "#4575B4"))(100)

widget <- DT::datatable(dt_df,
  filter  = "top",
  options = list(pageLength = 50, dom = "lftipr")
) |>
  DT::formatRound(columns = c("pearson_res", "abs_pearson_res"), digits = 3) |>
  DT::formatStyle("pearson_res", backgroundColor = DT::styleInterval(brks[-1], clrs))

htmlwidgets::saveWidget(widget, normalizePath("output.html"), selfcontained = TRUE)
```

## 7. PNG プロット出力

```r
# モザイクプロット
png("mosaic.png", width = 1000, height = 800)
vcd::mosaic(tab, shade = TRUE, main = "Mosaic Plot")
dev.off()

# アソシエーションプロット（2-way）
png("assoc.png", width = 1000, height = 800)
vcd::assoc(tab, residuals_type = "Pearson", shade = TRUE)
dev.off()

# 条件付きモザイクプロット（3-way）
png("cotab.png", width = 1000, height = 800)
vcd::cotabplot(tab, panel = vcd::cotab_mosaic, shade = TRUE)
dev.off()
```

## 8. JSON の読み書き

```r
# 書き込み（null を明示的に出力）
jsonlite::write_json(obj, "output.json",
  auto_unbox = TRUE, pretty = TRUE, null = "null")

# 読み込み
raw <- jsonlite::read_json("render_config.json")
```
