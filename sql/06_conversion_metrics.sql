-- Conversion metrics with explicit entity-level denominators and observation windows.
-- Analysis end is exclusive: 2026-10-01 00:00:00.
-- Synthetic dataset only; these metrics describe this dataset, not real-world performance.

-- 1) Application approval rate.
-- Denominator: applications with a final decision (approved or rejected).
-- Pending applications are excluded from the rate and reported separately.
SELECT
    COUNT(*) FILTER (
        WHERE application_status IN ('approved', 'rejected')
    ) AS decided_applications,
    COUNT(*) FILTER (
        WHERE application_status = 'approved'
    ) AS approved_applications,
    COUNT(*) FILTER (
        WHERE application_status = 'rejected'
    ) AS rejected_applications,
    COUNT(*) FILTER (
        WHERE application_status = 'pending'
    ) AS pending_applications,
    ROUND(
        COUNT(*) FILTER (WHERE application_status = 'approved')::NUMERIC
        / NULLIF(
            COUNT(*) FILTER (WHERE application_status IN ('approved', 'rejected')),
            0
        ),
        4
    ) AS approval_rate_among_decided_applications
FROM card_applications;


-- 2) D30 card activation rate.
-- Denominator: cards issued early enough to have a complete 30-day follow-up
-- before the analysis end. Activation must occur in [issued_at, issued_at + 30 days).
-- This avoids penalizing recently issued cards for having less time to activate.
WITH params AS (
    SELECT TIMESTAMP '2026-10-01 00:00:00' AS analysis_end_exclusive
),
eligible_cards AS (
    SELECT c.card_id, c.issued_at, c.activated_at
    FROM cards c
    CROSS JOIN params p
    WHERE c.issued_at + INTERVAL '30 days' <= p.analysis_end_exclusive
      AND c.issued_at < p.analysis_end_exclusive
),
card_activation_outcomes AS (
    SELECT
        card_id,
        issued_at,
        activated_at,
        (
            activated_at IS NOT NULL
            AND activated_at >= issued_at
            AND activated_at < issued_at + INTERVAL '30 days'
        ) AS activated_within_d30
    FROM eligible_cards
)
SELECT
    COUNT(*) AS eligible_issued_cards_with_full_d30_follow_up,
    COUNT(*) FILTER (WHERE activated_within_d30) AS cards_activated_within_d30,
    COUNT(*) FILTER (
        WHERE activated_at IS NULL OR activated_at >= issued_at + INTERVAL '30 days'
    ) AS cards_not_activated_within_d30,
    ROUND(
        COUNT(*) FILTER (WHERE activated_within_d30)::NUMERIC
        / NULLIF(COUNT(*), 0),
        4
    ) AS d30_activation_rate_among_eligible_issued_cards
FROM card_activation_outcomes;


-- 3) Decision-time distribution among decided applications.
-- Pending applications have no observed decision time and are reported separately
-- in section 1 rather than being treated as zero-duration decisions.
SELECT
    COUNT(*) AS decided_applications,
    COUNT(*) FILTER (WHERE application_status = 'approved') AS approved_applications,
    COUNT(*) FILTER (WHERE application_status = 'rejected') AS rejected_applications,
    ROUND(
        AVG(EXTRACT(EPOCH FROM (decision_at - submitted_at)) / 3600.0)::NUMERIC,
        2
    ) AS avg_hours_to_decision,
    ROUND(
        PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY EXTRACT(EPOCH FROM (decision_at - submitted_at)) / 3600.0
        )::NUMERIC,
        2
    ) AS median_hours_to_decision
FROM card_applications
WHERE application_status IN ('approved', 'rejected')
  AND decision_at IS NOT NULL
  AND decision_at >= submitted_at;
