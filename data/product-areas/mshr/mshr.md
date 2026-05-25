---
owner: vlad-akimenko
last_updated: 2026-05-25
review_cadence: monthly
next_review: 2026-06-25
source: internal
refs:
  - domains/mshr/domain-overview.md
  - data/glossary.md
---

# MSHR — Data Field Guide

Specific definitions, data boundaries, and schema pointers for MSHR data.
For product context (what MSHR is, who it's for), see `domains/mshr/`.

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
| `timecard_created_at` | When the employee punched in (created the timecard record). Signals employee activity. Used for wage period assignment in the payroll notebook. | `shift_created_at` |
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
| Industry | `locations.business_type_new` — the canonical industry field. 13 industries total. Do not use `locations.business_type`. | `business_type` (legacy) |
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

> **Table reference convention:** `corona.*` and `dbt.*` tables are Databricks-specific paths. `postgres.*` and `public.*` tables are Redshift tables accessed via `prod_redshift_replica` (e.g. `prod_redshift_replica.postgres.jobs`). SQL in this file uses shorthand paths matching the Databricks query context.

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

## Data Sources and Tables

### MSHR Pipeline — Employees Working, Hours Worked, Businesses Open

Primary source: `corona.shift_and_timecard_events` — a production event table at shift+timecard grain, built from `postgres.*` source tables plus three `operations.*` label-mapping tables. Contains pre-computed `hours_worked`, `total_wages_earned`, `has_clock_in`, `job_id`, `location_id`, `timecard_created_at`, and cleaned `state`/`msa`/`industry` labels.

**How `corona.shift_and_timecard_events` is built:**

> **Schema alias note:** `postgres.*` and `ext_homebase1_public.*` are interchangeable — they point to the same underlying data. The corona table uses `postgres.*`; the DBT ad hoc table uses `ext_homebase1_public.*`. Either can be used in queries.

| Source Table | Schema | What it contributes |
|---|---|---|
| `shifts` | `postgres` / `ext_homebase1_public` | One row per shift; `start_at`, `end_at`, `role_id`, `unscheduled` flag |
| `jobs` | `postgres` / `ext_homebase1_public` | Employee-location roster; `location_id`, `user_id` |
| `timecards` | `postgres` / `ext_homebase1_public` | Clock-in/out records; `start_at`, `end_at` — left join (NULL = no clock-in) |
| `role_wages` | `postgres` / `ext_homebase1_public` | Role-specific wage assignments — **not important for MSHR; skip for wage analysis** |
| `locations` | `public` | Location metadata; raw `state`, `msa`, `business_type_new`, `city`, `zip` |
| `companies` | `public` | `onboarding_business_description` for industry (preferred over `business_type`) |
| `wage_history` | `public` | Hourly wage rates — **not important for MSHR; skip for wage analysis. Use payroll cohort method instead.** |
| `zip_to_county_code_map` | `operations` | Zip → county FIPS |
| `coronavirus_data_state_mapping` | `operations` | Cleans and standardizes raw state values → `state` label (fallback: `'Unclassified'`) |
| `coronavirus_data_msa_mapping` | `operations` | Cleans and standardizes raw MSA values → `msa` label (fallback: `'All other'`) |
| `coronavirus_data_industry_mapping` | `operations` | Maps raw industry strings → standardized `industry` label (fallback: `'Unknown'`) |

Data horizon: `event_date > '2016-01-01'`

**Column definitions for `corona.shift_and_timecard_events`:**

| Column | Definition | MSHR usage |
|---|---|---|
| `location_id` | Single physical business location | All metrics |
| `company_id` | Parent company (may own multiple locations) | Filtering |
| `event_date` | `date(shifts.start_at)` — the date of the shift. **Primary period assignment field for all MSHR labor metrics.** | All labor metrics |
| `shift_created_at` | When the owner created the shift record. Signals business activity and forward expectation of work. Not used as period filter in MSHR — use `event_date`. | Not used in MSHR aggregation |
| `timecard_created_at` | When the employee punched in (timecard record created). Signals employee activity. **Used for period assignment in the payroll/wage notebook only**, not for labor metrics. | Payroll pipeline only |
| `job_id` | Unique employee-location pairing. One employee can have multiple `job_id`s across different locations. | Wages (COUNT DISTINCT for sample size) |
| `user_id` | Employee identifier. `COUNT(DISTINCT user_id)` = Employees Working. | Employees Working |
| `shift_id` | Shift record identifier | Row-level grain |
| `timecard_id` | Timecard record identifier. NULL if no clock-in. | `has_clock_in` flag |
| `hours_scheduled` | `(shifts.end_at - shifts.start_at) / 3600`. Present even with no clock-in. Captures businesses that use Homebase for scheduling only. **Surface as an employee engagement metric alongside `hours_worked`.** | Hours Worked metric (scheduling-only businesses) |
| `hours_worked` | `(timecards.end_at - timecards.start_at) / 3600`. NULL if no clock-in. Captures businesses that use Homebase for time tracking only or both. **Surface as an employee engagement metric alongside `hours_scheduled`.** | Hours Worked metric |
| `has_clock_in` | `1` if a timecard exists for the shift, `0` if not. Businesses open and Employees Working both depend on this flag. | Businesses Open, Employees Working |
| `unscheduled` | `1` if the employee clocked in without a pre-created shift (no `shifts` record). Owner did not create a shift in advance. | Dimension only — not used in MSHR metric aggregation |
| `hourly_wage_rate` | `COALESCE(role-specific wage, default wage)`, NULL if ≥ $100. Sourced from owner-reported payroll tables. **Do not use for MSHR wage metrics** — self-reported and overpopulated. Use the payroll cohort method (`postgres.payroll_payroll_runs`) instead. | Not used for MSHR wages |
| `total_wages_earned` | `hours_worked × hourly_wage_rate`. **Do not use for MSHR wage metrics** — same issue as `hourly_wage_rate`. Use payroll cohort method. | Not used for MSHR wages |
| `state` | Cleaned state label (via `coronavirus_data_state_mapping`). Fallback: `'Unclassified'`. | Regional breakdowns |
| `msa` | Cleaned MSA label (via `coronavirus_data_msa_mapping`). Fallback: `'All other'`. | MSA breakdowns |
| `industry` | Cleaned industry label (via `coronavirus_data_industry_mapping`). Derived from `COALESCE(companies.onboarding_business_description, locations.business_type)`. | Industry breakdowns |
| `city`, `zip`, `county_code` | Geographic metadata | Ad hoc geo breakdowns |

---

### MSHR Index Methodology — Businesses Open, Employees Working, Hours Worked

Businesses Open, Employees Working, and Hours Worked are **not reported as raw counts**. They are reported as an index — the level relative to January of the same year, expressed as a decimal (e.g., 0.018 = +1.8% above January baseline). This allows side-by-side comparison of seasonal patterns across 2024, 2025, and 2026.

**Index formula (aggregate — Looker "Agg" method):**
```
relative_level (daily) = SUM(actual across all locations) / SUM(benchmark across all locations) − 1
```
- For Employees Working: `SUM(users_with_clock_in) / SUM(benchmark.users_with_clock_in) − 1`
- For Hours Worked: `SUM(total_hours_worked) / SUM(benchmark.total_hours_worked) − 1`
- For Businesses Open: `SUM(is_open) / SUM(benchmark.denominator_clock_ins / 4.0) − 1`

Ratios are summed at the aggregate level, **not** averaged per location. INNER JOIN ensures only locations with a January benchmark are included (consistent with Looker).

**Monthly value = 7-day average** over `[reference_sunday, reference_sunday + 6]`, where reference_sunday = Sunday of the week containing the 12th of the month.

**MoM change = `current_month_avg − prior_month_avg`** (both already indexed → result is percentage-point change, no division needed). Partitioned by year so January has NULL.

**Baseline construction (benchmark table):**
- Source: `corona.daily_agg_shifts_timecards_sales` (deprecated) — if recreating, replicate inline from `corona.shift_and_timecard_events` (see `workflows/create_benchmark_table.sql`)
- Table grain: `location_id, state, msa, industry, city, day_of_week` (5 grain dimensions)
- DOW encoding: **0 = Sunday … 6 = Saturday** (PostgreSQL convention). In Databricks, use `dayofweek(date) - 1` to produce this encoding.
- Date range: **manually chosen each January** — 4 complete weeks (28 days) avoiding New Year's holiday distortion. Window may extend into early February when needed. No algorithmic formula.
- Denominator: `COUNT(DISTINCT event_date WHERE metric > 0)` — only days with actual activity; zero-activity days excluded from the per-location average
- Column structure (three tiers): (1) denominators — count of days where each metric had activity > 0; (2) 4-week totals — raw sums across the 28-day window; (3) daily benchmarks — totals / denominators (what Looker uses for relative level)
- `benchmark_locs_with_clock_ins`: **NOT stored** in the benchmark table. Derived in Looker as `denominator_clock_ins / 4.0` per location per DOW. `SUM()` across locations = expected open-location count (aggregate benchmark denominator for Businesses Open).

**Reference SQL:** see `workflows/indexed_values_query.sql` (full 3-year production query) and `workflows/create_benchmark_table.sql` (benchmark recreation script with verification queries).

**Benchmark tables — one created per year, refreshed annually every January:**

| Table | Schema | Reference period (confirmed) | Status |
|---|---|---|---|
| `location_usage_benchmarks_from_aph_jan_2018` | `corona` | 2018-01-04 to 2018-01-31 | Superseded |
| `location_usage_benchmarks_from_aph_jan_2019` | `corona` | 2019-01-04 to 2019-01-31 | Superseded |
| `location_usage_benchmarks_from_aph_jan_2020` | `corona` | 2020-01-04 to 2020-01-31 | Superseded |
| `location_usage_benchmarks_from_aph_jan_2021` | `corona` | 2021-01-09 to 2021-02-05 (extends into Feb) | Active |
| `location_usage_benchmarks_from_aph_jan_2022` | `corona` | 2022-01-03 to 2022-01-30 | Active |
| `location_usage_benchmarks_from_aph_jan_2023` | `corona` | 2023-01-08 to 2023-02-04 | Active |
| `location_usage_benchmarks_from_aph_jan_2024` | `corona` | 2024-01-07 to 2024-02-03 | Active |
| `location_usage_benchmarks_from_aph_jan_2025` | `corona` | 2025-01-05 to 2025-02-01 | Active |
| `location_usage_benchmarks_from_aph_jan_2026` | `corona` | 2026-01-04 to 2026-01-31 | Active — current year |
| `location_usage_benchmarks_from_aph_weekly` | `corona` | Weekly aggregates (Jan 6 – Feb 2, 2020 baseline) | Supporting |
| `location_metadata_benchmarks_from_aph` | `corona` | Team size metadata (Jan 4–31, 2020) | Supporting |

A new `_jan_YYYY` table must be created each January. See `workflows/data-sourcing.md` → "Recreating the Benchmark Table" for the full procedure.

**Supporting tables:**

| Table | Schema | What it provides | Status |
|---|---|---|---|
| `daily_agg_shifts_timecards_sales` | `corona` | **Deprecated.** Was a daily aggregation of `corona.shift_and_timecard_events` per location, with POS `has_sales` and `total_sales_dollars` columns added. MSHR never used sales data. If regenerating a benchmark, replace with an inline `GROUP BY location_id, state, msa, industry, city, event_date` aggregation from `corona.shift_and_timecard_events`. See `workflows/create_benchmark_table.sql`. | Inactive — do not use |
| `shifts_timecards_sales_aph` | `corona` | Date-spine table; provides a complete location × date grid for index calculations | Active |
| `jan_team_sizes` | `corona` | January weekly-average active users per location; used for team size benchmarking | Active |

---

### Ad Hoc Pipeline — Same Metrics, Richer Segmentation

**Not used for MSHR.** The DBT table `dbt.temp_timeclock_data` is built from the following source tables and is used for ad hoc reports that require richer segmentation (engagement flags, employee size bands, county codes, etc.).

| Table | Schema | What it provides | Notes |
|---|---|---|---|
| `shifts` | `ext_homebase1_public` | Scheduled shift records; `start_at`, `end_at`, `role_id` | |
| `jobs` | `ext_homebase1_public` | Roster entries; `location_id`, `user_id`, `archived_at` | |
| `timecards` | `ext_homebase1_public` | Clock-in/out records; `start_at`, `end_at` | Left join on shift — NULL = no clock-in |
| `role_wages` | `ext_homebase1_public` | Role-specific wage assignments | Not important for MSHR |
| `locations` | `public` | Location metadata | Use `business_type_new` for industry, not `business_type` |
| `users` | `public` | Filters to `highest_level_location` per user | Prevents double-counting across locations |
| `companies` | `public` | `onboarding_business_description` for industry | |
| `wage_history` | `public` | Hourly wage rates by job/role/date range | Not important for MSHR |
| `zip_to_county_code_map` | `operations` | Zip → county FIPS | Sub-regional breakdowns |
| `product_location_engagement_metrics` | `bizops` | Engagement flags; 30-day variants | Cohort filtering for ad hoc — see column definitions below |
| `fact_locations_by_day` | `public` | `employee_count`, `location_age`, `two_d_thirty_active` | See column definitions below |

**`public.locations` column definitions (key fields):**

| Column | Definition | Use in MSHR |
|---|---|---|
| `business_type_new` | **Canonical industry field.** 13 industries total. Always use this for industry breakdowns — not `business_type` (legacy). | Industry breakdowns |
| `business_category_new` | Granular subdivision within an industry. Multiple categories map to one `business_type_new`. Example: `business_type_new = "Food & Drink"` → `business_category_new = "Full-service restaurant"`. | Sub-industry breakdowns |
| `naics_code` | Industry classification code. Used to assign locations to an industry. Required non-null in the hiring/turnover consideration set as a data quality filter. | Consideration set filter |
| `business_type` | Legacy industry field. **Do not use.** Superseded by `business_type_new`. | Deprecated |

**`bizops.product_location_engagement_metrics` column definitions:**

| Column | Definition |
|---|---|
| `engagement_boolean` | See [Engaged (Core)](../../data/glossary.md) in the metrics glossary for the canonical definition. |
| `scheduling_engaged_boolean` | See [Scheduling Engaged](../../data/glossary.md) in the metrics glossary. |
| `engagement_boolean_30d_ago` | `engagement_boolean` measured as of 30 days prior to the current date. |
| `scheduling_engaged_boolean_30d_ago` | `scheduling_engaged_boolean` measured as of 30 days prior. |

**`public.fact_locations_by_day` column definitions:**

| Column | Definition |
|---|---|
| `two_d_thirty_active_this_month` | See [2D30](../../data/glossary.md) in the metrics glossary for the canonical definition. |
| `two_d_thirty_active_last_month` | Same 2D30 flag measured for the prior month. |
| `location_age` | Age of the location in **days** since `locations.created_at`. |
| `employee_count` | Count of employees at the location on that date. Used to classify locations into size bands. |

---

### Ad Hoc Weekly Aggregation — `dbt.new_data_weekly` and `dbt.new_state_data_weekly`

Pre-aggregated weekly tables built on top of `dbt.temp_timeclock_data`. Used for trend analysis, PR data requests, and any report that needs a time series of weekly activity. `dbt.new_data_weekly` is national; `dbt.new_state_data_weekly` is the same logic broken out by state.

**Reporting period:** Sunday to Saturday (complete weeks only). Different from the monthly MSHR window (28th–27th, ~25 days).

**For city- or MSA-level requests:** no city/MSA aggregation table exists. Filter `dbt.temp_timeclock_data` directly to the target `city` (from `public.locations`) or `msa` (from `corona.shift_and_timecard_events`) and apply the same qualification logic below.

#### Location Qualification Flags

Each location is evaluated per week against five independent flags. A location is included in a metric only if it passes the flag for that metric.

| Flag | Employee size band | Weeks active (of trailing 52) | Additional requirement |
|---|---|---|---|
| `qualified_for_jobs` | 5–100 employees | ≥12 weeks | Not archived this week |
| `qualified_for_turnover` | 10–100 employees | ≥12 weeks | Not archived this week |
| `qualified_for_hours` | 5–100 employees | ≥12 weeks | Not archived this week |
| `qualified_for_wages` | 5–100 employees | ≥12 weeks | `wage_coverage_ratio > 0.5`; not archived |
| `qualified_for_outlook` | 5–100 employees | ≥26 weeks (~6 months) | Not archived this week |

- **Employee size** = `employees_12w_avg`: 12-week rolling average of active employees at the location.
- **Weeks active** = `weeks_active_52w`: count of weeks in the trailing 52 weeks where the location had any activity.
- **Wage coverage** = fraction of hours that have an associated `hourly_wage_rate`. Threshold > 0.5 ensures the location has meaningful wage data.

#### Output Metrics

**Skip wages and survival metrics** for standard ad hoc reporting — they are included in the table but are not used in current outputs.

| Output column | Metric | Qualification flag | Definition |
|---|---|---|---|
| `active_location_count` | Active businesses | — (no flag) | Distinct locations with ≥1 clock-in in the week |
| `active_users` | Active employees | — (no flag) | Distinct users with ≥1 clock-in in the week |
| `avg_active_users_12w` | Rolling active users | — (no flag) | 12-week rolling average of `active_users` |
| `total_shifts` | Shifts created | — (no flag) | Count of shift records in the week |
| `users_added` | New employees (location growth) | `qualified_for_turnover` | Users whose **first-ever shift on the platform** (`MIN(event_date)` across all history) falls in the current week. One-time event per employee — fires the first time an employee appears anywhere on Homebase. Reflects workforce growth at the location level. |
| `users_archived` | Employees archived | `qualified_for_turnover` | Users with `archived_at` falling in the current week |
| `jobs_added` | Active job gains | `qualified_for_jobs` | Users who had a shift this week but **not** in the prior week (1-week lookback LEFT ANTI JOIN). **Recommended definition for future builds:** 4-week lookback — did this employee have a shift in any of the prior 4 weeks? If not, count them as newly active. Discuss lookback window with the requestor. |
| `jobs_archived` | Active job losses | `qualified_for_jobs` | Users who had a shift last week but not this week (inverse of `jobs_added`) |
| `hours_worked` | Hours worked | `qualified_for_hours` | Sum of `timecards.end_at − timecards.start_at` for the week |
| `hours_worked_with_wage` | Hours with wage data | `qualified_for_wages` | Hours worked where `hourly_wage_rate IS NOT NULL` |
| `hours_new_jobs` | Hours from newly active employees | `qualified_for_jobs` | Hours worked by employees in their first active week |
| `avg_hours_worked_per_loc` | Avg hours per location | `qualified_for_hours` | `hours_worked / active_location_count` |
| `future_shifts` | Future shift outlook | `qualified_for_outlook` | Shifts scheduled beyond the current date — **skip for standard reports** |
| `future_locs` | Locations with future shifts | `qualified_for_outlook` | Distinct locations with ≥1 future shift — **skip for standard reports** |
| `surviving_businesses_this_week` | 52-week survivors | `qualified_for_outlook` | Locations active this week that were also active 52 weeks ago — **skip for standard reports** |
| `surviving_businesses_last_52w` | Survival denominator | `qualified_for_outlook` | Locations active 52 weeks ago (denominator for survival rate) — **skip for standard reports** |
| `avg_nominal_wage` | Average hourly wage | `qualified_for_wages` | **Skip for standard reports** — use payroll cohort method instead |
| `avg_weekly_pay` | Average weekly pay | `qualified_for_wages` | **Skip for standard reports** — use payroll cohort method instead |

#### `users_added` vs. `jobs_added` — Key Distinction

These are different metrics measuring different stages of workforce activity:

| Metric | What it measures | Fires when | Use for |
|---|---|---|---|
| `users_added` | Employee enters Homebase for the first time | `MIN(event_date)` across all time falls this week | Location growth — how is the total workforce size changing? |
| `jobs_added` | Employee resumes activity after a gap | Had a shift this week but not last week | Labor market fluidity — how many workers are re-entering the workforce? |

---

### Payroll Pipeline — Hourly Wages (national, by industry, by state, by MSA)

| Table | Schema | What it provides | Join key | Notes |
|---|---|---|---|---|
| `payroll_payroll_runs` | `postgres` | One row per payroll run; `location_id`, `payday` | Filtered by `year(payday)` and `month(payday)` | Used twice: once for cohort start (12 months prior), once for cohort end (reporting month) |
| `shift_and_timecard_events` | `corona` | Event-level shift + timecard data; `hours_worked`, `total_wages_earned`, `job_id`, `location_id`, `timecard_created_at` | `location_id IN (cohort_start) AND location_id IN (cohort_end)` | Filtered to `timecard_created_at BETWEEN 2019-01-01 AND report_date`; equivalent grain to `dbt.temp_timeclock_data` |
| `locations` | `public` | `business_type` for industry breakdown; `state_cleaned` for state breakdown; `msa` for MSA breakdown | `locations.location_id = job_averages.location_id` | Filtered: `state NOT IN ('Not USA', 'Unclassified')` |

**Cohort definition:** a location qualifies if it appears in `postgres.payroll_payroll_runs` for both `(cohort_month_start, cohort_year_start)` AND `(cohort_month_end, cohort_year_end)` — exactly 12 months apart.

**Wage calculation (two-step):**
1. Per job per period: `wage_rate = SUM(total_wages_earned) / SUM(hours_worked)`
2. Across jobs: `AVG(wage_rate)` — treats each job equally regardless of hours worked

**`sample_size_jobs`** = `COUNT(DISTINCT job_id)` — the number of jobs (payroll runs) that reported an hourly wage in the period.

---

### Hiring & Turnover Pipeline — Jobs Added, Jobs Archived

| Table | Schema | What it provides | Join key | Notes |
|---|---|---|---|---|
| `jobs` | `postgres` | Employee-location activity records. Multiple rows per employee per location — one per work occurrence. `MIN(created_at)` per `(user_id, location_id)` = hire date. Subsequent rows = employee working. `archived_at` = turnover date. `uuid` uniquely identifies each row. | `location_info.location_id = jobs.location_id` | |
| `job_versions` | `postgres` | Audit log of changes to job records. `whodunnit` identifies who or what triggered the change (a user action, system worker, or rake task). Used to exclude system-driven archivations from turnover counts. **If turnover variance is >5% YoY, query this table to check for rake jobs and exclude them.** | `jv.item_id = jobs.id` AND `jv.created_at::date = jobs.archived_at::date` | Used for turnover quality control only |
| `companies` | `public` | `created_at` for company age filter | `location_info.company_id = companies.company_id` | |
| `locations` | `public` | `location_id`, `state_cleaned`, `msa`, `naics_code`, `business_type_new`, `business_category_new` | `consideration_set.company_id = locations.company_id` | Filtered: state not 'Not USA'/'Unclassified'; MSA, naics_code, business_type_new, business_category_new must be non-null |

**`postgres.jobs` column definitions:**

| Column | Definition |
|---|---|
| `id` / `job_id` | Unique identifier for the job record |
| `uuid` | Unique identifier for each row. Multiple rows exist per employee per location — one per work occurrence. `uuid` differentiates them. |
| `user_id` | Employee identifier |
| `location_id` | Location where the employee works |
| `created_at` | When this specific job row was created. Multiple rows exist per `(user_id, location_id)`: the first row (`MIN(created_at)`) = **employee hire date**; subsequent rows = the employee working on later days. Do not treat any single row's `created_at` as the hire date — always use `MIN(created_at)` per `(user_id, location_id)`. |
| `archived_at` | Date the job was archived. Used as the turnover date. NULL = still active. |

**Consideration set (`location_info`):** companies created >365 days before `year_beginning` (i.e., at least 1 year old at the start of the trailing-year window), with non-null MSA, NAICS code, business type, and business category.

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

---

## Example Queries

### Setup — Python Date Calculation and Temp Views

Run this setup code once per session in Databricks before running any of the queries below.

**Step 1 — Calculate cohort dates (Python)**

```python
import arrow
import pandas as pd

current_date = arrow.utcnow()
if arrow.now().day > 27:
    report_end_date = arrow.get(current_date.year, current_date.month, 27)
else:
    report_end_date = current_date.shift(months=-1).replace(day=27)

DATE = report_end_date.format('YYYY-MM-DD')

cohort_year_start  = report_end_date.shift(years=-1).year
cohort_year_end    = report_end_date.year
cohort_month_start = report_end_date.shift(years=-1).month
cohort_month_end   = report_end_date.month
```

**Step 2 — Create `month_end_dates` temp view (used by all queries)**

```sql
WITH exploded_dates AS (
    SELECT EXPLODE(sequence(to_date('2019-01-27'), to_date('{DATE}'), interval 1 month)) AS month_end
)
SELECT
    date_add(ADD_MONTHS(month_end, -12), 1) AS year_beginning,
    date_add(ADD_MONTHS(month_end, -1), 1)  AS month_beginning,
    month_end
FROM exploded_dates
```

Register as temp view: `spark.sql(...).createOrReplaceTempView('month_end_dates')`

**Step 3 — Create `consideration_set` temp view (used by hiring, turnover, shifts)**

Companies that had existing accounts at least one year ago. Excludes brand-new accounts from the sample.

```sql
SELECT company_id, created_at
FROM public.companies
WHERE created_at < date_add(current_date(), -365)
```

Register as temp view: `spark.sql(...).createOrReplaceTempView('consideration_set')`

**Step 4 — Create `location_info` temp view (used by hiring, turnover, shifts)**

Location metadata for the consideration set, filtered to US locations with clean industry/MSA data.

```sql
SELECT
    locations.location_id,
    consideration_set.company_id,
    consideration_set.created_at     AS company_created_date,
    locations.created_at             AS location_created_date,
    locations.naics_code,
    locations.msa,
    locations.state_cleaned          AS state,
    locations.business_type_new      AS business_type,
    locations.business_category_new  AS business_category
FROM consideration_set
INNER JOIN public.locations ON consideration_set.company_id = locations.company_id
WHERE locations.state_cleaned NOT IN ('Not USA', 'Unclassified')
    AND locations.msa               IS NOT NULL
    AND locations.naics_code        IS NOT NULL
    AND locations.business_type_new IS NOT NULL
    AND locations.business_category_new IS NOT NULL
```

Register as temp view: `spark.sql(...).createOrReplaceTempView('location_info')`

> **`ss` = sample size.** In every hiring, turnover, and shifts query, `COUNT(DISTINCT location_info.location_id) AS ss` is the number of qualifying locations in that reporting period. This is what flows into the D-Hiring+Turnover sheet as the `ss` column and is used as the denominator when normalizing per-location (`timeseries_data / ss`). The `ss` value comes from `location_info`, which is built from `consideration_set` — so the sample size is always the set of US locations at companies that existed at least one year before the reporting month.

---

### Payroll Cohort Average by Job (National)

```sql
WITH consideration_jobs_start AS (
    SELECT location_id FROM postgres.payroll_payroll_runs
    WHERE year(payday) = {cohort_year_start} AND month(payday) = {cohort_month_start}
),
consideration_jobs_end AS (
    SELECT location_id FROM postgres.payroll_payroll_runs
    WHERE year(payday) = {cohort_year_end} AND month(payday) = {cohort_month_end}
),
timeseries_data AS (
    SELECT * FROM corona.shift_and_timecard_events
    WHERE date(timecard_created_at) BETWEEN '2019-01-01' AND '{DATE}'
        AND location_id IN (SELECT location_id FROM consideration_jobs_start)
        AND location_id IN (SELECT location_id FROM consideration_jobs_end)
),
job_averages AS (
    SELECT
        month_end_dates.month_end AS period_end,
        timeseries_data.job_id,
        SUM(timeseries_data.total_wages_earned) / SUM(timeseries_data.hours_worked) AS wage_rate
    FROM timeseries_data
    JOIN month_end_dates ON timeseries_data.timecard_created_at::DATE
        BETWEEN month_end_dates.month_beginning AND month_end_dates.month_end
    GROUP BY period_end, job_id
)
SELECT
    period_end,
    AVG(wage_rate)          AS wage_rate,
    COUNT(DISTINCT job_id)  AS sample_size_jobs
FROM job_averages
GROUP BY period_end
HAVING sample_size_jobs > 20
ORDER BY period_end
```

### Payroll Cohort Average by Job by Industry

Uses the same `consideration_jobs_start`, `consideration_jobs_end`, and `timeseries_data` CTEs as the national query. Adds `location_id` to the `job_averages` GROUP BY, then joins to `public.locations` for the industry breakdown.

> **Note:** This production script uses `locations.business_type` (the legacy field). The canonical field for new queries is `locations.business_type_new` — but this script has not yet been migrated.

```sql
WITH consideration_jobs_start AS (
    SELECT location_id FROM postgres.payroll_payroll_runs
    WHERE year(payday) = {cohort_year_start} AND month(payday) = {cohort_month_start}
),
consideration_jobs_end AS (
    SELECT location_id FROM postgres.payroll_payroll_runs
    WHERE year(payday) = {cohort_year_end} AND month(payday) = {cohort_month_end}
),
timeseries_data AS (
    SELECT * FROM corona.shift_and_timecard_events
    WHERE date(timecard_created_at) BETWEEN '2019-01-01' AND '{DATE}'
        AND location_id IN (SELECT location_id FROM consideration_jobs_start)
        AND location_id IN (SELECT location_id FROM consideration_jobs_end)
),
job_averages AS (
    SELECT
        location_id,
        month_end_dates.month_end AS period_end,
        timeseries_data.job_id,
        SUM(timeseries_data.total_wages_earned) / SUM(timeseries_data.hours_worked) AS wage_rate
    FROM timeseries_data
    JOIN month_end_dates ON timeseries_data.timecard_created_at::DATE
        BETWEEN month_end_dates.month_beginning AND month_end_dates.month_end
    GROUP BY location_id, period_end, job_id
)
SELECT
    job_averages.period_end,
    locations.business_type,
    AVG(job_averages.wage_rate)        AS wage_rate,
    COUNT(DISTINCT job_averages.job_id) AS sample_size_jobs
FROM public.locations
INNER JOIN job_averages ON locations.location_id = job_averages.location_id
WHERE locations.state NOT IN ('Not USA', 'Unclassified')
GROUP BY locations.business_type, job_averages.period_end
HAVING sample_size_jobs > 20
ORDER BY locations.business_type, job_averages.period_end
```

### Payroll Cohort Average by State

Same CTEs as industry query above. Swap the final GROUP BY and SELECT to use `locations.state_cleaned`.

```sql
WITH consideration_jobs_start AS (
    SELECT location_id FROM postgres.payroll_payroll_runs
    WHERE year(payday) = {cohort_year_start} AND month(payday) = {cohort_month_start}
),
consideration_jobs_end AS (
    SELECT location_id FROM postgres.payroll_payroll_runs
    WHERE year(payday) = {cohort_year_end} AND month(payday) = {cohort_month_end}
),
timeseries_data AS (
    SELECT * FROM corona.shift_and_timecard_events
    WHERE date(timecard_created_at) BETWEEN '2019-01-01' AND '{DATE}'
        AND location_id IN (SELECT location_id FROM consideration_jobs_start)
        AND location_id IN (SELECT location_id FROM consideration_jobs_end)
),
job_averages AS (
    SELECT
        location_id,
        month_end_dates.month_end AS period_end,
        timeseries_data.job_id,
        SUM(timeseries_data.total_wages_earned) / SUM(timeseries_data.hours_worked) AS wage_rate
    FROM timeseries_data
    JOIN month_end_dates ON timeseries_data.timecard_created_at::DATE
        BETWEEN month_end_dates.month_beginning AND month_end_dates.month_end
    GROUP BY location_id, period_end, job_id
)
SELECT
    job_averages.period_end,
    locations.state_cleaned,
    AVG(job_averages.wage_rate)        AS wage_rate,
    COUNT(DISTINCT job_averages.job_id) AS sample_size_jobs
FROM public.locations
INNER JOIN job_averages ON locations.location_id = job_averages.location_id
WHERE locations.state NOT IN ('Not USA', 'Unclassified')
GROUP BY locations.state_cleaned, job_averages.period_end
HAVING sample_size_jobs > 20
ORDER BY locations.state_cleaned, job_averages.period_end
```

### Payroll Cohort Average by MSA

Same CTEs. Swap final GROUP BY and SELECT to use `locations.msa`.

```sql
WITH consideration_jobs_start AS (
    SELECT location_id FROM postgres.payroll_payroll_runs
    WHERE year(payday) = {cohort_year_start} AND month(payday) = {cohort_month_start}
),
consideration_jobs_end AS (
    SELECT location_id FROM postgres.payroll_payroll_runs
    WHERE year(payday) = {cohort_year_end} AND month(payday) = {cohort_month_end}
),
timeseries_data AS (
    SELECT * FROM corona.shift_and_timecard_events
    WHERE date(timecard_created_at) BETWEEN '2019-01-01' AND '{DATE}'
        AND location_id IN (SELECT location_id FROM consideration_jobs_start)
        AND location_id IN (SELECT location_id FROM consideration_jobs_end)
),
job_averages AS (
    SELECT
        location_id,
        month_end_dates.month_end AS period_end,
        timeseries_data.job_id,
        SUM(timeseries_data.total_wages_earned) / SUM(timeseries_data.hours_worked) AS wage_rate
    FROM timeseries_data
    JOIN month_end_dates ON timeseries_data.timecard_created_at::DATE
        BETWEEN month_end_dates.month_beginning AND month_end_dates.month_end
    GROUP BY location_id, period_end, job_id
)
SELECT
    job_averages.period_end,
    locations.msa,
    AVG(job_averages.wage_rate)        AS wage_rate,
    COUNT(DISTINCT job_averages.job_id) AS sample_size_jobs
FROM public.locations
INNER JOIN job_averages ON locations.location_id = job_averages.location_id
WHERE locations.state NOT IN ('Not USA', 'Unclassified')
GROUP BY locations.msa, job_averages.period_end
HAVING sample_size_jobs > 20
ORDER BY locations.msa, job_averages.period_end
```

### Hiring

```sql
SELECT
    month_end_dates.month_end AS period_end,
    COUNT(DISTINCT location_info.location_id) AS ss,
    COUNT(*) AS timeseries_data   -- new jobs created in period
FROM location_info
INNER JOIN postgres.jobs ON location_info.location_id = jobs.location_id
INNER JOIN month_end_dates ON jobs.created_at::DATE
    BETWEEN month_end_dates.month_beginning AND month_end_dates.month_end
WHERE location_info.state NOT IN ('Not USA')
    AND location_info.company_created_date < month_end_dates.year_beginning
GROUP BY period_end
ORDER BY period_end
```

### Turnover

```sql
SELECT
    month_end_dates.month_end AS period_end,
    COUNT(DISTINCT location_info.location_id) AS ss,
    COUNT(*) AS timeseries_data   -- jobs archived in period (organic departures only)
FROM location_info
INNER JOIN postgres.jobs ON location_info.location_id = jobs.location_id
INNER JOIN month_end_dates ON jobs.archived_at::DATE
    BETWEEN month_end_dates.month_beginning AND month_end_dates.month_end
LEFT JOIN postgres.job_versions jv
    ON jv.item_id = jobs.id AND jv.created_at::date = jobs.archived_at::date
WHERE location_info.state NOT IN ('Not USA')
    AND location_info.company_created_date < month_end_dates.year_beginning
    AND month_end_dates.month_end > '2018-12-01'
    AND lower(jv.whodunnit) NOT LIKE '%rake businesses:archive_invoiced_company%'
    AND lower(jv.whodunnit) NOT LIKE '%lockjobworker%'
    AND lower(jv.whodunnit) NOT LIKE '%handlejobterminationworker%'
GROUP BY period_end
ORDER BY period_end
```

### Shifts Worked

Requires `location_info` and `month_end_dates` temp views from Setup above.

```sql
SELECT
    month_end_dates.month_end                       AS period_end,
    COUNT(DISTINCT location_info.location_id)       AS ss,
    COUNT(*)                                        AS timeseries_data
FROM location_info
INNER JOIN corona.shift_and_timecard_events
    ON location_info.location_id = shift_and_timecard_events.location_id
JOIN month_end_dates
    ON shift_and_timecard_events.timecard_created_at::DATE
        BETWEEN month_end_dates.month_beginning AND month_end_dates.month_end
WHERE location_info.state NOT IN ('Not USA')
    AND location_info.company_created_date < month_end_dates.year_beginning
GROUP BY period_end
ORDER BY period_end
```

---

## MSHR Report Production Pipeline

The monthly PPTX report is generated from a single master Excel file: **`Main Street Health Report - 2026.xlsx`**. This section documents the full data flow from raw sources to published slide.

### File Architecture

```
Looker (daily indexed values)  ──►  D-sheets (raw data pulls)  ──►  Labor Activity / Wages Activity  ──►  PPTX slides
Python script (monthly wages,
  hiring, turnover)            ──►  D-sheets (raw data pulls)  ──┘
```

The Cover sheet tracks every published PPTX linked from the workbook, timestamped by publication date. It also defines the cell colour legend: input cells, hardcoded historical values, linked cells, and formula cells.

---

### D-Sheets — Data Inputs

Each D-sheet is a direct data pull. The O-sheets (calculation intermediates) are not needed for understanding or regenerating the report — all final numbers live in **Labor Activity** and **Wages Activity**.

#### `D-Employees_working` and `D-Hours_worked`

**Source:** Looker Explore `coronavirus_data_aph_jan_[YYYY]` (one explore per year, e.g. `coronavirus_data_aph_jan_2026`)

**Grain:** Daily. One row per calendar date. One column-pair per year (2022–2026).

| Looker field | Role |
|---|---|
| `Event Date Date.Date` | The calendar date |
| `(Aggregate) Changes Relative to Benchmark.Relative Level Agg Users with Clock In` | Indexed employees working — % above/below January baseline |
| `(Aggregate) Changes Relative to Benchmark.Relative Level Agg Total Hours Worked` | Indexed hours worked — % above/below January baseline |

**Important:** the index is computed inside Looker using the `corona.location_usage_benchmarks_from_aph_jan_[YYYY]` benchmark table. By the time data lands in the D-sheet, the value is already expressed as a relative level vs. January of that year. No further indexing is done in the spreadsheet.

#### `D-Regions`

Same Looker Explore as above, with `Region` added as a dimension.

| Looker field | Role |
|---|---|
| `Event Date Date.Date` | Calendar date |
| `Region` | One of: Mid-Atlantic, Midwest, Northeast, Other, Southeast, Southwest, West |
| `(Aggregate) Changes Relative to Benchmark.Relative Level Agg Locs with Clock Ins` | Indexed businesses open by region |

#### `D-Industry`

Same Looker Explore, with `Business Type` added as a dimension.

| Looker field | Role |
|---|---|
| `Event Date Date.Date` | Calendar date |
| `Business Type` | Industry label (matches `corona.shift_and_timecard_events.industry`) |
| `(Aggregate) Changes Relative to Benchmark.Relative Level Agg Users with Clock In` | Indexed employees working by industry |

Industries present in the data: Beauty & Wellness, Caregiving, Education, Entertainment, Food Drink & Dining, Home & Repair, Hospitality, Medical/Veterinary, Personal Services, Professional Services, Public/Nonprofit, Retail, Transportation & Logistics.

#### `D-Wage+Labour_cost`

**Source:** Python payroll cohort query (the matched-cohort wage script).

**Grain:** Monthly. Two sections side by side.

| Column | Definition |
|---|---|
| `segmented_by` | `'national'` for the overall cut |
| `period_end` | Month end date (27th of reporting month) |
| `wage_rate` | Average hourly wage — two-step matched-cohort calculation |
| `sample_size_jobs` | `COUNT(DISTINCT job_id)` for that period |
| `business_type` | Industry label (second section only — BY JOB AND INDUSTRY) |

Data runs from January 2019. The Jan 2022 national `wage_rate` = **$11.4829** — this is the fixed denominator for all "% above January 2022" calculations in the report.

#### `D-Hiring+Turnover`

**Source:** Python hiring/turnover query.

**Grain:** Monthly. Two sections (HIRING and TURNOVER) side by side.

| Column | Definition |
|---|---|
| `period_end` | Month end date (27th of reporting month) |
| `ss` | `COUNT(DISTINCT location_info.location_id)` — number of qualifying US locations in the period. Built from `consideration_set` → `location_info`. Used as the per-location normalization denominator: `timeseries_data / ss`. |
| `timeseries_data` | Raw count of jobs added (HIRING) or jobs archived (TURNOVER) |

Data runs from January 2019. Turnover data begins March 2019 (earlier months NULL).

---

### Calculation Layer — Labor Activity 2026

#### Reference date for each month

The report uses the **Sunday of the week containing the 12th** of each month as the anchor date. The 7-day window runs Sunday through Saturday (Sun ≤ date ≤ Sat).

Pre-computed reference Sundays:

| Month | 2024 | 2025 | 2026 |
|---|---|---|---|
| January | Jan 7 | Jan 12 | Jan 11 |
| February | Feb 11 | Feb 9 | Feb 8 |
| March | Mar 10 | Mar 9 | Mar 8 |
| April | Apr 14 | Apr 6 | Apr 12 |
| May | May 12 | May 11 | May 10 |
| June | Jun 9 | Jun 8 | Jun 7 |
| July | Jul 7 | Jul 6 | Jul 12 |
| August | Aug 11 | Aug 10 | Aug 9 |
| September | Sep 8 | Sep 7 | Sep 6 |
| October | Oct 6 | Oct 12 | Oct 11 |
| November | Nov 10 | Nov 9 | Nov 8 |
| December | Dec 8 | Dec 7 | Dec 6 |

When adding a new year, compute the reference Sunday for each month as: `DATE_TRUNC('week', DATE([year]-[month]-12))` (Trino/Presto: week starts Sunday by default).

#### 7-day rolling average

```
avg_indexed_value = AVERAGE(indexed_value WHERE date IN [sunday .. saturday])
```

Applied to whichever D-sheet column corresponds to the target year. The 7-day window smooths out day-of-week effects.

#### Month-over-month change

```
MoM_change = avg_indexed_value(current_month) − avg_indexed_value(prior_month)
```

Both averages are already in indexed units (relative to January of each year). The difference is therefore the MoM change in the indexed series — which is what slides 3, 4, 5, and 6 display. There is **no additional division** — the subtraction of two indexed values gives the percentage-point change directly.

#### How to read the chart values

The chart shows three years overlaid (e.g. 2024, 2025, 2026). Each year's series starts at 0 in January and accumulates from there. A value of +0.018 for May → June in 2025 means: the indexed level of employees working in the June reference week was 1.8 percentage points higher than in the May reference week of 2025, each relative to that year's January baseline.

**You cannot compare absolute levels across years from these charts.** For absolute comparison, use the absolute `wage_rate` values in `D-Wage+Labour_cost` or query the underlying corona/payroll tables directly.

---

### Calculation Layer — Wages Activity 2026

#### Absolute wages (Slide 8)

Direct pass-through from `D-Wage+Labour_cost.wage_rate` per `period_end` per `business_type`. No transformation. Plotted as dollar values on the time series.

Industries shown in the published report: Food & Drink, Entertainment (Leisure & Entertainment), Retail, Health Care, Professional Services, Total (national all-industry).

#### Wages relative to January 2022 (Slide 7)

```
pct_above_jan2022 = (current_wage_rate − 11.4829) / 11.4829
```

The $11.4829 denominator is the national `wage_rate` for the period ending 2022-01-27 — the first full month after Homebase Payroll matured (product launched 2021, first complete year 2022). This baseline never changes across reports.

#### MoM % change in wages by industry

```
MoM_pct_change = (current_month_wage / prior_month_wage) − 1
```

Computed per industry from the BY JOB AND INDUSTRY section of `D-Wage+Labour_cost`. Used in slide subheads to state month-level wage movements.

#### Hiring per location (Slide 9) — normalization-first order

```
Step 1 — Normalize:     jobs_per_loc = timeseries_data / ss
Step 2 — MoM change:   MoM_pct = (current_month_jobs_per_loc / prior_month_jobs_per_loc) − 1
Step 3 — Index to Jan: cumulative_change = (current_month_jobs_per_loc − jan_jobs_per_loc) / jan_jobs_per_loc
```

**Normalization comes before MoM calculation**, not after. This prevents the growing consideration set (`ss`) from artificially inflating or deflating the apparent MoM change. January of each year resets the index to 0.

National benchmarks (jobs added per location per month):
- Jan 2026: 2.34 | Jan 2025: 2.39 | Jan 2024: 2.58 | Jan 2023: 2.73

#### Turnover per location (Slide 10)

Identical three-step calculation using the TURNOVER section of `D-Hiring+Turnover`.

National benchmarks (jobs archived per location per month):
- Jan 2026: 3.10 | Jan 2025: 3.20 | Jan 2024: 3.35 | Jan 2023: 3.42

---

### Narrative Language Patterns

The report is written for external audiences (press, economists, policy analysts). Every slide follows the same structure:

| Element | Formula | Example |
|---|---|---|
| **Slide title** | Active verb phrase naming the direction | "Workforce Participation Stalls Heading Into Spring" |
| **Subtitle** | Actual number + prior-year comparison + economic inference | "April marked the first negative Mar–Apr reading in three years (-0.2%), reversing the +1.1% to +1.2% gains seen in 2024 and 2025..." |
| **Chart note** | Literal data definition | "Data compares rolling 7-day averages for weeks encompassing the 12th of each month." |

**Recurring framing rules:**
- Always show 3 years (current + prior 2). The current year is framed as "above," "below," or "tracking" prior years.
- Lead with the number, then the interpretation: never interpret without citing the specific value.
- Seasonal moves are acknowledged — declines described as "consistent with seasonal patterns" unless anomalous.
- Small business agency language: SMBs "manage payroll cautiously," "hire to backfill," "correct for over-hiring" — never passive.
- Wages and labor activity are frequently contrasted to surface the divergence story (fewer workers, higher pay).
- Slide 2 (At A Glance) synthesizes all six metrics into a one-paragraph month title and three segment takeaways (Workforce & Hours / Industry & Region / Hiring & Turnover).

**Report cadence observed from Cover sheet:**
The PPTX is published in two packs historically (Pack 1 = labor metrics shortly after month end; Pack 2 = wages + hiring/turnover ~2 weeks later). Starting with the 2025 series this merged into a single monthly release.
