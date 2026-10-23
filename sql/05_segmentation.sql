-- 90-day outcomes by acquisition channel.
WITH params AS (
    SELECT TIMESTAMP '2026-09-30 23:59:59' AS analysis_cutoff, INTERVAL '90 days' AS observation_window
), eligible_users AS (
    SELECT u.* FROM users u CROSS JOIN params p
    WHERE u.signup_at+p.observation_window<=p.analysis_cutoff
), user_outcomes AS (
    SELECT u.user_id,u.acquisition_channel,
        EXISTS(SELECT 1 FROM card_applications a WHERE a.user_id=u.user_id AND a.submitted_at<=u.signup_at+INTERVAL '90 days') AS has_applied,
        EXISTS(SELECT 1 FROM card_applications a WHERE a.user_id=u.user_id AND a.application_status='approved' AND a.decision_at<=u.signup_at+INTERVAL '90 days') AS has_approved_application,
        EXISTS(SELECT 1 FROM cards c JOIN card_applications a USING(application_id) WHERE a.user_id=u.user_id AND c.issued_at<=u.signup_at+INTERVAL '90 days') AS has_issued_card,
        EXISTS(SELECT 1 FROM cards c JOIN card_applications a USING(application_id) WHERE a.user_id=u.user_id AND c.activated_at IS NOT NULL AND c.activated_at<=u.signup_at+INTERVAL '90 days') AS has_activated_card
    FROM eligible_users u
)
SELECT acquisition_channel,COUNT(*) AS registered_users,
       COUNT(*) FILTER(WHERE has_applied) AS users_applied,
       COUNT(*) FILTER(WHERE has_approved_application) AS users_approved,
       COUNT(*) FILTER(WHERE has_issued_card) AS users_with_issued_card,
       COUNT(*) FILTER(WHERE has_activated_card) AS users_activated,
       ROUND(COUNT(*) FILTER(WHERE has_applied)::NUMERIC/NULLIF(COUNT(*),0),4) AS application_conversion,
       ROUND(COUNT(*) FILTER(WHERE has_approved_application)::NUMERIC/NULLIF(COUNT(*),0),4) AS approval_per_registered_user,
       ROUND(COUNT(*) FILTER(WHERE has_activated_card)::NUMERIC/NULLIF(COUNT(*),0),4) AS activation_per_registered_user
FROM user_outcomes GROUP BY acquisition_channel ORDER BY registered_users DESC;