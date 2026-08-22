-- =============================================================================
-- Sample Cohort Extraction SQL Query Template (MySQL 8.0 / DuckDB)
-- 注意: 実クエリ実行時は認証情報をハードコードせず、Keychainまたはローカル設定を参照すること
-- =============================================================================

SELECT
    c.patient_id,
    c.age,
    c.sex,
    c.treatment_arm,
    c.followup_days,
    c.event_occurred
FROM
    cohort_patients AS c
WHERE
    c.age >= 18
    AND c.followup_days > 0
ORDER BY
    c.patient_id;
