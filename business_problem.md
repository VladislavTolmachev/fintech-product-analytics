# Business Problem

## Context
This portfolio case studies a fictional digital financial product that offers credit cards. The product team wants to understand how customers move from registration to application, approval, card activation, and repeat use.

All data will be synthetic. The case is not an analysis of Plata's internal performance and makes no claims about its actual customers or business.

## Primary objective
Identify the largest observed drop-offs in the customer journey and describe how activation and product usage vary by acquisition channel and customer cohort.

## Questions and metrics

| Question | Metric | Initial definition |
|---|---|---|
| Which channels bring in the most users? | Registrations by channel | Distinct users by acquisition channel and signup period |
| How many users apply? | Application conversion | Users who submit an application / registered users in the defined cohort |
| How often are applications approved? | Approval rate | Approved applications / applications with a final decision |
| How often are cards activated? | Card activation rate | Activated cards / issued cards in the defined cohort |
| How quickly do customers make a purchase? | Time to first purchase | Time from card activation to first completed purchase |
| Do customers return to the app? | Retention | Share of a signup or activation cohort active in a later period |
| How does behavior vary? | Segment-level metrics | Funnel and usage metrics by acquisition channel and other available dimensions |

## Guardrails and assumptions
- Use explicit cohort and observation windows for all conversion metrics.
- Exclude pending applications from approval-rate denominators.
- Define a successful purchase as a `purchase` transaction with `completed` status.
- Do not treat refunds, declined transactions, or reversed transactions as successful purchases.
- Separate in-app activity from financial activity.
- Account for right-censoring when analyzing D7 or D30 retention: users need sufficient follow-up time.
- Correlation in observational data does not establish causality.

## Deliverables
1. Reproducible SQL queries.
2. Data-quality checks.
3. Funnel and activation analysis.
4. Cohort-retention analysis.
5. A concise summary of findings and actionable product recommendations, based only on observed results.