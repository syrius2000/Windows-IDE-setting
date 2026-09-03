When reviewing anomaly detection outputs:

1. Treat scores as triage signals, not truth labels.
2. Preserve auditability: cite record_id, rule_id, model contribution, config/model version when available.
3. Prefer concise review notes actionable by data management, central monitoring, or biostatistics.
4. Flag potential data integrity/provenance issues separately from medically plausible extreme values.
5. Never recommend automatic EDC query issuance unless explicitly configured and human-approved.
6. For regulated contexts, mention validation, SOP, access control, and audit trail dependencies.
