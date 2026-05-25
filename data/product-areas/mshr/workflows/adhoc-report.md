---
owner: vlad
last_updated: 2026-05-14
review_cadence: as-needed
next_review: 2026-06-14
source: internal
refs: []
---

# Ad Hoc MSHR Production Workflow

## Overview

Ad hoc MSHR reports are produced on request from leadership or the GTM team. They are typically scoped to a specific question, time window, or external event (e.g., a policy announcement, a media inquiry, a conference keynote).

## When to Use This Workflow

IF the request comes from Ray Sanza, Katie Dare, Vlad, or GTM outside of the monthly schedule → use this workflow.
IF the request specifies a particular metric subset, geography, or time window → use this workflow.
IF the request is "same as last month but for [specific segment]" → use this workflow.

## Required Clarifying Questions

**Do not pull any data or write any SQL until all of these are answered.** Act as an analyst: ask these questions first, confirm the answers, then proceed to Production Steps.

### 1. Metric scope

- Which metrics are needed? (check all that apply)
  - Employees Working / Hours Worked / Businesses Open
  - Wages (requires payroll cohort — adds processing time)
  - Jobs Added / Jobs Archived
  - Users Added (new to platform)

- **Jobs Added — which definition?**
  - **MSHR definition**: `MIN(postgres.jobs.created_at)` per employee per location = first-ever hire date. One-time event.
  - **Weekly activity gap definition**: employee had a shift this week but not last week (1-week lookback). Measures re-entry, not first hire.
  - These are different signals. Confirm which one the requester needs, or whether both should be shown side-by-side.

- **Users Added vs Jobs Added — same or separate?**
  - `users_added` = employee's very first shift ever on the Homebase platform. Fires once per employee across all time. Reflects platform-level workforce growth.
  - `jobs_added` = activity gap — employee was active this week but not last week. Reflects labor market fluidity.
  - Confirm whether the requester wants one, both, or a combined view. Clarify which signal answers their question.

### 2. Time grain

- **Weekly or monthly?**
  - **Weekly**: Sunday–Saturday complete weeks. Uses `dbt.new_data_weekly` or filtered `dbt.temp_timeclock_data`. Qualification flags pre-applied. MoM or YoY comparison = same week prior period.
  - **Monthly (MSHR-equivalent)**: Period = 28th of prior calendar month to 27th of current. Labor metrics use 7-day rolling average around the reference Sunday (Sunday of week containing the 12th), indexed to January. Wages use matched payroll cohort. More complex to generate — confirm if MSHR-style formatting is required.

- **What time window?** (single month, rolling 3 months, full series from 2019, YoY, custom range)

### 3. Geographic and industry cuts

- **Geography**: national only, or broken out by state / Census region / MSA / city?
  - Note: no pre-aggregate exists for city or MSA. City/MSA requires filtering `dbt.temp_timeclock_data` directly and applying qualification flags manually.
- **Industry**: all 13 industries or a specific subset? (`locations.business_type_new`)

### 4. Output format and audience

- Who receives this? (Ray Sanza for strategy, Katie Dare for PR/media, Vlad for internal QA, other)
- Output format: slide deck, CSV data file, one-pager with narrative, talking points only?
- Internal use or external publication? (suppression rules — `sample_size_jobs > 20` for wages — apply to anything external)

## Weekly vs Monthly Formula Differences

Confirm the time grain before building any calculation.

| Dimension | Weekly (ad hoc) | Monthly (MSHR-equivalent) |
|---|---|---|
| Reporting period | Sunday–Saturday complete weeks | 28th of prior month to 27th of current month |
| Reference anchor | Any complete week | Sunday of the week containing the 12th |
| Labor metrics calculation | Raw counts or simple % change | 7-day rolling average of indexed daily values |
| Index baseline | None (use raw or YoY % change) | January of the current year = 0; all months expressed relative to it |
| MoM change | `(current_week − prior_week) / prior_week` | `current_month_7day_avg − prior_month_7day_avg` (both already indexed; result is percentage-point change) |
| Wages | Payroll cohort query, monthly grain | Same cohort query; denominator anchored to Jan 2022 ($11.4829) |
| Hiring/turnover | `timeseries_data / ss` → MoM % change | Same normalization; then indexed to January of each year |
| Primary table | `dbt.new_data_weekly` | `corona.shift_and_timecard_events` + `postgres.jobs` |

## Production Steps

**Step 1 — Scope definition**

Before pulling any data, confirm with the requester:
- What question is being answered? Who is the end audience?
- Which metrics? (subset or full set — employees working, hours, wages, hiring, turnover)
- What time window? (single month, rolling 3 months, full historical series, YoY comparison)
- What geographic or sector cuts? (national / state / MSA / industry / city)
- What output format? (slide deck, CSV data file, one-pager, talking points)
- Who signs off before external use? (Ray Sanza or Vlad)

**Step 2 — Select the right table**

| If the request needs... | Use this table |
|---|---|
| National weekly time series | `dbt.new_data_weekly` |
| State-level weekly time series | `dbt.new_state_data_weekly` |
| Custom segmentation (engagement, size band) | `dbt.temp_timeclock_data` (filter directly) |
| City or MSA level | `dbt.temp_timeclock_data` filtered to `city` or `msa` — no pre-aggregate exists |
| Wages | Run payroll cohort query scoped to the requested window |
| Hiring / turnover | Run hiring/turnover queries scoped to the requested window |

Apply the relevant qualification flags from `../mshr.md`:
- `qualified_for_jobs` (5–100 employees, ≥12 weeks active) for jobs added/archived
- `qualified_for_hours` (5–100, ≥12 weeks) for hours
- `qualified_for_wages` (5–100, ≥12 weeks, wage coverage > 0.5) for wages
- `qualified_for_turnover` (10–100, ≥12 weeks) for turnover and `users_added`

**Step 3 — Data pull**

Confirm source tables cover the requested window:

```sql
SELECT MAX(event_date) FROM corona.shift_and_timecard_events;
```

Run the scoped query. Check row counts and null rates on key metric columns before proceeding.

**Step 4 — QA**

- Verify `sample_size_jobs > 20` for any wage segment being published
- Check jobs added/archived for >5% YoY variance vs equivalent prior period; if so, inspect `postgres.job_versions.whodunnit` for system archivations
- For weekly reports: confirm all periods are complete Sunday–Saturday weeks (no partial weeks)
- Confirm the `jobs_added` lookback window matches the request context — current SQL uses 1-week lookback; 4-week is recommended for trend analysis. Confirm with requester.

**Step 5 — Output**

Format per requester spec. Always include a methodology note citing:
- Reference period definition (weekly: Sunday–Saturday; monthly: 28th–27th)
- Qualification flags applied
- Suppression thresholds (wage segments: `sample_size_jobs > 20`)
- Table(s) used

**Step 6 — Deliver and confirm**

Ray Sanza or Vlad must confirm before any external use or distribution.

## Key Differences from Monthly Workflow

| Dimension | Monthly | Ad Hoc |
|---|---|---|
| Trigger | Calendar | Request from leadership / GTM |
| Scope | Full metric set | Subset defined by request |
| Time window | Prior full month | Flexible |
| Output | Standard report format | Varies by request |
| Sign-off | Ray Sanza | Ray Sanza or Vlad |
