---
owner: vlad-akimenko
last_updated: 2026-05-28
review_cadence: monthly
next_review: 2026-06-28
source: internal
refs:
  - data/product-areas/mshr/mshr.md
  - data/product-areas/mshr/index-methodology.md
---

# MSHR — Pipeline Schemas

Load when you need to understand what tables MSHR is built from, what columns exist in each pipeline, how source tables are joined, or how entities map across pipelines.

For metric definitions, terminology, and suppression rules, see `mshr.md`. For index formulas and benchmark construction, see `index-methodology.md`.

---

## MSHR Pipeline — Employees Working, Hours Worked, Businesses Open

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

## Ad Hoc Pipeline — Same Metrics, Richer Segmentation

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

## Ad Hoc Weekly Aggregation — `dbt.new_data_weekly` and `dbt.new_state_data_weekly`

Pre-aggregated weekly tables built on top of `dbt.temp_timeclock_data`. Used for trend analysis, PR data requests, and any report that needs a time series of weekly activity. `dbt.new_data_weekly` is national; `dbt.new_state_data_weekly` is the same logic broken out by state.

**Reporting period:** Sunday to Saturday (complete weeks only). Different from the monthly MSHR window (28th–27th, ~25 days).

**For city- or MSA-level requests:** no city/MSA aggregation table exists. Filter `dbt.temp_timeclock_data` directly to the target `city` (from `public.locations`) or `msa` (from `corona.shift_and_timecard_events`) and apply the same qualification logic below.

### Location Qualification Flags

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

### Output Metrics

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

### `users_added` vs. `jobs_added` — Key Distinction

These are different metrics measuring different stages of workforce activity:

| Metric | What it measures | Fires when | Use for |
|---|---|---|---|
| `users_added` | Employee enters Homebase for the first time | `MIN(event_date)` across all time falls this week | Location growth — how is the total workforce size changing? |
| `jobs_added` | Employee resumes activity after a gap | Had a shift this week but not last week | Labor market fluidity — how many workers are re-entering the workforce? |

---

## Payroll Pipeline — Hourly Wages (national, by industry, by state, by MSA)

| Table | Schema | What it provides | Join key | Notes |
|---|---|---|---|---|
| `payroll_payroll_runs` | `postgres` | One row per payroll run; `location_id`, `payday` | Filtered by `year(payday)` and `month(payday)` | Used twice: once for cohort start (12 months prior), once for cohort end (reporting month) |
| `shift_and_timecard_events` | `corona` | Event-level shift + timecard data; `hours_worked`, `total_wages_earned`, `job_id`, `location_id`, `timecard_created_at` | `location_id IN (cohort_start) AND location_id IN (cohort_end)` | Filtered to `timecard_created_at BETWEEN 2019-01-01 AND report_date`; equivalent grain to `dbt.temp_timeclock_data` |
| `locations` | `public` | `business_type_new` for industry breakdown; `state_cleaned` for state breakdown; `msa` for MSA breakdown | `locations.location_id = job_averages.location_id` | Filtered: `state NOT IN ('Not USA', 'Unclassified')` |

**Cohort definition:** a location qualifies if it appears in `postgres.payroll_payroll_runs` for both `(cohort_month_start, cohort_year_start)` AND `(cohort_month_end, cohort_year_end)` — exactly 12 months apart.

**Wage calculation (two-step):**
1. Per job per period: `wage_rate = SUM(total_wages_earned) / SUM(hours_worked)`
2. Across jobs: `AVG(wage_rate)` — treats each job equally regardless of hours worked

**`sample_size_jobs`** = `COUNT(DISTINCT job_id)` — the number of jobs (payroll runs) that reported an hourly wage in the period.

---

## Hiring & Turnover Pipeline — Jobs Added, Jobs Archived

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
