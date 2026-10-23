-- Activation-to-first-purchase analysis (PostgreSQL).
-- Observation window is [activation time, 2026-10-01 00:00:00).
-- D30 means a successful purchase in [activated_at, activated_at + 30 days).
-- Only cards activated on or before 2026-09-01 00:00:00 have a complete D30 window.
-- Mean/median time-to-purchase below are conditional on a successful purchase within D30.
-- This file contains three result sets: card-level detail, D30 summary, and a data-quality check.

WITH params AS (
    SELECT
        TIMESTAMP '2026-10-01 00:00:00' AS analysis_end_exclusive
),
first_purchase_after_activation AS (
    SELECT
        c.card_id,
        c.activated_at,
        MIN(t.transaction_at) AS first_purchase_at
    FROM cards c
    CROSS JOIN params p
    LEFT JOIN transactions t
      ON t.card_id = c.card_id
     AND t.transaction_type = 'purchase'
     AND t.transaction_status = 'completed'
     AND t.transaction_at >= c.activated_at
     AND t.transaction_at < p.analysis_end_exclusive
    WHERE c.activated_at IS NOT NULL
    GROUP BY c.card_id, c.activated_at
)
SELECT
    card_id,
    activated_at,
    first_purchase_at,
    first_purchase_at - activated_at AS time_to_first_purchase,
    ROUND(
        (EXTRACT(EPOCH FROM (first_purchase_at - activated_at)) / 3600.0)::NUMERIC,
        2
    ) AS hours_to_first_purchase,
    (first_purchase_at IS NOT NULL) AS made_successful_purchase_by_analysis_end
FROM first_purchase_after_activation
ORDER BY hours_to_first_purchase NULLS LAST, card_id;


-- D30 conversion and time-to-first-purchase among cards with a complete 30-day
-- observation window. Cards without a successful purchase remain in the denominator.
WITH params AS (
    SELECT TIMESTAMP '2026-10-01 00:00:00' AS analysis_end_exclusive
),
eligible_cards AS (
    SELECT c.card_id, c.activated_at
    FROM cards c
    CROSS JOIN params p
    WHERE c.activated_at IS NOT NULL
      AND c.activated_at + INTERVAL '30 days' <= p.analysis_end_exclusive
),
first_purchase_d30 AS (
    SELECT
        ec.card_id,
        ec.activated_at,
        MIN(t.transaction_at) AS first_purchase_at
    FROM eligible_cards ec
    LEFT JOIN transactions t
      ON t.card_id = ec.card_id
     AND t.transaction_type = 'purchase'
     AND t.transaction_status = 'completed'
     AND t.transaction_at >= ec.activated_at
     AND t.transaction_at < ec.activated_at + INTERVAL '30 days'
    GROUP BY ec.card_id, ec.activated_at
)
SELECT
    COUNT(*) AS eligible_activated_cards,
    COUNT(*) FILTER (WHERE first_purchase_at IS NOT NULL) AS cards_with_purchase_d30,
    ROUND(
        COUNT(*) FILTER (WHERE first_purchase_at IS NOT NULL)::NUMERIC
        / NULLIF(COUNT(*), 0),
        4
    ) AS d30_purchase_conversion_rate,
    ROUND(
        AVG(EXTRACT(EPOCH FROM (first_purchase_at - activated_at)) / 3600.0)
            FILTER (WHERE first_purchase_at IS NOT NULL)::NUMERIC,
        2
    ) AS avg_hours_to_first_purchase_among_d30_converters,
    ROUND(
        PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY EXTRACT(EPOCH FROM (first_purchase_at - activated_at)) / 3600.0
        ) FILTER (WHERE first_purchase_at IS NOT NULL)::NUMERIC,
        2
    ) AS median_hours_to_first_purchase_among_d30_converters
FROM first_purchase_d30;


-- Data-quality check: successful purchases timestamped before card activation.
-- These rows are deliberately not used as the first post-activation purchase.
SELECT
    COUNT(*) AS successful_purchases_before_activation,
    COUNT(DISTINCT t.card_id) AS affected_cards
FROM transactions t
JOIN cards c USING (card_id)
WHERE t.transaction_type = 'purchase'
  AND t.transaction_status = 'completed'
  AND c.activated_at IS NOT NULL
  AND t.transaction_at < c.activated_at;
