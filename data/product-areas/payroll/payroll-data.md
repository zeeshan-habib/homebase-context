# Payroll — Data Field Guide

Specific definitions, gotchas, disambiguation, and pointers for payroll data.
For metric definitions, see `data/glossary.md`. For product context, see `domains/payroll/`.

## Gotchas & Caveats

### Payroll runs aggregate employees AND contractors

The `payroll_payroll_runs` derived table unions employees and contractors into a single earnings CTE. Employee items come from `prod_redshift_replica.postgres.payroll_items` joined to `prod_redshift_replica.postgres.payroll_earnings`. Contractor items come from `prod_redshift_replica.postgres.payroll_contractor_payments`. If you need to split them, use `employees_paid` vs `contractors_paid` — don't assume all items are employees.

### Tip earnings have their own columns

Earnings with `description LIKE '%tips%'` are counted separately as `tip_earnings`. Overridden tip earnings (where `overridden = true`) are tracked as `tip_overridden_earnings`. Both are counts, not dollar amounts.

### "Paying customer" ≠ "ran payroll this month"

In `payroll_canonical_mrr`, `count_distinct_paying_customers` includes companies with `people_paid_in_month > 0` **or** companies in an active churn window. A company can be counted as "paying" for revenue purposes even if they didn't run payroll that specific month.

### Promo periods affect MRR but not customer count

A company on a 3-month promo is counted as a customer from day one, but their `flat_fee` is $0 during the promo. `total_company_mrr` sums `flat_fee` only for paying customers. `total_hb_payroll_mrr` adds per-employee revenue and workers comp revenue on top.

### Opportunity snapshots are point-in-time

Opportunity records capture product metrics (employee count, tier, price, team members active) as of the opportunity creation date via `prod_redshift_replica.public.fact_locations_by_day`. These do not update — they reflect the company's state when the opp was created.

### Pay period mismatch = OT risk

If `pay_period_start_clean ≠ schedule_start` on a location, overtime calculations may be wrong. The `start_day_mismatch` flag in `payroll_companies_pdt` tracks this.

### Check requirement statuses

Each Check verification step (EIN, bank, signatory, company identity) has a status: open, pending, failed, or closed. A company is "blocked by Check" if any requirement is not closed. These are tracked per-month in `companies_blocked_by_check`.

---

## Key Tables

| Table | What it's for | Join key |
|---|---|---|
| `prod_redshift_replica.postgres.payroll_check_companies` | Companies registered with Check for payroll | `company_id` |
| `prod_redshift_replica.postgres.payroll_payroll_runs` | Individual payroll run records | `run_id`, `location_id` |
| `prod_redshift_replica.postgres.payroll_items` | Employee payroll line items | `run_id`, `job_id` |
| `prod_redshift_replica.postgres.payroll_earnings` | Earnings detail per payroll item | joins to `payroll_items` |
| `prod_redshift_replica.postgres.payroll_contractor_payments` | Contractor payment records | `run_id` |
| `prod_redshift_replica.bizops.payroll_canonical_mrr_looker` | Pre-aggregated monthly payroll revenue | `company_id`, `reporting_date` |
| `prod_redshift_replica.bizops.payroll_opportunities` | Payroll sales opportunities | `opportunity_id`, `company_id` |
| `prod_enriched.bizops.crm_opportunity` | Zoho CRM opportunity details (loss reasons, descriptions) | `opportunity_id` |
| `prod_redshift_replica.postgres.payroll_run_metadata` | Submission method (web=0, autopayroll=1, mobile=2) | `run_id` |
| `prod_redshift_replica.postgres.payroll_company_packages` | Billing package / promo type info | `company_id` |
| `prod_redshift_replica.public.fact_locations_by_day` | Daily location snapshots (used for opp creation metrics) | `location_id`, `date` |

---

## Cohort Definitions

### Payroll cohort (months since first payroll)

Used in `payroll_canonical_mrr` to group customers by maturity:

| Cohort | Definition |
|---|---|
| M1 | First month after `first_payroll_date` |
| M2 – M12 | Subsequent months |
| M13+ | 13 or more months since first payroll |

### Company age at opportunity creation

Used in `zoho_payroll_opportunities` to segment pipeline by company maturity:

| Bucket | Definition |
|---|---|
| M1 | Company age < 1 month at opp creation |
| M2 | 1–2 months |
| M3 | 2–3 months |
| M4-M12 | 3–12 months |
| M13+ | 12+ months |

---

## Churn Reason Groupings

Churn reasons from `payroll_canonical_mrr` are grouped two ways:

**Detailed (`churn_reason_grouped_v2`):** unhappy_software, unhappy_customer_service, lack_of_features, business_disruption_or_closure, switching_to_manual_payroll, switching_to_other_provider, payroll_error, other

**Binary (`churn_reason_grouped_v3`):** Controllable Churn vs. Uncontrollable Churn

---

## MRR Components

Total Homebase Payroll MRR is built from three parts:

| Component | Source field | What it includes |
|---|---|---|
| Flat fee | `flat_fee` | Base subscription price |
| Per-employee revenue | `per_employee_revenue` | Per-head charges |
| Workers comp revenue | `per_employee_workers_compensation_revenue` | Workers comp add-on |

`total_hb_payroll_mrr` = flat fee + per-employee + workers comp

---

## Disambiguation

| If you see... | Use this | Not this |
|---|---|---|
| "Ran payroll" | `first_payroll_date IS NOT NULL` on the opportunity | `status` on `payroll_payroll_runs` (that's individual run status) |
| "Paying customer" (payroll) | `count_distinct_paying_customers` in canonical MRR | Simple company count (misses churn window logic) |
| Payroll MRR | `total_hb_payroll_mrr` (includes all 3 components) | `total_company_mrr` (flat fee only) |
| Employee count at opp | `employee_count_at_opp_creation` from `prod_redshift_replica.bizops.payroll_opportunities` | Current employee count (changes over time) |
| Opportunity created date | `opportunity_created_at` from `prod_redshift_replica.bizops.payroll_opportunities` | `company_created_at` (different event) |
| Submission method | `submitted_through`: 0=web, 1=autopayroll, 2=mobile | `auto_payroll` flag (only indicates auto vs manual) |
