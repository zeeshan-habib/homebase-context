---
owner: vlad
last_updated: 2026-05-24
review_cadence: monthly
next_review: 2026-06-24
source: internal
refs: []
---

# MSHR Data Sourcing

## Overview

This file describes how to identify, locate, refresh, and validate the Databricks tables and notebooks that power MSHR. Load this file when the question is about which tables to use, whether data is current, or how to run a refresh.

For full column definitions and SQL patterns, see `../mshr.md`.

## Source Tables

### Monthly MSHR Pipeline

| Table | Description | Refresh cadence | Notes |
|---|---|---|---|
| `corona.shift_and_timecard_events` | Primary production event table at shift+timecard grain. Source for Employees Working, Hours Worked, Businesses Open, and the wage cohort filter. | Daily | Data horizon: `event_date > '2016-01-01'`. Use `event_date` (not `timecard_created_at`) for all labor metrics. |
| `corona.location_usage_benchmarks_from_aph_jan_[YYYY]` | Per-location, per-day-of-week benchmarks used by Looker to compute indexed values. One table per calendar year. | Annually (January) | A new `_jan_YYYY` table must be created each January. Active tables: 2022–2026. Looker Explore name: `coronavirus_data_aph_jan_[YYYY]`. |
| `postgres.jobs` | Employee-location roster records. Used for Hiring (jobs created) and Turnover (jobs archived). | Real-time (production) | Multiple rows per employee per location — always use `MIN(created_at)` per `(user_id, location_id)` for hire date. `uuid` differentiates rows. |
| `postgres.job_versions` | Audit log of all changes to job records. Used to exclude system-driven archivations from turnover counts. | Real-time | Query only when turnover variance is >5% YoY. Filter `whodunnit` for rake/lock/termination patterns. |
| `postgres.payroll_payroll_runs` | One row per payroll run per location. Defines the matched cohort for wage analysis. | Monthly | Filter by `year(payday)` and `month(payday)`. Cohort = locations appearing in both reporting month AND 12 months prior. |
| `public.locations` | Location metadata: `business_type_new`, `state_cleaned`, `msa`, `naics_code`, `city`, `zip`. | Real-time | Use `business_type_new` for industry (not deprecated `business_type`). Filter `state NOT IN ('Not USA', 'Unclassified')`. |
| `operations.coronavirus_data_state_mapping` | Maps raw state strings → standardized state labels. | Stable | Fallback: `'Unclassified'`. Applied inside `corona.shift_and_timecard_events` build. |
| `operations.coronavirus_data_msa_mapping` | Maps raw MSA strings → standardized MSA labels. | Stable | Fallback: `'All other'`. Applied inside `corona.shift_and_timecard_events` build. |
| `operations.coronavirus_data_industry_mapping` | Maps raw industry strings → standardized industry labels. | Stable | Fallback: `'Unknown'`. Applied inside `corona.shift_and_timecard_events` build. |

### Ad Hoc Pipeline (not used for monthly MSHR)

| Table | Description | Refresh cadence | Notes |
|---|---|---|---|
| `dbt.temp_timeclock_data` | DBT-built enriched timeclock staging table. Richer than corona: includes engagement flags (`bizops.product_location_engagement_metrics`), size bands (`public.fact_locations_by_day`), county codes. | DBT refresh | Use for ad hoc custom segmentation only. Never cite this table for monthly MSHR outputs. |
| `dbt.new_data_weekly` | Pre-aggregated national weekly table built on `dbt.temp_timeclock_data`. Reporting period = Sunday to Saturday. | Weekly | Use for weekly time series and PR data requests. Includes qualification flags per metric. |
| `dbt.new_state_data_weekly` | Same as `new_data_weekly` but broken out by state. | Weekly | Use when state-level weekly breakdowns are needed. |

## Notebooks

| Notebook | What it produces | Inputs | Run by |
|---|---|---|---|
| [Wages, Hiring & Turnover](https://homebase-staging.cloud.databricks.com/editor/notebooks/2248482107468255?o=373323366197249) | `D-Wage+Labour_cost` (monthly avg hourly wage by job, nationally and by industry) and `D-Hiring+Turnover` (monthly jobs added and archived per location consideration set), both from Jan 2019 forward | `cohort_month_start`, `cohort_year_start`, `cohort_month_end`, `cohort_year_end`, report cutoff date | Vlad Akimenko |
| [DBT tables](https://homebase-staging.cloud.databricks.com/editor/notebooks/155412963220333?o=373323366197249) | `dbt.temp_timeclock_data`, `dbt.new_data_weekly`, `dbt.new_state_data_weekly` — enriched timeclock staging and pre-aggregated weekly tables used for ad hoc reports | Triggered on schedule or on demand before an ad hoc run | Vlad Akimenko |

## Data Freshness Check

Before any report run, confirm all tables are current through the cutoff date (27th of the reporting month):

```sql
-- Primary labor metrics table
SELECT MAX(event_date) AS latest_event_date
FROM corona.shift_and_timecard_events;

-- Payroll cohort coverage
SELECT MAX(payday) AS latest_payday
FROM postgres.payroll_payroll_runs;

-- Hiring and turnover coverage
SELECT
    MAX(created_at)  AS latest_job_created,
    MAX(archived_at) AS latest_job_archived
FROM postgres.jobs;
```

All three dates should be ≥ the 27th of the reporting month before proceeding.

## Known Data Issues

| Issue | Details | Mitigation |
|---|---|---|
| System-driven turnover spikes | Rake jobs, lock workers, and termination workers can bulk-archive jobs, inflating turnover counts. | If turnover variance is >5% YoY, query `postgres.job_versions` filtered to the spike period. Filter `whodunnit NOT LIKE '%rake businesses:archive_invoiced_company%'`, `'%lockjobworker%'`, `'%handlejobterminationworker%'`. |
| `corona.daily_agg_shifts_timecards_sales` deprecated | This table was the former daily aggregate used for benchmark construction. Do not use. | If regenerating benchmarks, use `create_benchmark_table.sql` (in this folder) — it replicates the aggregation inline from `corona.shift_and_timecard_events`. |
| `hourly_wage_rate` / `total_wages_earned` in corona | These fields are owner self-reported and overpopulated — not suitable for wage analysis. | Use the payroll cohort method (`postgres.payroll_payroll_runs`) for all MSHR wage metrics. |
| Annual benchmark table must be created each January | A new `corona.location_usage_benchmarks_from_aph_jan_[YYYY]` must be created each January using the benchmark script. | Track this as a recurring January task. If the current year's table is missing, Looker indexed values will be wrong. |

---

## Recreating the Benchmark Table

The benchmark table `corona.location_usage_benchmarks_from_aph_jan_[YYYY]` must be recreated once per year in January. It is the denominator for all three indexed labor metrics (Employees Working, Hours Worked, Businesses Open).

**When to run:** Every January, after choosing the reference date range. Must exist before Looker can compute indexed values for the new year.

**Reference SQL:** `create_benchmark_table.sql` (in this folder) — full Databricks SQL script with verification queries.

### Step 1 — Choose the date range

The range is chosen manually each January. Rules:
- Must be exactly 4 complete weeks (28 days), which means exactly 4 of each day of the week
- Avoid the New Year's holiday period — do not start before ~Jan 3
- The window may extend into early February when the calendar requires it

**Confirmed historical ranges:**

| Year | Start | End | Notes |
|---|---|---|---|
| 2026 | 2026-01-04 | 2026-01-31 | |
| 2025 | 2025-01-05 | 2025-02-01 | Extends into Feb |
| 2024 | 2024-01-07 | 2024-02-03 | Extends into Feb |
| 2023 | 2023-01-08 | 2023-02-04 | Extends into Feb |
| 2022 | 2022-01-03 | 2022-01-30 | |
| 2021 | 2021-01-09 | 2021-02-05 | Extends into Feb |
| 2020 | 2020-01-04 | 2020-01-31 | |
| 2019 | 2019-01-04 | 2019-01-31 | |
| 2018 | 2018-01-04 | 2018-01-31 | |

### Step 2 — Update and run the script

In `create_benchmark_table.sql` (in this folder), change the two lines marked `← CHANGE`:
1. Table name: `corona.location_usage_benchmarks_from_aph_jan_[YYYY]`
2. Date filter: `WHERE event_date BETWEEN '[start]' AND '[end]'`

Run the full script in Databricks. It creates the table from scratch (DROP + CREATE).

### Step 3 — Verify

After creation, run the three verification queries at the bottom of the script:

1. **DOW symmetry** — `SELECT day_of_week, COUNT(*) FROM ... GROUP BY day_of_week` should return the same location count for all 7 DOWs (0–6). If not, the date range spans an unequal number of each day of the week.
2. **days_with_data = 4** — `SELECT MIN(days_with_data), MAX(days_with_data)` should both equal 4. If not, the 28-day window contains fewer or more than 4 of some DOW.
3. **Spot-check against D-sheet** — run the sample relative-level query for a known date and compare to the D-Employees_working column in the MSHR Excel file. Values should match within rounding.

### Key technical notes

- **Table grain:** `location_id, state, msa, industry, city, day_of_week` — five grain dimensions, not just location × DOW
- **DOW encoding:** 0 = Sunday … 6 = Saturday (PostgreSQL convention). In Databricks, use `dayofweek(event_date) - 1` on both sides of the join
- **No US filter at creation** — state/US filtering (`state NOT IN ('Not USA', 'Unclassified')`) is applied at query time (in Looker or in the indexed values query), not during benchmark table creation
- **`benchmark_locs_with_clock_ins`** is NOT stored in the table. Derive it at query time as `denominator_clock_ins / 4.0`. SUM across locations = aggregate expected open-location count (denominator for Businesses Open indexed value)
