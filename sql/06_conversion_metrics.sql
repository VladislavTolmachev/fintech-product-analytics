-- Stage-specific denominators: applications and cards are separate entities.
SELECT COUNT(*) FILTER(WHERE application_status IN ('approved','rejected')) AS decided_applications,
       COUNT(*) FILTER(WHERE application_status='approved') AS approved_applications,
       COUNT(*) FILTER(WHERE application_status='rejected') AS rejected_applications,
       ROUND(COUNT(*) FILTER(WHERE application_status='approved')::NUMERIC /
         NULLIF(COUNT(*) FILTER(WHERE application_status IN ('approved','rejected')),0),4) AS approval_rate_among_decided
FROM card_applications;

SELECT COUNT(*) AS issued_cards,
       COUNT(*) FILTER(WHERE activated_at IS NOT NULL) AS activated_cards,
       COUNT(*) FILTER(WHERE activated_at IS NULL) AS not_yet_activated_cards,
       ROUND(COUNT(*) FILTER(WHERE activated_at IS NOT NULL)::NUMERIC/NULLIF(COUNT(*),0),4) AS activation_rate_among_issued
FROM cards;

SELECT COUNT(*) AS decided_applications,
       ROUND(AVG(EXTRACT(EPOCH FROM (decision_at-submitted_at))/3600.0)::NUMERIC,2) AS avg_hours_to_decision,
       ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (decision_at-submitted_at))/3600.0)::NUMERIC,2) AS median_hours_to_decision
FROM card_applications WHERE decision_at IS NOT NULL;