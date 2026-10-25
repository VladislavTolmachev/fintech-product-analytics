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

**Important modeling limitation:** user sessions are generated at random points across the available follow-up period, and transactions are randomly distributed from activation to the data end. As a result, retention and time-to-first-purchase patterns are artifacts of the generator, not realistic behavioral estimates. Acquisition channel is also assigned independently of outcomes, so channel differences are not causal evidence. Use this dataset to demonstrate SQL methods and metric definitions, not to claim real product insights. Timestamps are timezone-naive and assume one consistent fictional product timezone.

## Repository layout
- `business_problem.md` — business context, hypotheses and analytical approach
- `data/data_dictionary.md` — tables, fields and definitions
- `data/generate_synthetic_data.py` — deterministic synthetic-data generator
- `data/generated/*.csv` — generated tables
- `sql/00_schema.sql` — PostgreSQL schema
- `sql/00_load_synthetic_data.sql` — CSV loading with psql `\copy`
- `sql/01_data_quality.sql` — integrity and consistency checks
- `sql/02_funnel_analysis.sql` — 90-day user-level funnel
- `sql/03_activation_and_first_transaction.sql` — card-level activation and first-purchase analysis
- `sql/04_cohort_retention.sql` — monthly in-app activity by signup cohort
- `sql/05_segmentation.sql` — 90-day user-level outcomes by acquisition channel
- `sql/06_conversion_metrics.sql` — application-level approval, card-level D30 activation and decision-time metrics
- `.github/workflows/sql-validation.yml` — PostgreSQL CI for schema, loading, QA assertions and all analysis scripts

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
- Synthetic CSV generation, schema creation and CSV loading completed successfully in the latest recorded CI attempt.
- The latest recorded GitHub Actions run failed in `sql/01_data_quality.sql` because the PL/pgSQL `DO` block was missing the semicolon after `END`. This has been corrected; rerun the workflow and verify all steps before treating CI as passed.
- Local PostgreSQL execution has been performed for the data-quality, funnel, activation/first-purchase and conversion-metrics scripts. Re-run all scripts after the latest repository changes to confirm the full set together.
- No real-world product conclusions are claimed because all records are synthetic.

## Metrics and analytical choices

| Metric | Unit of analysis | Definition |
|---|---|---|
| 90-day funnel | User | A user counts at a stage if they reached it at least once within `[signup_at, signup_at + 90 days)`; the full observation window must fit before the analysis cutoff. |
| Channel segmentation | User | Same 90-day user-level stage definitions as the funnel, grouped by acquisition channel. Channel differences are descriptive, not causal. |
| Application approval rate | Application | Approved applications divided by applications with a final decision before the cutoff. Pending applications are reported separately. |
| D30 activation rate | Card | Eligible issued cards activated within `[issued_at, issued_at + 30 days)`, divided by cards with a complete 30-day observation window. |
| D30 first-purchase conversion | Card | Eligible activated cards with a completed purchase in `[activated_at, activated_at + 30 days)`, divided by activated cards with a complete 30-day observation window. |
| Time to first purchase | Card | Time from activation to the first completed purchase; the reported D30 mean/median are conditional on a purchase within D30. |
| Monthly cohort activity rate | User | Distinct users with at least one tracked event in a calendar month divided by the original signup-cohort size. Month 0 can be below 100% because it measures activity after signup during the signup calendar month; month 1+ measures activity in subsequent calendar months, not strict day-based retention. |
| Decision time | Application | Elapsed time between submission and final decision; pending applications are excluded. |

**Denominator warning:** the funnel and channel segmentation are user-level, approval rate and decision time are application-level, and D30 activation/purchase are card-level. These results must not be compared as if they represented the same entities. A user with multiple applications or cards may contribute to more than one application/card outcome, while counting once in a user-level stage.

## Next steps
1. Confirm that the latest `SQL validation` workflow passes after the QA fix.
2. Re-run all scripts and review the QA outputs.
3. Add only findings supported by query results, while clearly labeling the generator's behavioral limitations.
4. Only then promote the project to `main`.

See `business_problem.md` and the `sql/` directory for the detailed case.
