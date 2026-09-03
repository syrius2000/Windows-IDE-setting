# Test Plan

## Unit Tests

- schema validation
- deterministic rules
- robust statistics
- score fusion

## Integration Tests

- CSV -> pipeline -> JSONL
- synthetic anomaly injection -> top-ranked result

## EDC/RWD Scenario Tests

| Scenario | Injection | Expected |
|---|---|---|
| Required missing | `site_id = null` | missing flag |
| Duplicate | same `study_id+site_id+subject_id+visit_date+form_name` | duplicate flag |
| Temporal inconsistency | `recorded_at < visit_date` | temporal flag |
| Implausible value | negative age or extreme BP | range flag |
| Site drift | shift distribution for one site | high model score |

## Evaluation Metrics

- top-k precision
- PR-AUC if labels exist
- recall for critical known issues
- false positive review cost
- detection delay for near-real-time use
