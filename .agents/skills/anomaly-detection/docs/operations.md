# Operations and Compliance Notes

## Audit Trail

Each batch should save:

- input snapshot hash
- schema version
- config hash
- model version
- execution timestamp
- user/service account
- output hash
- reviewer decision when available

## Run output isolation

- Prefer `python -m anomaly_detection.cli --input <path> --output-root ./skill_out/anomaly_detection` without `--output`.
- Artifacts are written to `run_<id>/anomaly_results.jsonl` (or `.csv` with `--format csv`).
- `--run-id` is optional; when omitted, a JST timestamp run id is used and collisions create `run_<id>_2`, etc.
- Legacy `--output <path>` remains supported for explicit paths (may overwrite on re-run).

## 21 CFR Part 11 Considerations

This scaffold is not a validated Part 11 system. For regulated production use, connect it to validated identity, access control, audit trail, electronic signature, change control, backup, and SOP-governed operational processes.

## Privacy

- Avoid PHI/PII in logs.
- Prefer surrogate `record_id`.
- Subject identifiers should be pseudonymized upstream.
- Store model inputs only when justified by audit/reproducibility requirements.

## Deployment

Local:

```bash
uvicorn anomaly_detection.api:app --reload
```

Docker:

```bash
docker build -f deploy/Dockerfile -t edc-rwd-anomaly-detection:0.1.0 .
docker run -p 8000:8000 edc-rwd-anomaly-detection:0.1.0
```
