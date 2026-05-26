---
owner: vlad
last_updated: 2026-05-25
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
| `dbt.temp_timeclock_data` | DBT-built enriched timeclock staging table. Richer than corona: includes engagement flags, size bands, county codes. Grain: one row per shift event per employee per location. Full schema documented in the section below. | DBT refresh | Use for ad hoc custom segmentation only. Never cite this table for monthly MSHR outputs. **Never filter by the raw `industry` column** — use `JOIN public.locations ON location_id` and filter on `business_type_new` instead (see `adhoc-report.md → Industry Classification`). |
| `dbt.new_data_weekly` | Pre-aggregated national weekly table built on `dbt.temp_timeclock_data`. Reporting period = Sunday to Saturday. Full schema documented in the section below. | Weekly | Use for weekly time series and PR data requests. **Do not use for published wages — see wage caveat below.** |
| `dbt.new_state_data_weekly` | Same as `new_data_weekly` but broken out by state. | Weekly | Use when state-level weekly breakdowns are needed. |

## Notebooks

| Notebook | What it produces | Inputs | Run by |
|---|---|---|---|
| [Wages, Hiring & Turnover](https://homebase-staging.cloud.databricks.com/editor/notebooks/2248482107468255?o=373323366197249) | `D-Wage+Labour_cost` (monthly avg hourly wage by job, nationally and by industry) and `D-Hiring+Turnover` (monthly jobs added and archived per location consideration set), both from Jan 2019 forward | `cohort_month_start`, `cohort_year_start`, `cohort_month_end`, `cohort_year_end`, report cutoff date | Vlad Akimenko |
| [DBT tables](https://homebase-staging.cloud.databricks.com/editor/notebooks/155412963220333?o=373323366197249) | `dbt.temp_timeclock_data`, `dbt.new_data_weekly`, `dbt.new_state_data_weekly` — enriched timeclock staging and pre-aggregated weekly tables used for ad hoc reports | Triggered on schedule or on demand before an ad hoc run | Vlad Akimenko |

---

## `dbt.temp_timeclock_data` — Full Column Reference

Grain: one row per shift event per employee per location. Built by the [DBT notebook](https://homebase-staging.cloud.databricks.com/editor/notebooks/155412963220333?o=373323366197249) from `corona.shift_and_timecard_events` enriched with engagement, size, and geography data.

> **Qualification flags do NOT exist in this table.** The `qualified_for_hours`, `qualified_for_jobs`, `qualified_for_turnover`, `qualified_for_wages`, and `qualified_for_outlook` columns live in `dbt.new_data_weekly` only. Any query against `dbt.temp_timeclock_data` that references these columns will fail. Use the inline qualification pattern below instead.

> **Industry field warning:** The `industry` column in this table contains raw/legacy values and is NOT normalized (43 distinct strings for 13 actual categories). **Do not filter or group by `industry` directly.** Always join to `public.locations` on `location_id` and use `business_type_new` for the canonical industry grouping. The full mapping and CASE WHEN fallback are in `adhoc-report.md → Industry Classification` and `industry-classification.sql`.

### Location & Geography

| Column | Type | Definition |
|---|---|---|
| `location_id` | INT | Single physical business location. Primary join key to `public.locations`. |
| `company_id` | INT | Parent company (may own multiple locations). |
| `city` | STRING | City name (raw, from `public.locations`). |
| `zip` | STRING | 5-digit ZIP code. |
| `county_code` | STRING | FIPS county code (e.g. `41009` = Columbia County, OR). |
| `state` | STRING | Standardized 2-letter state abbreviation (e.g. `'OR'`). Filtered to US states only in production — `state NOT IN ('Not USA', 'Unclassified')`. |
| `msa` | STRING | Metropolitan Statistical Area label (e.g. `'Portland-Vancouver-Beaverton, OR-WA MSA'`). `'[STATE] NONMETROPOLITAN AREA'` for rural locations. |

### Temporal

| Column | Type | Definition |
|---|---|---|
| `event_date` | DATE | Date of the shift (`date(shifts.start_at)`). **Primary filter field for all labor metrics.** |
| `shift_created_at` | TIMESTAMP | When the manager created the shift record. Signals business scheduling intent. |
| `timecard_created_at` | TIMESTAMP | When the employee punched in. Null if no clock-in. |
| `archived_at` | TIMESTAMP | When the employee-location job was archived (null = still active). |
| `loc_archived_at` | TIMESTAMP | When the location was archived (null = still active). Filter `loc_archived_at IS NULL` to exclude closed locations. |

### Employee & Job

| Column | Type | Definition |
|---|---|---|
| `user_id` | INT | Employee identifier. `COUNT(DISTINCT user_id)` = Employees Working. |
| `user_created_at` | TIMESTAMP | When the employee's Homebase account was created. |
| `job_id` | INT | Employee-location roster entry from `postgres.jobs`. One employee can have multiple `job_id`s across different locations. |
| `shift_id` | BIGINT | Shift record identifier. |
| `timecard_id` | BIGINT | Timecard record identifier. **Null if `has_clock_in = 0`.** |

### Labor Activity

| Column | Type | Definition |
|---|---|---|
| `hours_scheduled` | DOUBLE | `(shifts.end_at − shifts.start_at) / 3600`. Always present — captures scheduling-only businesses. |
| `hours_worked` | DOUBLE | `(timecards.end_at − timecards.start_at) / 3600`. **Null when `has_clock_in = 0`** (~24% of rows). Use for all MSHR labor metrics. |
| `has_clock_in` | INT | `1` if a timecard exists for this shift; `0` otherwise. ~77% of rows are `1` in a typical window. |
| `unscheduled` | INT | `1` if employee clocked in without a pre-created shift (no shift record). ~27% of rows. |

### Wage

| Column | Type | Definition |
|---|---|---|
| `hourly_wage_rate` | DOUBLE | Owner-reported wage rate. **Null for ~33% of rows.** Do NOT use for MSHR wage metrics — self-reported, overpopulated. Use the payroll cohort method instead. Valid range for filtering: `BETWEEN 7.25 AND 100`. |
| `total_wages_earned` | DOUBLE | Owner-reported wages for this shift. **Null for ~43% of rows.** Same caveat — internal trend use only, not for published wages. |

### Industry & Classification

| Column | Type | Definition |
|---|---|---|
| `industry` | STRING | **Raw/legacy field — NOT normalized. 43 distinct values exist for 13 canonical categories.** Do not use for filtering or grouping. Join to `public.locations.business_type_new` via `location_id` instead. |
| `naics_code` | STRING | 6-digit NAICS code. Null for ~2% of rows. Use as a fallback for industry mapping when `public.locations` is not joinable — see `industry-classification.sql`. |

### Engagement Flags

All flags sourced from `bizops.product_location_engagement_metrics`. Available at two snapshots to enable change analysis.

| Column | Type | Definition |
|---|---|---|
| `engagement_boolean` | INT | `1` if location is engagement-active (7d TT or scheduling + 30d OAM activity). Current snapshot. |
| `engagement_boolean_30d_ago` | INT | Same flag, 30 days prior. Combine with current to identify newly engaged / churned locations. |
| `scheduling_engaged_boolean` | INT | `1` if scheduling-engaged (7d lookback). Current snapshot. |
| `scheduling_engaged_boolean_30d_ago` | INT | Same flag, 30 days prior. |
| `two_d_thirty_active_this_month` | BOOLEAN | `true` if location was 2D30-active this calendar month. |
| `two_d_thirty_active_last_month` | BOOLEAN | `true` if location was 2D30-active last calendar month. |

### Size & Age

| Column | Type | Definition |
|---|---|---|
| `employee_count` | STRING | Pre-computed employee size band. Confirmed distinct values (from `public.locations` snapshot): `'0 employees'`, `'1–4 employees'`, `'5–9 employees'`, `'10–19 employees'`, `'20–49 employees'`, `'50–99 employees'`, `'100–249 employees'`, `'250–499 employees'`, `'500–999 employees'`, `'Unknown'`. For the standard MSHR 5–99 range, filter: `employee_count IN ('5–9 employees', '10–19 employees', '20–49 employees', '50–99 employees')`. |
| `location_age` | INT | Location age in **days** at the time of the event. Divide by 365.25 for years. Use `location_age >= 84` (84 days = 12 weeks) as the inline proxy for the minimum-weeks-active threshold. |

### Inline Qualification Pattern for `dbt.temp_timeclock_data`

Because `qualified_for_*` flags do not exist here, apply these filters in the `WHERE` clause of every ad hoc query. They replicate the intent of the pre-computed flags in `dbt.new_data_weekly`.

```sql
-- Replicates qualified_for_hours / qualified_for_jobs (5–99 employees, >= 12 weeks active)
WHERE employee_count IN (
    '5–9 employees',
    '10–19 employees',
    '20–49 employees',
    '50–99 employees'
)
AND location_age >= 84        -- 12 weeks * 7 days
AND loc_archived_at IS NULL   -- exclude closed locations

-- For qualified_for_turnover (10–100 employees), replace the IN list with:
-- employee_count IN ('10–19 employees', '20–49 employees', '50–99 employees')
```

**Note:** `location_age >= 84` is a point-in-time proxy for "active in ≥ 12 of the last 52 weeks." It is a reasonable approximation for city/segment ad hoc work but will include some locations that were inactive for extended periods. For national published MSHR outputs, use `dbt.new_data_weekly` where the flags are pre-computed precisely.

---

## `dbt.new_data_weekly` — Full Column Reference

Grain: one row per complete Sunday–Saturday week, national aggregate. Rebuilt by the [DBT notebook](https://homebase-staging.cloud.databricks.com/editor/notebooks/155412963220333?o=373323366197249). Full CREATE TABLE SQL: `create_new_data_weekly.sql` in this folder.

### Qualification Flags

Each location-week is pre-scored with five flags. Metric calculations apply the appropriate flag as a filter.

| Flag | Employee size band (12w avg) | Min weeks active (of last 52) | Additional requirement | Used by |
|---|---|---|---|---|
| `qualified_for_jobs` | 5–100 | ≥ 12 | Not archived this week | jobs_added, jobs_archived, hours_new_jobs |
| `qualified_for_hours` | 5–100 | ≥ 12 | Not archived this week | hours_worked, active_location_count |
| `qualified_for_turnover` | 10–100 | ≥ 12 | Not archived this week | users_added, users_archived, active_users, turnover rates |
| `qualified_for_wages` | 5–100 | ≥ 12 | wage_coverage_ratio > 0.5; not archived this week | avg_nominal_wage, avg_weekly_pay |
| `qualified_for_outlook` | 5–100 | ≥ 26 | Not archived this week | future_shifts, survival_52w |

### Output Columns

**Period**

| Column | Type | Definition |
|---|---|---|
| `period_start` | DATE | Sunday of the reporting week |
| `period_end` | DATE | Saturday of the reporting week |

**Denominators**

| Column | Type | Definition |
|---|---|---|
| `active_location_count` | INT | `COUNT(DISTINCT location_id)` WHERE `qualified_for_hours = 1` |
| `active_users` | INT | `COUNT(DISTINCT user_id)` WHERE `qualified_for_turnover = 1` |
| `avg_active_users_12w` | DOUBLE | 12-week rolling average of `active_users` — denominator for turnover/hire rates |
| `total_shifts` | INT | Shift count WHERE `qualified_for_outlook = 1` |

**Job flows** (`qualified_for_jobs`)

| Column | Type | Definition |
|---|---|---|
| `jobs_added` | INT | Users at a location this week but not last week (1-week activity gap) |
| `jobs_archived` | INT | Users at a location last week but not this week (activity gap) |
| `hours_new_jobs` | DOUBLE | `SUM(hours_worked)` for new job-location pairs this week |

**Turnover flows** (`qualified_for_turnover`)

| Column | Type | Definition |
|---|---|---|
| `users_added` | INT | Users whose first-ever shift on Homebase falls in this week. One-time platform-level event. |
| `users_archived` | INT | Users with `archived_at` falling in this week |

**Hours** (`qualified_for_hours` / `qualified_for_wages`)

| Column | Type | Definition |
|---|---|---|
| `hours_worked` | DOUBLE | `SUM(hours_worked)` WHERE `qualified_for_hours = 1` |
| `hours_worked_with_wage` | DOUBLE | `SUM(hours_worked)` WHERE `hourly_wage_rate IS NOT NULL` AND `qualified_for_wages = 1` |

**Wages** (`qualified_for_wages`) — ⚠️ internal trend use only

| Column | Type | Definition |
|---|---|---|
| `avg_nominal_wage` | DOUBLE | `SUM(total_wages_earned) / SUM(hours_worked)` WHERE `hourly_wage_rate BETWEEN 7.25 AND 100`. Self-reported field — not the payroll cohort method. Do not cite externally. |
| `avg_weekly_pay` | DOUBLE | `SUM(total_wages_earned) / COUNT(DISTINCT user_id)` WHERE `hourly_wage_rate BETWEEN 7.25 AND 100` |

**Per-location averages**

| Column | Type | Definition |
|---|---|---|
| `avg_hours_worked_per_loc` | DOUBLE | `hours_worked / active_location_count` |
| `avg_jobs_added_per_loc` | DOUBLE | `jobs_added / active_location_count` |
| `avg_jobs_archived_per_loc` | DOUBLE | `jobs_archived / active_location_count` |
| `avg_net_jobs_added_per_loc` | DOUBLE | `(jobs_added - jobs_archived) / active_location_count` |
| `shifts_per_loc` | DOUBLE | `total_shifts / active_location_count` |
| `hours_worked_per_user` | DOUBLE | `hours_worked / active_users` |
| `hours_worked_per_shift` | DOUBLE | `hours_worked / total_shifts` |
| `employees_per_loc` | DOUBLE | `active_users / active_location_count` |

**Workforce dynamics** (`qualified_for_turnover`)

| Column | Type | Definition |
|---|---|---|
| `turnover_rate` | DOUBLE | `users_archived / avg_active_users_12w` |
| `hire_rate` | DOUBLE | `users_added / avg_active_users_12w` |
| `turnover_volatility_idx` | DOUBLE | `(users_added + users_archived) / avg_active_users_12w` |

**Outlook / scheduling** (`qualified_for_outlook`)

| Column | Type | Definition |
|---|---|---|
| `future_shifts` | INT | Shifts scheduled 1–4 weeks ahead of the reporting week |
| `future_locs` | INT | Locations with future shifts scheduled |
| `future_shift_growth` | DOUBLE | `future_shifts / total_shifts` |
| `future_loc_growth` | DOUBLE | `future_locs / locs_curr` |
| `surviving_businesses_this_week` | INT | Locations active both 52 weeks ago and this week |
| `surviving_businesses_last_52w` | INT | Locations active 52 weeks ago (denominator for survival rate) |

### ⚠️ Key Differences vs Monthly MSHR

| Dimension | `dbt.new_data_weekly` | Monthly MSHR |
|---|---|---|
| **Reporting period** | Sunday–Saturday complete week | 28th of prior month → 27th of current month |
| **`jobs_added`** | Activity gap: worked this week, not last (labor fluidity signal) | `MIN(postgres.jobs.created_at)` per `(user_id, location_id)` — first-ever hire date, one-time event. **Completely different concept.** |
| **`jobs_archived`** | Activity gap: worked last week, not this week | `postgres.jobs.archived_at` in month, filtered via `whodunnit` to exclude system events |
| **Wages** | `avg_nominal_wage` from self-reported `total_wages_earned` in `dbt.temp_timeclock_data`. Internal trend use only. | Payroll cohort method via `postgres.payroll_payroll_runs`. Matched cohort. Suppressed at `sample_size_jobs ≤ 20`. Only valid method for published wages. |
| **Index / baseline** | None — raw counts and ratios | Indexed to January of current year; values = % above/below |
| **Employee double-count** | Filtered to `highest_level_location` in `dbt.temp_timeclock_data` — no double-count | `corona` pipeline may count an employee at multiple locations |

> **Wage rule:** For any wage figure published externally (monthly or ad hoc), always use the payroll cohort queries in `../mshr.md → ## Example Queries`. `avg_nominal_wage` from this table is for internal directional use only.


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
