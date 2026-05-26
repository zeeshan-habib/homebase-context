---
owner: vlad
last_updated: 2026-05-24
review_cadence: quarterly
next_review: 2026-08-24
source: internal
refs:
  - global/business-overview.md
  - data/product-areas/mshr/mshr.md
---
# MSHR Data Model

Load when you need to understand what data MSHR is built from, how MSHR entities relate to core Homebase entities, or how raw product data becomes publishable report data.

For full column definitions, SQL patterns, and suppression rules, see `mshr.md` — that file is the canonical source.

## Data Sources

Three independent pipelines feed MSHR. Each uses a different source table and a different aggregation method.

| Data Source | Homebase Product | What it captures | Aggregation applied |
|---|---|---|---|
| `corona.shift_and_timecard_events` | Scheduling + Time Clock | Shifts, clock-ins, hours worked, employee-location pairings at event grain | Daily indexed values (via Looker Explore `coronavirus_data_aph_jan_[YYYY]`) → 7-day rolling average around the 12th of each month |
| `postgres.jobs` + `postgres.job_versions` | Scheduling | Employee roster entries — hire dates (`MIN(created_at)`), turnover (`archived_at`) | Monthly count of new and archived jobs per location consideration set; system archivations excluded via `job_versions.whodunnit` |
| `postgres.payroll_payroll_runs` + `corona.shift_and_timecard_events` | Homebase Payroll | Matched-cohort wage rates for locations running Payroll in both the reporting month and 12 months prior | Monthly average hourly wage per `job_id`; suppressed at `sample_size_jobs ≤ 20` |

**Ad hoc reports** use a fourth source: `dbt.temp_timeclock_data` (DBT-built, enriched with engagement flags and size bands). This table is **not used for monthly MSHR** — it supports custom segmentation only.

## Key Entities

### Business (Location)

In MSHR, "business" always means a single physical location — not a company. One company may own multiple locations; each location is counted independently.

Maps to `locations.location_id`. Filtered to US only (`state NOT IN ('Not USA', 'Unclassified')`). Grouped by `locations.business_type_new` for industry breakdowns (13 categories — use `business_type_new`, not legacy `business_type`).

### Employee (User)

An hourly worker counted via `COUNT(DISTINCT user_id WHERE has_clock_in = 1)` in the reference week. In the monthly MSHR corona pipeline, an employee may be counted at multiple locations if they work at more than one. In the ad hoc pipeline (`dbt.temp_timeclock_data`), employees are filtered to `highest_level_location` to prevent double-counting.

### Job (Wage Context)

For wages, "job" still refers to a roster entry from `postgres.jobs` — the same employee-location pairing used for hiring and turnover. The `job_id` in `corona.shift_and_timecard_events` originates from `postgres.jobs`.

`postgres.payroll_payroll_runs` plays a different role: it defines which **locations** qualify for the wage cohort (locations that ran Homebase Payroll in both the reporting month and 12 months prior). It does not contain the job records or wage amounts themselves. Once the cohort locations are identified, `corona.shift_and_timecard_events` is filtered to those locations and `job_id` (from `postgres.jobs`) is used as the wage calculation grain.

**Rule:** when talking about wages → refer to `postgres.payroll_payroll_runs` to define the cohort. When talking about jobs (hiring, turnover, roster) → refer to `postgres.jobs` directly. Never conflate the two tables.

### Payroll Cohort

Locations that appear in `postgres.payroll_payroll_runs` for **both** the reporting month and the same month one year prior. This matched cohort is used for all wage calculations to ensure YoY comparisons are apples-to-apples.

## Relationship to Core Homebase Entities

| MSHR Concept | Maps to Homebase Entity | Caveats |
|---|---|---|
| Business | Location (`locations.location_id`) | US only; single physical site, not a company |
| Employee (Employees Working) | User (`jobs.user_id`) WHERE `has_clock_in = 1` | Distinct count in reference week only; not cumulative roster |
| Hours Worked | Timecard duration (`timecards.end_at − timecards.start_at`) | NULL if no clock-in; does not include scheduled-only hours |
| Jobs Added (MSHR) | `MIN(postgres.jobs.created_at)` per `(user_id, location_id)` | First job row per employee per location = hire date; subsequent rows are not new hires |
| Jobs Archived (MSHR) | `postgres.jobs.archived_at` falling in the reference month | System-driven archivations excluded via `job_versions.whodunnit` |
| Industry | `locations.business_type_new` | 13 categories; do NOT use legacy `business_type` |
| Month | 28th of prior calendar month to 27th of current | Not a standard calendar month |
| Job (wage calculation grain) | `postgres.jobs` roster entry, accessed via `corona.shift_and_timecard_events.job_id` | `job_id` is a `postgres.jobs` ID, not a payroll run. `postgres.payroll_payroll_runs` is used only to filter which locations are in the cohort. |

## Anonymization and Privacy Rules

| Rule | Applies to | Threshold |
|---|---|---|
| Minimum jobs for wage publication | Payroll pipeline — any national or segment cut | `HAVING sample_size_jobs > 20` — suppress any period/segment at or below this |
| US locations only | All metrics | `state NOT IN ('Not USA', 'Unclassified')` |
| Company age | Hiring & Turnover consideration set | Company `created_at` must be > 365 days before `year_beginning` of the trailing window |
| Non-null geography and industry | Hiring & Turnover consideration set | `msa`, `naics_code`, `business_type_new`, `business_category_new` must all be non-null |
| No individual location data | All public outputs | All published metrics are national or segment aggregates — no location-level data is surfaced |

## Common Confusion Points

| Confusion | Clarification |
|---|---|
| "Business" = company | "Business" in MSHR = a single location. One company can have many locations, each counted separately. |
| `hours_worked` vs scheduled hours | `hours_worked` = `timecards.end_at − timecards.start_at` (actual clock-in duration). Scheduled hours = `shifts.end_at − shifts.start_at`. Use `hours_worked` for all MSHR metrics. |
| Using `corona` wage fields for wages | Do NOT use `corona.shift_and_timecard_events.hourly_wage_rate` or `total_wages_earned` for MSHR wages — they are owner self-reported and overpopulated. Use the payroll cohort method via `postgres.payroll_payroll_runs`. |
| `business_type` vs `business_type_new` | Always use `locations.business_type_new` (13 categories). `business_type` is the legacy field — deprecated. |
| `jobs_added` in MSHR vs ad hoc | In MSHR: `MIN(postgres.jobs.created_at)` per employee per location = hire date. In ad hoc weekly: employees who had a shift this week but not last week (activity gap). Completely different concepts. |
| `sample_size_jobs` = payroll run count or employee count | `sample_size_jobs` = `COUNT(DISTINCT job_id)` — number of unique `postgres.jobs` roster entries (employee-location pairings) that had payroll wage data. Not a payroll run count, not an employee headcount. |
| `postgres.jobs` = payroll table | `postgres.jobs` is the roster table (hiring, turnover). `postgres.payroll_payroll_runs` is the payroll table (used only for cohort location selection). Always use `payroll_payroll_runs` to define the wage cohort, and `postgres.jobs` for any job-level roster analysis. |
| Month = calendar month | MSHR month runs 28th of the prior calendar month to 27th of the current calendar month. |
| `postgres.*` vs `ext_homebase1_public.*` | These are interchangeable — they point to the same underlying data. The corona pipeline uses `postgres.*`; the DBT ad hoc pipeline uses `ext_homebase1_public.*`. |
