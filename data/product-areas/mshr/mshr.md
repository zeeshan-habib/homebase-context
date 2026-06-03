---
owner: vlad-akimenko
last_updated: 2026-05-28
review_cadence: monthly
next_review: 2026-06-28
source: internal
refs:
  - domains/mshr/domain-overview.md
  - data/glossary.md
  - data/product-areas/mshr/schemas.md
  - data/product-areas/mshr/index-methodology.md
  - data/product-areas/mshr/example-queries.md
  - data/product-areas/mshr/report-production.md
---

# MSHR — Data Field Guide

Load when you need metric definitions, terminology, suppression rules, or the disambiguation table. For table schemas and column definitions, see `schemas.md`. For index formulas and benchmark construction, see `index-methodology.md`. For production SQL, see `example-queries.md`. For the report production pipeline, see `report-production.md`.

---

## MSHR Terminology

> These definitions apply **only to MSHR reports**. Ad hoc report definitions use standard Homebase platform terms.

| MSHR Term | Means | Not |
|---|---|---|
| Business | A single location | A company (which may have multiple locations) |
| Hourly worker / Employee | An employee at a location | — |
| Shift | A work period created by the owner/manager in advance | A clock-in or timecard |
| Clock-in / Timecard | Created when an employee punches in for work. Independent of shifts — a timecard can exist without a shift (unscheduled), and a shift can exist without a timecard (no-show). | — |
| `shift_created_at` | When the owner created the shift record in the system. Signals business activity (owner has expectation of future work). | When the employee clocked in |
| `timecard_created_at` | When the employee punched in (timecard record created). Signals employee activity. Used for wage period assignment in the payroll notebook. | `shift_created_at` |
| `event_date` | Date of shift start (`date(shifts.start_at)`). Used as the period assignment date for all MSHR labor metrics. | `timecard_created_at` or `shift_created_at` |
| Unscheduled | A timecard with no associated shift — the employee clocked in without a pre-created shift record. | A scheduled shift with no clock-in (which is a no-show) |
| Hours scheduled | `shifts.end_at − shifts.start_at`. Present even if no clock-in occurred. Used for businesses that track scheduling only. | Hours actually worked |
| Hours worked | `timecards.end_at − timecards.start_at`. Only present if a timecard exists. Used for businesses that track time only or both. | Scheduled hours |
| Job (in wage context) | A roster entry from `postgres.jobs` (one employee at one location) at a location in the payroll cohort. `job_id` originates from `postgres.jobs`. `postgres.payroll_payroll_runs` defines which *locations* qualify for the cohort — it does not contain the job records themselves. | A payroll run; an employee headcount; a shift |
| Jobs added (MSHR) | `MIN(postgres.jobs.created_at)` per employee at a location = the employee's hire date. Multiple job records can exist for the same employee; the earliest `created_at` is the hire date. | Subsequent job records for the same employee |
| Jobs added (ad hoc weekly) | Employees who had a shift in the current week but **not** in the prior week (current SQL: 1-week lookback). Recommended definition: 4-week lookback. Definition should be confirmed with the requestor when generating ad hoc reports. | Same as MSHR jobs added — these are different concepts |
| Jobs archived (MSHR) | Jobs with `postgres.jobs.archived_at` falling in the reference month, excluding system-driven archivations (rake jobs, lock workers, termination workers) | Raw archive count including system events |
| Users added (ad hoc weekly) | Employees whose very first shift on the platform (`MIN(event_date)` across all history) falls in the current reporting period. One-time event per employee. Reflects location workforce growth. | `jobs_added` — which measures recurring weekly activity gaps |
| Payroll cohort | Locations that ran Homebase Payroll in both the reporting month AND the same month one year prior | All active locations |
| Month | 28th of the prior calendar month to 27th of the current calendar month | Calendar month |
| Industry | `locations.business_type_new` — the canonical industry field for new and ad hoc queries. 13 industries total. **Exception:** the monthly MSHR production workflow uses `locations.business_type` (legacy column) to match the reference notebook (`PR_Standard_EOM_Metrics.ipynb`). Do not change the monthly workflow to `business_type_new` without re-validating industry label parity against the notebook. | — |
| Business category | `locations.business_category_new` — a granular subdivision within an industry. Multiple categories map to one industry. | Industry-level grouping |

---

## Report Architecture

Two distinct reports are produced from this domain. They share metric definitions but use different source tables.

| Report | Cadence | Primary Source Table | Notes |
|---|---|---|---|
| **Main Street Health Report (MSHR)** | Monthly | `corona.shift_and_timecard_events` | Production event table; all six MSHR metrics flow from here |
| **Ad Hoc Reports** | On request | `dbt.temp_timeclock_data` | DBT-built staging table; same grain as corona but enriched with engagement, size bands, and geo lookups. Used for custom segmentation and one-off analysis. |

**Never conflate the two.** `dbt.temp_timeclock_data` is richer but is a derived/temp table. The MSHR is always built directly from `corona.shift_and_timecard_events` and `postgres.jobs`. When documenting MSHR logic, cite corona/postgres — not the DBT table.

---

> **Table reference convention:** `corona.*`, `dbt.*`, and `operations.*` tables are Databricks-native schemas living under the `hive_metastore` catalog (e.g. `hive_metastore.corona.shift_and_timecard_events`). SQL in this file uses shorthand paths (without the catalog prefix) matching the Databricks query context where `hive_metastore` is the default catalog. `postgres.*` and `public.*` tables are Redshift tables accessed via `prod_redshift_replica` (e.g. `prod_redshift_replica.postgres.jobs`).

## Key Metrics

> All six MSHR metrics are sourced from the **MSHR pipeline** (`corona.shift_and_timecard_events` + `postgres.jobs`). The ad hoc pipeline (`dbt.temp_timeclock_data`) uses equivalent logic but is documented separately.

| Metric | Technical Definition | Source Table (MSHR) | Key Fields | Breakdowns Available |
|---|---|---|---|---|
| **Employees Working** | Distinct count of hourly workers with ≥1 clock-in in the reference week | `corona.shift_and_timecard_events` | `user_id` WHERE `has_clock_in = 1` (timecard present) | Overall; by industry (Beauty & Wellness, Caregiving, Entertainment, Food/Drink/Dining, Hospitality, Retail, Home & Repair, Medical/Veterinary) |
| **Hours Worked** | Sum of `timecards.end_at − timecards.start_at` across all timecards in the reference week | `corona.shift_and_timecard_events` | `hours_worked` = `TIMESTAMPDIFF(second, timecards.start_at, timecards.end_at) / 3600.0` | Overall |
| **Businesses Open** | Count of locations with ≥1 employee clock-in in the reference week | `corona.shift_and_timecard_events` | `location_id` WHERE `has_clock_in = 1` | Overall; by Census region (Midwest, Northeast, Southeast, Southwest, West) |
| **Hourly Wages** | Average of per-job wage rates (`total_wages_earned / hours_worked`) across all jobs in the payroll cohort, for the reference month | `corona.shift_and_timecard_events` (filtered to payroll cohort from `postgres.payroll_payroll_runs`) | `wage_rate` per `job_id` = `SUM(total_wages_earned) / SUM(hours_worked)`; then `AVG(wage_rate)` across jobs | Overall; by industry (`locations.business_type_new`); by state; by MSA |
| **Jobs Added** | Count of new jobs (`jobs.created_at`) at qualifying locations in the reference month | `postgres.jobs` | `jobs.created_at BETWEEN month_beginning AND month_end` | Overall |
| **Jobs Archived** | Count of jobs with `jobs.archived_at` in the reference month at qualifying locations, excluding system-driven archivations | `postgres.jobs` + `postgres.job_versions` | `jobs.archived_at BETWEEN month_beginning AND month_end`; filtered via `jv.whodunnit` | Overall |

---

## Aggregation and Suppression Rules

### General

| Rule | Logic | Why |
|---|---|---|
| Data horizon | Timeclock and payroll data: from `2019-01-01`. Turnover: `month_end > '2018-12-01'` | Historical baseline for 3-year trend comparisons |
| US locations only | `state NOT IN ('Not USA', 'Unclassified')` | Excludes non-US and unclassified records |
| Month definition | 28th of prior calendar month to 27th of current calendar month | Consistent with Homebase Payroll cycle |
| Period sequence | Generated via `sequence(to_date('2019-01-27'), to_date(DATE), interval 1 month)` in `month_end_dates` view | Creates one row per reporting month back to 2019 |

### Timeclock Pipeline

| Rule | Logic | Why |
|---|---|---|
| Shift owner type | `shifts.owner_type = 'Job'` | Excludes open/unassigned shifts |
| Primary location (ad hoc only) | `jobs.location_id = u.highest_level_location` | Counts each employee once at their primary location. Applied in `dbt.temp_timeclock_data`, not in MSHR corona pipeline. |
| Do not use corona wage fields for MSHR | `hourly_wage_rate` and `total_wages_earned` in `corona.shift_and_timecard_events` are owner self-reported and overpopulated | Use the payroll cohort method (`postgres.payroll_payroll_runs`) for all MSHR wage metrics |

### Payroll Pipeline (Wages)

| Rule | Logic | Why |
|---|---|---|
| Matched cohort | Location must appear in `payroll_payroll_runs` for both cohort start and cohort end months | Ensures YoY comparisons use the same businesses |
| Sample suppression | `HAVING sample_size_jobs > 20` | Suppresses periods/segments with fewer than 20 jobs to protect anonymity and reduce noise |

### Hiring & Turnover Pipeline

| Rule | Logic | Why |
|---|---|---|
| Company age | `company_created_date < month_end_dates.year_beginning` | Excludes newly created companies from the cohort; ensures locations have a full year of history |
| Turnover: exclude billing archivations | `whodunnit NOT LIKE '%rake businesses:archive_invoiced_company%'` | Bulk archivations triggered by billing/invoicing, not actual employee departures |
| Turnover: exclude lock archivations | `whodunnit NOT LIKE '%lockjobworker%'` | System lock events unrelated to real turnover |
| Turnover: exclude termination-worker archivations | `whodunnit NOT LIKE '%handlejobterminationworker%'` | System-automated terminations (e.g., Clover integrations); not organic turnover |
| Turnover: rake job monitoring | If turnover variance is **>5% YoY**, query `postgres.job_versions` filtered to the spike period and inspect `whodunnit` for rake task patterns. Exclude any identified rake jobs from the count. | Historical internal cleanup runs have artificially inflated turnover numbers in the past |

---

## Disambiguation

| If you see... | Use this | Not this |
|---|---|---|
| "business" in MSHR context | location (single physical site) | company or account |
| "employees working" | distinct workers with ≥1 clock-in | scheduled or rostered headcount |
| "hours worked" | actual timecard duration (`timecards.end_at − timecards.start_at`) | `shifts.end_at − shifts.start_at` (scheduled hours) |
| "jobs added" | `postgres.jobs.created_at` falling in the reference month | all active jobs |
| "jobs archived" | `postgres.jobs.archived_at` in the reference month, minus system archivations | total raw archive count |
| "wage inflation" | YoY change in avg hourly wage, matched-cohort Payroll locations only | all-location wage average |
| "job" in wage context | a `postgres.jobs` roster entry (employee-location pairing) at a location in the payroll cohort. For wages, always refer to `postgres.payroll_payroll_runs` to define which locations qualify — then use `job_id` (from `postgres.jobs`, via `corona`) as the wage calculation grain. | a payroll run |
| "sample_size_jobs" | `COUNT(DISTINCT job_id)` in the wage query — number of unique `postgres.jobs` roster entries that had payroll wage data in the period | payroll run count; employee headcount; location count |
