-- First successful purchase after card activation; includes cards with no purchase.
WITH first_purchase AS (
    SELECT card_id, MIN(transaction_at) AS first_purchase_at
    FROM transactions
    WHERE transaction_type='purchase' AND transaction_status='completed'
    GROUP BY card_id
), activated_cards AS (
    SELECT c.card_id, c.activated_at, fp.first_purchase_at
    FROM cards c LEFT JOIN first_purchase fp USING (card_id)
    WHERE c.activated_at IS NOT NULL
)
SELECT card_id, activated_at, first_purchase_at,
       first_purchase_at - activated_at AS time_to_first_purchase,
       EXTRACT(EPOCH FROM (first_purchase_at-activated_at))/3600.0 AS hours_to_first_purchase,
       (first_purchase_at IS NOT NULL) AS made_successful_purchase
FROM activated_cards
WHERE first_purchase_at IS NULL OR first_purchase_at >= activated_at
ORDER BY hours_to_first_purchase NULLS LAST;

WITH first_purchase AS (
    SELECT card_id, MIN(transaction_at) AS first_purchase_at
    FROM transactions
    WHERE transaction_type='purchase' AND transaction_status='completed'
    GROUP BY card_id
), durations AS (
    SELECT EXTRACT(EPOCH FROM (fp.first_purchase_at-c.activated_at))/3600.0 AS hours
    FROM cards c JOIN first_purchase fp USING (card_id)
    WHERE c.activated_at IS NOT NULL AND fp.first_purchase_at >= c.activated_at
)
SELECT COUNT(*) AS cards_with_successful_purchase,
       ROUND(AVG(hours)::NUMERIC,2) AS avg_hours_to_first_purchase,
       ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY hours)::NUMERIC,2) AS median_hours_to_first_purchase
FROM durations;