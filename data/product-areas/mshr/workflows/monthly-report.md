---
owner: vlad
last_updated: 2026-05-14
review_cadence: monthly
next_review: 2026-06-14
source: internal
refs: []
---

# Monthly MSHR Production Workflow

## Overview

The monthly MSHR runs on a fixed calendar cadence. It produces the full set of employment metrics for the prior month and feeds the public-facing report that leadership and GTM publish.

## Production Steps

**Step 1 — Confirm data cutoff**

Cutoff = 27th of the reporting month (`month_end` in the month_end_dates sequence).

```sql
SELECT MAX(event_date)  FROM corona.shift_and_timecard_events;  -- must be ≥ cutoff
SELECT MAX(payday)       FROM postgres.payroll_payroll_runs;      -- must be ≥ cutoff
SELECT MAX(created_at), MAX(archived_at) FROM postgres.jobs;      -- must be ≥ cutoff
```

**Step 2 — Looker pull (labor metrics)**

Open Looker Explore `coronavirus_data_aph_jan_[current_year]`. Export:
- `Relative Level Agg Users with Clock In` → D-Employees_working and D-Industry
- `Relative Level Agg Total Hours Worked` → D-Hours_worked
- `Relative Level Agg Locs with Clock Ins` with Region dimension → D-Regions

Paste daily indexed values into the corresponding D-sheets in `Main Street Health Report - 2026.xlsx`. Values arrive already indexed to January of the current year — no further indexing needed.

**Step 3 — Python script runs (wages, hiring, turnover)**

All three scripts use the queries defined in `../mshr.md → ## Example Queries`. Run the **Setup** section first (Python date calculation + `month_end_dates`, `consideration_set`, `location_info` temp views) before running any of the queries below.

**Wages — national:**
Use `### Payroll Cohort Average by Job (National)`. Set cohort variables to: `cohort_month/year_end` = reporting month, `cohort_month/year_start` = same month one year prior. Paste `period_end`, `wage_rate`, `sample_size_jobs` into D-Wage+Labour_cost (national section).

**Wages — by industry:**
Use `### Payroll Cohort Average by Job by Industry`. Same cohort variables. Paste `period_end`, `business_type`, `wage_rate`, `sample_size_jobs` into D-Wage+Labour_cost (by-industry section).

**Hiring:**
Use `### Hiring`. Paste `period_end`, `ss`, `timeseries_data` into D-Hiring+Turnover (HIRING section). `ss` = `COUNT(DISTINCT location_id)` from `location_info` — the per-location sample size used as the normalization denominator.

**Turnover:**
Use `### Turnover`. Paste `period_end`, `ss`, `timeseries_data` into D-Hiring+Turnover (TURNOVER section). Same `ss` definition as hiring.

**Step 4 — Excel auto-calculation**

Labor Activity 2026 and Wages Activity 2026 sheets recalculate automatically once D-sheets are updated:
- **Labor Activity**: 7-day rolling average of D-sheet values for the reference window (Sunday of week containing the 12th); MoM change = current month avg − prior month avg (both indexed units)
- **Wages Activity**: wages vs Jan 2022 = `(wage_rate − 11.4829) / 11.4829`; MoM % change per industry; hiring/turnover normalized per location (`timeseries_data / ss`) → MoM change → indexed to January

**Step 5 — QA** (see QA Checklist below)

**Step 6 — PPTX assembly**

Update each slide with values from Labor Activity and Wages Activity. Rewrite slide titles, subtitles, and chart notes following the narrative language patterns in `../mshr.md`. Slide 2 (At A Glance) must synthesize all six metrics.

**Step 7 — Review and sign-off**

Ray Sanza: narrative framing and headline metric accuracy.
Vlad: data accuracy and suppression rule compliance.

**Step 8 — Publish**

Save final PPTX. Log it in the Cover sheet of the master Excel file with the publication date.

## Data Requirements

IF running this workflow → load `../mshr.md`. Use `## Example Queries` for all wage, hiring, and turnover data pulls. Do not use `dbt` tables or any other source for these metrics.

## QA Checklist

- [ ] All three source tables confirm `MAX(date) ≥` 27th of reporting month
- [ ] D-sheet row counts extend through the cutoff date — no missing days in any D-sheet column
- [ ] Wage `sample_size_jobs > 20` for every national and industry segment being published
- [ ] Turnover variance vs prior year < 5%; if ≥ 5%, query `postgres.job_versions.whodunnit` for rake/lock/termination patterns and re-run with exclusions
- [ ] Reference Sunday used matches the pre-computed table in `../mshr.md` (Sunday of the week containing the 12th)
- [ ] MoM deltas reviewed; any movement > 3 percentage points flagged for manual review before sign-off
- [ ] At least one metric traced end-to-end from D-sheet value → Labor/Wages Activity calculation → PPTX slide
- [ ] Hiring/turnover normalization order confirmed: divide by `ss` first, then compute MoM change
- [ ] Ray Sanza sign-off received before external distribution
