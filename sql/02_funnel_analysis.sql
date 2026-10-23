-- 90-day user-level funnel from signup.
-- Analysis end is exclusive: 2026-10-01 00:00:00.
-- Eligible users have a complete [signup_at, signup_at + 90 days) observation window.
-- Stage flags mean "ever reached this stage" at user level. If a user has multiple
-- applications/cards, the stages may refer to different application/card records.
-- All data is synthetic; this is descriptive, not causal analysis.

WITH params AS (
    SELECT TIMESTAMP '2026-10-01 00:00:00' AS analysis_end_exclusive,
           INTERVAL '90 days' AS observation_window
),
eligible_users AS (
    SELECT u.user_id, u.signup_at, u.acquisition_channel
    FROM users u
    CROSS JOIN params p
    WHERE u.signup_at + p.observation_window <= p.analysis_end_exclusive
),
outcomes AS (
    SELECT
        eu.user_id,
        eu.acquisition_channel,
        EXISTS (
            SELECT 1
            FROM card_applications a
            WHERE a.user_id = eu.user_id
              AND a.submitted_at >= eu.signup_at
              AND a.submitted_at < eu.signup_at + INTERVAL '90 days'
        ) AS applied,
        EXISTS (
            SELECT 1
            FROM card_applications a
            WHERE a.user_id = eu.user_id
              AND a.application_status = 'approved'
              AND a.decision_at >= eu.signup_at
              AND a.decision_at < eu.signup_at + INTERVAL '90 days'
        ) AS approved,
        EXISTS (
            SELECT 1
            FROM cards c
            JOIN card_applications a USING (application_id)
            WHERE a.user_id = eu.user_id
              AND c.issued_at >= eu.signup_at
              AND c.issued_at < eu.signup_at + INTERVAL '90 days'
        ) AS card_issued,
        EXISTS (
            SELECT 1
            FROM cards c
            JOIN card_applications a USING (application_id)
            WHERE a.user_id = eu.user_id
              AND c.activated_at IS NOT NULL
              AND c.activated_at >= eu.signup_at
              AND c.activated_at < eu.signup_at + INTERVAL '90 days'
        ) AS card_activated
    FROM eligible_users eu
),
counts AS (
    SELECT
        COUNT(*) AS registered_users,
        COUNT(*) FILTER (WHERE applied) AS applied_users,
        COUNT(*) FILTER (WHERE approved) AS approved_users,
        COUNT(*) FILTER (WHERE card_issued) AS issued_users,
        COUNT(*) FILTER (WHERE card_activated) AS activated_users
    FROM outcomes
),
stages AS (
    SELECT 1 AS stage_order, 'registered' AS funnel_stage, registered_users AS users FROM counts
    UNION ALL SELECT 2, 'applied', applied_users FROM counts
    UNION ALL SELECT 3, 'approved', approved_users FROM counts
    UNION ALL SELECT 4, 'card_issued', issued_users FROM counts
    UNION ALL SELECT 5, 'card_activated', activated_users FROM counts
),
with_previous AS (
    SELECT
        *,
        LAG(users) OVER (ORDER BY stage_order) AS previous_stage_users
    FROM stages
)
SELECT
    funnel_stage,
    users,
    ROUND(
        users::NUMERIC / NULLIF((SELECT registered_users FROM counts), 0),
        4
    ) AS conversion_from_signup,
    ROUND(
        users::NUMERIC / NULLIF(previous_stage_users, 0),
        4
    ) AS conversion_from_previous_stage
FROM with_previous
ORDER BY stage_order;
