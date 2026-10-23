-- Run from the repository root with psql after creating an empty schema.
-- Generate CSVs first: python data/generate_synthetic_data.py
-- This script is intended for a fresh/empty set of tables; it is not idempotent.
-- ON_ERROR_STOP prevents psql from continuing after a failed command.
\set ON_ERROR_STOP on

BEGIN;

\copy users (user_id, signup_at, acquisition_channel, country_code) FROM 'data/generated/users.csv' WITH (FORMAT csv, HEADER true)
\copy card_applications (application_id, user_id, submitted_at, decision_at, application_status) FROM 'data/generated/card_applications.csv' WITH (FORMAT csv, HEADER true, NULL '')
\copy cards (card_id, application_id, issued_at, activated_at, card_status) FROM 'data/generated/cards.csv' WITH (FORMAT csv, HEADER true, NULL '')
\copy transactions (transaction_id, card_id, transaction_at, amount, transaction_type, transaction_status) FROM 'data/generated/transactions.csv' WITH (FORMAT csv, HEADER true)
\copy user_events (event_id, user_id, event_time, event_name, session_id) FROM 'data/generated/user_events.csv' WITH (FORMAT csv, HEADER true, NULL '')

-- CSVs provide explicit IDs, so advance each identity sequence past the imported maximum.
-- This prevents the next INSERT that omits an ID from reusing an existing key.
SELECT setval(pg_get_serial_sequence('users', 'user_id'),
              COALESCE(MAX(user_id), 1), COUNT(*) > 0)
FROM users;
SELECT setval(pg_get_serial_sequence('card_applications', 'application_id'),
              COALESCE(MAX(application_id), 1), COUNT(*) > 0)
FROM card_applications;
SELECT setval(pg_get_serial_sequence('cards', 'card_id'),
              COALESCE(MAX(card_id), 1), COUNT(*) > 0)
FROM cards;
SELECT setval(pg_get_serial_sequence('transactions', 'transaction_id'),
              COALESCE(MAX(transaction_id), 1), COUNT(*) > 0)
FROM transactions;
SELECT setval(pg_get_serial_sequence('user_events', 'event_id'),
              COALESCE(MAX(event_id), 1), COUNT(*) > 0)
FROM user_events;

COMMIT;
