-- Monthly in-app retention by signup cohort.
-- The analysis end is exclusive: all events before 2026-10-01 are included,
-- including fractional seconds on September 30.
-- Month 0 is the signup calendar month and can be below 100%: it measures the share
-- of the cohort with at least one tracked event after signup in that calendar month.
-- Month_index >= 1 measures activity in subsequent calendar months; this is a
-- calendar-month activity rate, not a strict day-30/day-60 retention definition.
WITH raw_params AS (
    SELECT TIMESTAMP '2026-10-01 00:00:00' AS analysis_end_exclusive
),
params AS (
    SELECT
        analysis_end_exclusive,
        DATE_TRUNC('month', analysis_end_exclusive - INTERVAL '1 microsecond')::DATE AS last_activity_month
    FROM raw_params
),
user_cohorts AS (
    SELECT
        user_id,
        signup_at,
        DATE_TRUNC('month', signup_at)::DATE AS cohort_month
    FROM users
),
cohort_sizes AS (
    SELECT cohort_month, COUNT(*) AS cohort_size
    FROM user_cohorts
    GROUP BY cohort_month
),
monthly_activity AS (
    -- One row per user and activity month. Ignore events before signup and
    -- events outside the declared analysis window.
    SELECT DISTINCT
        uc.user_id,
        uc.cohort_month,
        DATE_TRUNC('month', e.event_time)::DATE AS activity_month
    FROM user_cohorts uc
    JOIN user_events e
      ON e.user_id = uc.user_id
     AND e.event_time >= uc.signup_at
    CROSS JOIN params p
    WHERE e.event_time < p.analysis_end_exclusive
),
cohort_activity AS (
    SELECT
        ma.cohort_month,
        ma.activity_month,
        (
            (EXTRACT(YEAR FROM ma.activity_month) - EXTRACT(YEAR FROM ma.cohort_month)) * 12
            + EXTRACT(MONTH FROM ma.activity_month) - EXTRACT(MONTH FROM ma.cohort_month)
        )::INT AS month_index,
        COUNT(*) AS active_users
    FROM monthly_activity ma
    WHERE ma.activity_month >= ma.cohort_month
    GROUP BY ma.cohort_month, ma.activity_month
),
cohort_month_scaffold AS (
    -- Create every observable cohort-month combination, including months
    -- with zero active users. Do not generate months beyond the cutoff.
    SELECT
        cs.cohort_month,
        gs.activity_month::DATE AS activity_month,
        (
            (EXTRACT(YEAR FROM gs.activity_month) - EXTRACT(YEAR FROM cs.cohort_month)) * 12
            + EXTRACT(MONTH FROM gs.activity_month) - EXTRACT(MONTH FROM cs.cohort_month)
        )::INT AS month_index,
        cs.cohort_size
    FROM cohort_sizes cs
    CROSS JOIN params p
    CROSS JOIN LATERAL GENERATE_SERIES(
        cs.cohort_month::TIMESTAMP,
        p.last_activity_month::TIMESTAMP,
        INTERVAL '1 month'
    ) AS gs(activity_month)
    WHERE gs.activity_month <= p.last_activity_month
)
SELECT
    s.cohort_month,
    s.activity_month,
    s.month_index,
    s.cohort_size,
    COALESCE(ca.active_users, 0) AS active_users,
    ROUND(
        COALESCE(ca.active_users, 0)::NUMERIC / NULLIF(s.cohort_size, 0),
        4
    ) AS retention_rate
FROM cohort_month_scaffold s
LEFT JOIN cohort_activity ca
  ON ca.cohort_month = s.cohort_month
 AND ca.activity_month = s.activity_month
ORDER BY s.cohort_month, s.month_index;
