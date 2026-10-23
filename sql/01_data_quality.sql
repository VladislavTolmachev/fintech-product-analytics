-- Run after generating and loading synthetic data.
-- Each query should return zero rows unless the comment says otherwise.
-- These checks complement schema constraints; they do not replace them.
-- If a constraint rejects bad data during loading, the load may fail before this file runs.

-- 1) Duplicate user IDs. The primary key should already prevent these.
SELECT user_id, COUNT(*) AS row_count
FROM users
GROUP BY user_id
HAVING COUNT(*) > 1;

-- 2) Applications submitted before the user registered.
SELECT a.application_id, a.user_id, u.signup_at, a.submitted_at
FROM card_applications a
JOIN users u USING (user_id)
WHERE a.submitted_at < u.signup_at;

-- 3) Decision timestamp before submission.
-- Also covered by the schema CHECK constraint when data is loaded through PostgreSQL.
SELECT application_id, submitted_at, decision_at
FROM card_applications
WHERE decision_at IS NOT NULL
  AND decision_at < submitted_at;

-- 4) Application status and decision timestamp must agree.
SELECT application_id, application_status, decision_at
FROM card_applications
WHERE (application_status = 'pending' AND decision_at IS NOT NULL)
   OR (application_status IN ('approved', 'rejected') AND decision_at IS NULL);

-- 5) Applications whose user is missing (normally prevented by the foreign key).
SELECT a.application_id, a.user_id
FROM card_applications a
LEFT JOIN users u USING (user_id)
WHERE u.user_id IS NULL;

-- 6) Cards must be linked to approved applications.
SELECT c.card_id, c.application_id, a.application_status
FROM cards c
LEFT JOIN card_applications a USING (application_id)
WHERE a.application_id IS NULL
   OR a.application_status <> 'approved';

-- 7) A card must not be issued before the application was approved.
SELECT c.card_id, c.issued_at, a.application_id, a.decision_at
FROM cards c
JOIN card_applications a USING (application_id)
WHERE a.application_status = 'approved'
  AND c.issued_at < a.decision_at;

-- 8) Activation must not precede issuance.
-- Also covered by the schema CHECK constraint when data is loaded through PostgreSQL.
SELECT card_id, issued_at, activated_at
FROM cards
WHERE activated_at IS NOT NULL
  AND activated_at < issued_at;

-- 9) Card status and activation timestamp must agree.
SELECT card_id, card_status, activated_at
FROM cards
WHERE (card_status = 'issued' AND activated_at IS NOT NULL)
   OR (card_status IN ('active', 'blocked', 'closed') AND activated_at IS NULL);

-- 10) Transactions must reference an existing card (normally prevented by the foreign key).
SELECT t.transaction_id, t.card_id
FROM transactions t
LEFT JOIN cards c USING (card_id)
WHERE c.card_id IS NULL;

-- 11) Transactions must not precede card issuance.
SELECT t.transaction_id, t.transaction_at, c.issued_at
FROM transactions t
JOIN cards c USING (card_id)
WHERE t.transaction_at < c.issued_at;

-- 12) Transactions must not precede activation when the card has an activation timestamp.
-- This is a business-rule check, not currently a schema constraint.
SELECT t.transaction_id, t.transaction_at, c.activated_at
FROM transactions t
JOIN cards c USING (card_id)
WHERE c.activated_at IS NOT NULL
  AND t.transaction_at < c.activated_at;

-- 13) Events must reference an existing user (normally prevented by the foreign key).
SELECT e.event_id, e.user_id
FROM user_events e
LEFT JOIN users u USING (user_id)
WHERE u.user_id IS NULL;

-- 14) Events must not precede user registration.
SELECT e.event_id, e.user_id, u.signup_at, e.event_time
FROM user_events e
JOIN users u USING (user_id)
WHERE e.event_time < u.signup_at;

-- 15) Basic numeric sanity check for transaction amounts.
-- Also covered by the schema CHECK constraint when data is loaded through PostgreSQL.
SELECT transaction_id, amount
FROM transactions
WHERE amount <= 0;

-- 16) Timestamp bounds check against the documented synthetic observation period.
-- Expected bounds: signup/application/card data begins no earlier than 2025-01-01;
-- transaction/event activity ends before 2026-10-01 00:00:00.
-- Review returned rows rather than assuming every future dataset must share these bounds.
SELECT 'users.signup_at' AS field_name, MIN(signup_at) AS min_value, MAX(signup_at) AS max_value
FROM users
UNION ALL
SELECT 'applications.submitted_at', MIN(submitted_at), MAX(submitted_at)
FROM card_applications
UNION ALL
SELECT 'cards.issued_at', MIN(issued_at), MAX(issued_at)
FROM cards
UNION ALL
SELECT 'transactions.transaction_at', MIN(transaction_at), MAX(transaction_at)
FROM transactions
UNION ALL
SELECT 'user_events.event_time', MIN(event_time), MAX(event_time)
FROM user_events;
