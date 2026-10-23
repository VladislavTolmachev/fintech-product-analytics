-- Monthly in-app retention by signup cohort.
WITH params AS (SELECT DATE '2026-09-30' AS analysis_end),
user_cohorts AS (
    SELECT user_id, DATE_TRUNC('month',signup_at)::DATE AS cohort_month FROM users
), cohort_sizes AS (
    SELECT cohort_month, COUNT(*) AS cohort_size FROM user_cohorts GROUP BY cohort_month
), monthly_activity AS (
    SELECT DISTINCT user_id, DATE_TRUNC('month',event_time)::DATE AS activity_month FROM user_events
), cohort_activity AS (
    SELECT uc.cohort_month, ma.activity_month,
        ((EXTRACT(YEAR FROM ma.activity_month)-EXTRACT(YEAR FROM uc.cohort_month))*12
          + EXTRACT(MONTH FROM ma.activity_month)-EXTRACT(MONTH FROM uc.cohort_month))::INT AS month_index,
        COUNT(DISTINCT uc.user_id) AS active_users
    FROM user_cohorts uc JOIN monthly_activity ma USING (user_id) CROSS JOIN params p
    WHERE ma.activity_month >= uc.cohort_month
      AND ma.activity_month <= DATE_TRUNC('month',p.analysis_end)::DATE
    GROUP BY uc.cohort_month,ma.activity_month
)
SELECT ca.cohort_month,ca.activity_month,ca.month_index,cs.cohort_size,ca.active_users,
       ROUND(ca.active_users::NUMERIC/NULLIF(cs.cohort_size,0),4) AS retention_rate
FROM cohort_activity ca JOIN cohort_sizes cs USING (cohort_month)
ORDER BY ca.cohort_month,ca.month_index;