# Architecture

```mermaid
flowchart TD
    A[Ingestion: CSV/JSON/ODM/API] --> B[Schema Contract]
    B --> C[Rule Engine]
    B --> D[Feature Builder]
    D --> E[Robust Statistics]
    D --> F[Isolation Forest]
    D --> G[LOF]
    C --> H[Score Fusion]
    E --> H
    F --> H
    G --> H
    H --> I[Result Normalization]
    I --> J[LLM Review Draft]
    J --> K[Human Review]
    K --> L[Reviewer Feedback Store]
    L --> M[Future Supervised Model]
```

## Components

| Component | Responsibility |
|---|---|
| `schemas.py` | Pydantic request/response contracts |
| `rules.py` | Deterministic EDC/RWD checks |
| `features.py` | Numeric/categorical preprocessing and robust MAD scores |
| `detectors.py` | Isolation Forest / LOF wrapper |
| `pipeline.py` | Multi-stage score fusion and result ranking |
| `api.py` | Optional FastAPI interface |
| `audit.py` | Config hash and execution metadata |

## Score Fusion

\[
S_i = w_r R_i + w_m M_i + w_f F_i + w_l L_i
\]

where:

- \(R_i\): deterministic rule score
- \(M_i\): robust MAD score
- \(F_i\): Isolation Forest normalized anomaly score
- \(L_i\): LOF normalized anomaly score

Default weights are defined in `configs/default.yaml`.
