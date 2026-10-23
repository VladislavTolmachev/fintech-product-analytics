-- Run after generating and loading synthetic data.
-- Each query should return zero rows unless the comment says otherwise.

SELECT user_id, COUNT(*) AS row_count FROM users GROUP BY user_id HAVING COUNT(*) > 1;

SELECT a.application_id, a.user_id, u.signup_at, a.submitted_at
FROM card_applications a JOIN users u USING (user_id)
WHERE a.submitted_at < u.signup_at;

SELECT c.card_id, a.application_id, a.application_status
FROM cards c JOIN card_applications a USING (application_id)
WHERE a.application_status <> 'approved';

SELECT t.transaction_id, t.transaction_at, c.issued_at
FROM transactions t JOIN cards c USING (card_id)
WHERE t.transaction_at < c.issued_at;

SELECT t.transaction_id, t.transaction_at, c.activated_at
FROM transactions t JOIN cards c USING (card_id)
WHERE c.activated_at IS NOT NULL AND t.transaction_at < c.activated_at;

SELECT application_id, application_status, decision_at
FROM card_applications
WHERE (application_status = 'pending' AND decision_at IS NOT NULL)
   OR (application_status IN ('approved', 'rejected') AND decision_at IS NULL);

SELECT a.application_id FROM card_applications a
LEFT JOIN users u USING (user_id) WHERE u.user_id IS NULL;

SELECT e.event_id, e.user_id, u.signup_at, e.event_time
FROM user_events e JOIN users u USING (user_id)
WHERE e.event_time < u.signup_at;

SELECT card_id, card_status, activated_at FROM cards
WHERE (card_status = 'issued' AND activated_at IS NOT NULL)
   OR (card_status IN ('active', 'blocked', 'closed') AND activated_at IS NULL);