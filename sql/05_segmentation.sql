-- 90-day user-level outcomes by acquisition channel.
-- The overall analysis end is exclusive: 2026-10-01 00:00:00.
-- Each user's observation window is [signup_at, signup_at + 90 days).
-- Only users whose full 90-day window ends by the analysis cutoff are eligible.
-- Stage flags are user-level "ever reached this stage" flags. With multiple applications/cards,
-- stages are not guaranteed to refer to the same application or card.
-- These are synthetic data; channel differences do not establish causal effects.

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
user_outcomes AS (
    SELECT
        u.user_id,
        u.acquisition_channel,
        EXISTS (
            SELECT 1
            FROM card_applications a
            WHERE a.user_id = u.user_id
              AND a.submitted_at >= u.signup_at
              AND a.submitted_at < u.signup_at + INTERVAL '90 days'
        ) AS has_applied,
        EXISTS (
            SELECT 1
            FROM card_applications a
            WHERE a.user_id = u.user_id
              AND a.application_status = 'approved'
              AND a.decision_at >= u.signup_at
              AND a.decision_at < u.signup_at + INTERVAL '90 days'
        ) AS has_approved_application,
        EXISTS (
            SELECT 1
            FROM cards c
            JOIN card_applications a USING (application_id)
            WHERE a.user_id = u.user_id
              AND c.issued_at >= u.signup_at
              AND c.issued_at < u.signup_at + INTERVAL '90 days'
        ) AS has_issued_card,
        EXISTS (
            SELECT 1
            FROM cards c
            JOIN card_applications a USING (application_id)
            WHERE a.user_id = u.user_id
              AND c.activated_at IS NOT NULL
              AND c.activated_at >= u.signup_at
              AND c.activated_at < u.signup_at + INTERVAL '90 days'
        ) AS has_activated_card
    FROM eligible_users u
),
channel_counts AS (
    SELECT
        acquisition_channel,
        COUNT(*) AS registered_users,
        COUNT(*) FILTER (WHERE has_applied) AS users_applied,
        COUNT(*) FILTER (WHERE has_approved_application) AS users_approved,
        COUNT(*) FILTER (WHERE has_issued_card) AS users_with_issued_card,
        COUNT(*) FILTER (WHERE has_activated_card) AS users_activated
    FROM user_outcomes
    GROUP BY acquisition_channel
)
SELECT
    acquisition_channel,
    registered_users,
    users_applied,
    users_approved,
    users_with_issued_card,
    users_activated,
    ROUND(users_applied::NUMERIC / NULLIF(registered_users, 0), 4)
        AS application_conversion_per_registered_user,
    ROUND(users_approved::NUMERIC / NULLIF(registered_users, 0), 4)
        AS approval_per_registered_user,
    ROUND(users_approved::NUMERIC / NULLIF(users_applied, 0), 4)
        AS approval_among_applicant_users,
    ROUND(users_with_issued_card::NUMERIC / NULLIF(registered_users, 0), 4)
        AS issuance_per_registered_user,
    ROUND(users_activated::NUMERIC / NULLIF(registered_users, 0), 4)
        AS activation_per_registered_user,
    ROUND(users_activated::NUMERIC / NULLIF(users_with_issued_card, 0), 4)
        AS activation_among_users_with_issued_cards
FROM channel_counts
ORDER BY registered_users DESC;
