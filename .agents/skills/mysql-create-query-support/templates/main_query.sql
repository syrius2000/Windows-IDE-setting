-- Purpose: replace with the natural-language analysis goal.
-- Grain: one row per patient/event/visit/prescription/lab result.
-- Main ID: PATIENTNO.
-- Date policy: state whether the range is inclusive or half-open.

WITH base_entity AS (
    SELECT DISTINCT
        PATIENTNO
    FROM target_table
    WHERE PATIENTNO IS NOT NULL
),
event_candidates AS (
    SELECT
        PATIENTNO,
        event_date,
        event_code
    FROM event_table
    WHERE event_date >= DATE('2020-01-01')
      AND event_date < DATE('2021-01-01')
)
SELECT
    b.PATIENTNO,
    e.event_date,
    e.event_code
FROM base_entity AS b
LEFT JOIN event_candidates AS e
    ON b.PATIENTNO = e.PATIENTNO;
