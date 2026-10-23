-- Conversion metrics with explicit entity-level denominators and observation windows.
-- Analysis end is exclusive: 2026-10-01 00:00:00.
-- Synthetic dataset only; these metrics describe this dataset, not real-world performance.

-- 1) Application approval rate as of the analysis cutoff.
-- Denominator: applications with a final decision before the cutoff.
-- Applications submitted before the cutoff but still pending at the cutoff are reported separately.
WITH params AS (
    SELECT TIMESTAMP '2026-10-01 00:00:00' AS analysis_end_exclusive
)
SELECT
    COUNT(*) FILTER (
        WHERE a.application_status IN ('approved', 'rejected')
          AND a.decision_at < p.analysis_end_exclusive
    ) AS decided_applications,
    COUNT(*) FILTER (
        WHERE a.application_status = 'approved'
          AND a.decision_at < p.analysis_end_exclusive
    ) AS approved_applications,
    COUNT(*) FILTER (
        WHERE a.application_status = 'rejected'
          AND a.decision_at < p.analysis_end_exclusive
    ) AS rejected_applications,
    COUNT(*) FILTER (
        WHERE a.application_status = 'pending'
           OR a.decision_at IS NULL
           OR a.decision_at >= p.analysis_end_exclusive
    ) AS pending_applications_as_of_cutoff,
    ROUND(
        COUNT(*) FILTER (
            WHERE a.application_status = 'approved'
              AND a.decision_at < p.analysis_end_exclusive
        )::NUMERIC
        / NULLIF(
            COUNT(*) FILTER (
                WHERE a.application_status IN ('approved', 'rejected')
                  AND a.decision_at < p.analysis_end_exclusive
            ),
            0
        ),
        4
    ) AS approval_rate_among_decided_applications
FROM card_applications a
CROSS JOIN params p
WHERE a.submitted_at < p.analysis_end_exclusive;


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


-- 3) Decision-time distribution among applications decided before the analysis cutoff.
-- Pending applications have no observed decision time and are excluded.
WITH params AS (
    SELECT TIMESTAMP '2026-10-01 00:00:00' AS analysis_end_exclusive
)
SELECT
    COUNT(*) AS decided_applications,
    COUNT(*) FILTER (WHERE a.application_status = 'approved') AS approved_applications,
    COUNT(*) FILTER (WHERE a.application_status = 'rejected') AS rejected_applications,
    ROUND(
        AVG(EXTRACT(EPOCH FROM (a.decision_at - a.submitted_at)) / 3600.0)::NUMERIC,
        2
    ) AS avg_hours_to_decision,
    ROUND(
        PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY EXTRACT(EPOCH FROM (a.decision_at - a.submitted_at)) / 3600.0
        )::NUMERIC,
        2
    ) AS median_hours_to_decision
FROM card_applications a
CROSS JOIN params p
WHERE a.application_status IN ('approved', 'rejected')
  AND a.submitted_at < p.analysis_end_exclusive
  AND a.decision_at < p.analysis_end_exclusive
  AND a.decision_at IS NOT NULL
  AND a.decision_at >= a.submitted_at;
