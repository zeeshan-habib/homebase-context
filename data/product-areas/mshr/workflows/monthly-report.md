---
owner: vlad
last_updated: 2026-05-26
review_cadence: monthly
next_review: 2026-06-26
source: internal
refs: []
---

<!-- Load when: producing the monthly MSHR report — end-to-end steps, pre-flight checklist, and QA -->

# Monthly MSHR Production Workflow

## Overview

The monthly MSHR runs on a fixed calendar cadence. It produces the full set of six employment metrics for the prior reporting month and feeds the public-facing report that leadership and GTM publish. All scope, time grain, geographic cuts, and output format are predetermined — there are no clarifying questions to ask before starting.

---

## When to Use This Workflow

Use this workflow when **all four conditions are true:**

- The request is the regularly scheduled monthly report — not a one-off, scoped, or event-driven cut
- The reporting month has closed (today's date is past the 27th of the month being reported)
- All three source tables confirm data through the cutoff date (see Pre-Flight Checklist below)
- The master Excel workbook is accessible and up to date

IF the request comes from Ray Sanza, Katie Dare, Vlad, or GTM **outside** of the monthly calendar → use `adhoc-report.md` instead.

IF the request mentions an event (sporting event, natural disaster, policy announcement) → use `adhoc-report.md` and invoke `event-impact-template.py`.

IF the request is the standard monthly report but wages, hiring, or turnover are needed for a specific state, city, or industry cut → use this workflow for the national run, then follow up with `adhoc-report.md` for the segmented cut.

---

## Pre-Flight Checklist

**Confirm all of these before pulling any data or running any script.**

### 1. Data cutoff

Cutoff = 27th of the reporting month. All three source tables must have data through this date:

```sql
SELECT MAX(event_date)                FROM corona.shift_and_timecard_events;  -- must be >= cutoff
SELECT MAX(payday)                    FROM postgres.payroll_payroll_runs;      -- must be >= cutoff
SELECT MAX(created_at), MAX(archived_at) FROM postgres.jobs;                  -- must be >= cutoff
```

If any table falls short: stop. Do not proceed until the data engineering team confirms the table is refreshed.

### 2. Reporting period variables

Compute these once — they are used in every script:

| Variable | Formula | Example (reporting month = April 2026) |
|---|---|---|
| `DATE` | 27th of the reporting month | `2026-04-27` |
| `cohort_month_end` / `cohort_year_end` | Month and year of `DATE` | `4` / `2026` |
| `cohort_month_start` / `cohort_year_start` | Same month, one year prior | `4` / `2025` |
| Reference Sunday | Sunday of the week containing the 12th of the reporting month | Run `date_sub(make_date(yr, mo, 12), (dayofweek(make_date(yr, mo, 12))-1) % 7)` |

### 3. Tooling access

- [ ] Looker Explore `coronavirus_data_aph_jan_[current_year]` loads without error
- [ ] Databricks notebook environment is accessible and warehouse `16984dfe9a2c3705` is running
- [ ] Master Excel workbook (`Main Street Health Report - [year].xlsx`) is open and editable
- [ ] Sign-off contacts reachable: **Ray Sanza** (narrative) and **Vlad** (data accuracy)

---

## Table Selection

| Metric | Source table | Query to use |
|---|---|---|
| Employees Working | `corona.shift_and_timecard_events` + `corona.location_usage_benchmarks_from_aph_jan_[YYYY]` | `indexed_values_query.sql` or Looker Explore |
| Hours Worked | Same as above | Same |
| Businesses Open | Same as above | Same |
| Wages — national | `corona.shift_and_timecard_events` + `postgres.payroll_payroll_runs` + `public.locations` | `../mshr.md → ### Payroll Cohort Average by Job (National)` |
| Wages — by industry | Same tables | `../mshr.md → ### Payroll Cohort Average by Job by Industry` |
| Jobs Added (hiring) | `postgres.jobs` + `postgres.job_versions` + consideration CTEs | `../mshr.md → ### Hiring` |
| Jobs Archived (turnover) | Same tables + `whodunnit` exclusions | `../mshr.md → ### Turnover` |

> **Never use `dbt.new_data_weekly` or `dbt.temp_timeclock_data` for any monthly metric.** Those tables feed the ad hoc track. The monthly pipeline uses `corona.shift_and_timecard_events` directly, indexed against pre-built benchmark tables.

> **Wages are always payroll cohort — no exceptions.** Whether national or by-industry, the cohort filters to locations that ran payroll in both `cohort_month/year_start` and `cohort_month/year_end`. Do not use `dbt` tables for wages.

---

## Date and Anchor Date Logic

The report period always ends on the **27th of the reporting month**. This is the `month_end` value in the `month_end_dates` CTE sequence.

```python
# mirrors PR_Standard_EOM_Metrics.ipynb cell 2 exactly
current_date = arrow.utcnow()
if arrow.now().day > 27:
    report_end_date = arrow.get(current_date.year, current_date.month, 27)
else:
    report_end_date = current_date.shift(months=-1).replace(day=27)

DATE = report_end_date.format("YYYY-MM-DD")
```

**Reference Sunday** — the anchor for the 7-day rolling average used in labor metrics:
- Definition: the Sunday of the calendar week that contains the 12th of the reporting month
- Used in both the Looker export and the `indexed_values_query.sql`
- Pre-computed reference table lives in `../mshr.md → ## Reference Sundays`

**Jan 2022 wage baseline** — used for `% above Jan 2022` wage metric:
- Never hardcoded. Derived each run from the national wage query: find the row where `period_end` starts with `"2022-01"` and read its `wage_rate`.
- Changes slightly each run due to retroactive payroll corrections.

---

## Industry Classification

The by-industry wage query uses `locations.business_type` — the **legacy column** — to match the reference notebook (`PR_Standard_EOM_Metrics.ipynb` cell 5) exactly. Do not change to `business_type_new` without re-validating industry label parity.

For the 13 broad industry classifications and their sub-categories, see `adhoc-report.md → Industry Classification`. The same 13 categories apply to both tracks. The monthly workflow uses the legacy `business_type` column; the ad hoc track uses the normalized `business_type_new`.

---

## Production Steps

**Step 1 — Run pre-flight checklist**

Confirm all three items in the Pre-Flight Checklist above. Do not proceed until all pass.

**Step 2 — Labor metrics (Employees Working, Hours Worked, Businesses Open)**

Option A — Looker (standard):
Open Looker Explore `coronavirus_data_aph_jan_[current_year]`. Export three series:
- `Relative Level Agg Users with Clock In` → `D-Employees_working` and `D-Industry` sheets
- `Relative Level Agg Total Hours Worked` → `D-Hours_worked` sheet
- `Relative Level Agg Locs with Clock Ins` with Region dimension → `D-Regions` sheet

Paste the daily indexed values into the corresponding D-sheets in the master Excel workbook. Values arrive already indexed to January of the current year — no further indexing required.

Option B — Direct Databricks SQL (if Looker is unavailable or needs verification):
Run `indexed_values_query.sql` in Databricks against warehouse `16984dfe9a2c3705`. This query covers 2024/2025/2026, applies the benchmark join, and outputs indexed values with MoM ppt changes directly.

**Step 3 — Wages (national + by industry)**

Run the Setup section of the reference notebook first (date variables + `month_end_dates` CTE). Then:

```python
# Set cohort window before running either wage query
cohort_year_start  = DATE_year - 1   # or same month, one year prior
cohort_month_start = DATE_month
cohort_year_end    = DATE_year
cohort_month_end   = DATE_month
```

**National wages:** use `../mshr.md → ### Payroll Cohort Average by Job (National)`. Paste `period_end`, `wage_rate`, `sample_size_jobs` into the national section of `D-Wage+Labour_cost`.

**By-industry wages:** use `../mshr.md → ### Payroll Cohort Average by Job by Industry`. Paste `period_end`, `business_type`, `wage_rate`, `sample_size_jobs` into the by-industry section of `D-Wage+Labour_cost`.

QA gate — before pasting: confirm `sample_size_jobs > 20` for **every** segment. Any segment below 20 must be suppressed from the published output.

**Step 4 — Hiring and turnover**

Run the Setup section of the reference notebook to create `consideration_set` and `location_info` temp views. Then:

**Hiring:** use `../mshr.md → ### Hiring`. Paste `period_end`, `ss`, `timeseries_data` into the HIRING section of `D-Hiring+Turnover`. `ss` = `COUNT(DISTINCT location_id)` from `location_info` — the per-location normalization denominator.

**Turnover:** use `../mshr.md → ### Turnover`. Paste `period_end`, `ss`, `timeseries_data` into the TURNOVER section of `D-Hiring+Turnover`. Same `ss` definition.

QA gate — before pasting: check turnover variance vs prior year. If > 5% variance, query `postgres.job_versions.whodunnit` for rake/lock/termination system archivations and re-run with exclusions before pasting.

**Step 5 — Excel auto-calculation**

Once all D-sheets are updated, the Labor Activity and Wages Activity sheets recalculate automatically:

| Sheet | What it computes |
|---|---|
| Labor Activity | 7-day rolling average over the Reference Sunday window; MoM change = current avg − prior avg (both already indexed — result is percentage-point change, no division) |
| Wages Activity | `% above Jan 2022 = (wage_rate − baseline) / baseline`; MoM % change per industry; hiring/turnover normalized as `timeseries_data / ss` → MoM change → indexed to January |

Verify the Reference Sunday used in the Labor Activity sheet matches the pre-computed table in `../mshr.md → ## Reference Sundays`.

**Step 6 — QA**

Run the full QA Checklist below before moving to PPTX assembly.

**Step 7 — PPTX assembly**

Update each slide with final values from the Labor Activity and Wages Activity sheets:
- Slide 2 (At A Glance): synthesize all six metrics into 2–3 headline statements
- Slide titles and subtitles: follow the narrative language patterns in `../mshr.md`
- Chart notes: flag any metric that moved > 3 ppt MoM with a brief inline note

**Step 8 — Review and publish**

Ray Sanza: narrative framing and headline metric accuracy.
Vlad: data accuracy and suppression rule compliance.

On approval: save final PPTX. Log it in the Cover sheet of the master Excel workbook with the publication date.

---

## QA Checklist

Run every item before Step 7 (PPTX assembly). Do not proceed to publishing if any item is unresolved.

- [ ] All three source tables: `MAX(date) >= 27th of reporting month`
- [ ] D-sheet row counts extend through the cutoff date — no missing days in any column
- [ ] Wage suppression: `sample_size_jobs > 20` for every national and industry segment being published — suppress any segment below this threshold
- [ ] Turnover variance vs prior year: if >= 5%, confirm `whodunnit` exclusions were applied and re-run before pasting
- [ ] Reference Sunday: the anchor used in Labor Activity matches the pre-computed table in `../mshr.md → ## Reference Sundays`
- [ ] MoM delta review: any movement > 3 percentage points flagged for manual review and noted in the PPTX
- [ ] End-to-end trace: at least one metric traced from D-sheet value → Labor/Wages Activity calculation → PPTX slide value
- [ ] Normalization order: hiring/turnover divided by `ss` first, then MoM change computed — not the reverse
- [ ] Jan 2022 wage baseline: derived dynamically from the national query result, not hardcoded
- [ ] Ray Sanza sign-off received before external distribution or publication

---

## Key Differences from Ad Hoc Workflow

| Dimension | Monthly | Ad Hoc |
|---|---|---|
| Trigger | Calendar cadence | Leadership / GTM request, event, or external inquiry |
| Scope | All six metrics — fixed | Subset defined by the requester |
| Time grain | Monthly (28th–27th); 7-day rolling avg around Reference Sunday | Weekly (Sun–Sat) or custom; raw counts or simple % change |
| Geographic cuts | National + by-industry + by-state (fixed) | Flexible — national, state, MSA, city, or custom |
| Index baseline | January of current year = 0; metrics expressed relative to it | No indexing — raw counts or YoY % change |
| MoM change | `current_month_avg − prior_month_avg` (both indexed; result is ppt change) | `(current_week − prior_week) / prior_week` |
| Wages | Payroll cohort; denominator anchored to Jan 2022 for % framing | Same payroll cohort method — `dbt` tables never used for wages |
| Primary labor table | `corona.shift_and_timecard_events` + benchmark join | `dbt.new_data_weekly` or `dbt.temp_timeclock_data` |
| Output format | PPTX slide deck (fixed) | Varies: slide deck, CSV, one-pager, talking points |
| Sign-off | Ray Sanza (required) + Vlad | Ray Sanza or Vlad |
| Clarifying questions | None — scope is fixed | Ask all 4 questions before pulling any data |
