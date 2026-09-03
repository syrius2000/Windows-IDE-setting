# question config CSV 仕様

`templates/batch_runner.R` が期待する設定CSVの仕様。

## 必須列

以下の列が **すべて必須**。

- `survey_id`
- `question_id`
- `analysis_type`
- `var1`
- `var2`
- `var3`
- `output_slug`
- `question_label`
- `subset_expr`
- `na_policy`
- `ordered_levels`
- `reference_note`

## 列の使い方（主要）

- `analysis_type`: `nominal_2way` / `likert_2way` / `nominal_3way`
- `var1`,`var2`,`var3`: 入力データ列名（`var3` は2-wayでは空で可）
- `output_slug`: 各設問の出力フォルダ名
- `subset_expr`: R式のフィルタ（空なら全件）
- `na_policy`: `drop` なら欠損行を除外

## 最小例

```csv
survey_id,question_id,analysis_type,var1,var2,var3,output_slug,question_label,subset_expr,na_policy,ordered_levels,reference_note
S1,Q01,nominal_2way,sex,event,,q01,性別×事象,,drop,,
S1,Q02,nominal_3way,sex,event,age_group,q02,性別×事象×年齢層,,drop,,
```

## よくある失敗

- `var1/var2/var3` が入力CSVに存在しない
- `analysis_type` の綴りミス
- `output_slug` 重複で成果物が上書きされる
- `subset_expr` の式エラー（実装上は全件扱いにフォールバックする場合があるため要注意）
