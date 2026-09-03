# Interpretation Guide

## Read order for beginners

1. Check `summary.csv` for `p_value`, `effect_value`, `max_abs_pearson_res`, and `status`.
2. Open each question's `report.html`.
3. Review `residual_plot.png` when it exists. Positive residuals mean observed counts are larger than model expectation. Negative residuals mean observed counts are smaller than model expectation.
4. Use `summary.csv` to compare patterns across questions.

## Practical tips

- If `p_value` is small but `effect_value` is tiny, practical impact may be weak.
- In 3-way analyses, review subgroup patterns before making conclusions.
- Always report top residual cells with plain language labels.
