# API Reference

## POST `/detect`

### Request

```json
{
  "study_id": "STUDY-001",
  "batch_id": "2026-07-02T010000Z",
  "mode": "batch",
  "return_explanations": true,
  "records": [
    {
      "record_id": "row-1",
      "values": {
        "subject_id": "SUBJ-0001",
        "site_id": "SITE-001",
        "visit_date": "2026-06-01",
        "recorded_at": "2026-06-03",
        "form_name": "LAB",
        "age": 61,
        "sbp": 128,
        "dbp": 79
      },
      "metadata": {
        "source": "EDC",
        "schema_version": "1.0"
      }
    }
  ]
}
```

### Response

```json
{
  "study_id": "STUDY-001",
  "batch_id": "2026-07-02T010000Z",
  "results": [
    {
      "record_id": "row-1",
      "score": 0.12,
      "label": "normal",
      "triggered_rules": [],
      "model_contributions": {
        "rule_score": 0.0,
        "robust_mad": 0.1,
        "iforest": 0.2,
        "lof": 0.1
      },
      "explanation": "Overall anomaly score=0.120, label=normal..."
    }
  ],
  "summary": {
    "n_records": 1,
    "n_returned": 1,
    "n_warning_or_critical": 0
  }
}
```

## CLI

```bash
python scripts/infer.py --input data/synthetic_edc.csv --output outputs/results.jsonl
```
