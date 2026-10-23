# Fintech Product Analytics — Credit Card Activation & Retention

**Portfolio case study for a Junior Product Analyst role.**  
The project explores a fictional fintech card journey using fully synthetic data. This is an independent practice project; it does not use or describe Plata's internal data.

## Business questions
1. Where do users drop out between signup, application, approval, card issuance, activation and first successful purchase?
2. How long does it take for a newly activated card to make its first successful purchase?
3. How does retention change by signup cohort?
4. Do acquisition channels differ in downstream conversion?
5. Which metrics should a product team monitor?

## Dataset
Generated reproducibly with seed `20261023`.
- 5,000 users
- 3,333 card applications
- 1,777 cards
- 15,310 transactions
- 74,518 user events

Signup dates span Jan 2025–Jun 2026. Events are generated through Sep 2026. All records are synthetic.

**Important modeling limitation:** user sessions are generated at random points across the available follow-up period, and transactions are randomly distributed from activation to the data end. As a result, retention and time-to-first-purchase patterns are artifacts of the generator, not realistic behavioral estimates. Use this dataset to demonstrate SQL methods and metric definitions, not to claim real product insights. Timestamps are timezone-naive and assume one consistent fictional product timezone.

## Repository layout
- `business_problem.md` — business context, hypotheses and analytical approach
- `data/data_dictionary.md` — tables, fields and definitions
- `data/generate_synthetic_data.py` — deterministic synthetic-data generator
- `data/generated/*.csv` — generated tables
- `sql/00_schema.sql` — PostgreSQL schema
- `sql/00_load_synthetic_data.sql` — CSV loading with psql `\copy`
- `sql/01_data_quality.sql` — integrity and consistency checks
- `sql/02_funnel_analysis.sql` — 90-day conversion funnel
- `sql/03_activation_and_first_transaction.sql` — activation and time to first purchase
- `sql/04_cohort_retention.sql` — monthly cohort retention
- `sql/05_segmentation.sql` — acquisition-channel segmentation
- `sql/06_conversion_metrics.sql` — decision, issuance and timing metrics

## Run locally (PostgreSQL)
From the project root:

```bash
python data/generate_synthetic_data.py
createdb fintech_analytics
psql -d fintech_analytics -f sql/00_schema.sql
psql -d fintech_analytics -f sql/00_load_synthetic_data.sql
psql -d fintech_analytics -f sql/01_data_quality.sql
psql -d fintech_analytics -f sql/02_funnel_analysis.sql
psql -d fintech_analytics -f sql/03_activation_and_first_transaction.sql
psql -d fintech_analytics -f sql/04_cohort_retention.sql
psql -d fintech_analytics -f sql/05_segmentation.sql
psql -d fintech_analytics -f sql/06_conversion_metrics.sql
```

The load script uses psql-specific `\copy` commands. Run it from the repository root so the relative CSV paths resolve.

## Validation status
- Synthetic CSV generation and referential/time-order integrity checks: passed.
- SQL scripts: **not yet executed in PostgreSQL** in the authoring environment.
- Findings and recommendations: intentionally pending SQL execution; no unverified business conclusions are claimed.

## Metrics and analytical choices
- Funnel outcomes are deduplicated at user level within a 90-day observation window.
- Application approval rate uses final decisions only.
- Activation rate is calculated among issued cards.
- First-purchase latency uses successful transactions.
- Retention is measured by active users relative to the signup cohort.

## Next steps
1. Execute the scripts in PostgreSQL.
2. Review all QA outputs and resolve any failures.
3. Add actual query outputs, evidence-based findings and product recommendations.
4. Only then promote the project to `main`.

See `business_problem.md` and the `sql/` directory for the detailed case.
