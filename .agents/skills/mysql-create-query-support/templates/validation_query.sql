-- Validation SQL for main_query.sql.
-- Run these checks before moving SQL from sql/drafts/ to sql/validated/.

WITH result AS (
    SELECT *
    FROM analysis_dataset_view_or_subquery
)
SELECT
    COUNT(*) AS n_rows,
    COUNT(DISTINCT PATIENTNO) AS n_patients,
    SUM(CASE WHEN PATIENTNO IS NULL THEN 1 ELSE 0 END) AS n_missing_patient_id,
    MIN(event_date) AS min_event_date,
    MAX(event_date) AS max_event_date
FROM result;

-- Duplicate check. Adjust columns to match the intended grain.
WITH result AS (
    SELECT *
    FROM analysis_dataset_view_or_subquery
)
SELECT
    PATIENTNO,
    event_date,
    event_code,
    COUNT(*) AS n
FROM result
GROUP BY
    PATIENTNO,
    event_date,
    event_code
HAVING COUNT(*) > 1
ORDER BY n DESC
LIMIT 50;

-- Category value check. Replace event_code with the target categorical column.
WITH result AS (
    SELECT *
    FROM analysis_dataset_view_or_subquery
)
SELECT
    event_code,
    COUNT(*) AS n
FROM result
GROUP BY event_code
ORDER BY n DESC
LIMIT 100;
