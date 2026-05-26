---
owner: vlad
last_updated: 2026-05-25
review_cadence: as-needed
next_review: 2026-06-25
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
IF the request involves an event (sporting event, natural disaster, heatwave, policy change) → use this workflow **and** invoke `event-impact-template.py`.

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
- **Industry**: all 13 industries or a specific subset? Use the 13 broad classifications from `business_type_new` — see [Industry Classification](#industry-classification) below.

### 4. Output format and audience

- Who receives this? (Ray Sanza for strategy, Katie Dare for PR/media, Vlad for internal QA, other)
- Output format: slide deck, CSV data file, one-pager with narrative, talking points only?
- Internal use or external publication? (suppression rules — `sample_size_jobs > 20` for wages — apply to anything external)

---

## Industry Classification

> **Never filter by the raw `industry` column in `dbt.temp_timeclock_data`.** That field contains legacy and un-normalized values (43 distinct strings for what should be 13 categories — e.g., `'food'`, `'Food & Drink'`, `'food-table'`, `'food_table'` all mean the same thing). Filtering on it will silently return incomplete results.

**Always use `public.locations.business_type_new`** — the canonical, normalized field — via a join on `location_id`. This is the field that appears in published MSHR outputs.

### The 13 Broad Industry Classifications

| `business_type_new` | What it covers |
|---|---|
| Food, Drink, & Dining | Restaurants (sit-down and QSR), bars, coffee shops, bakeries, food trucks, breweries, wineries |
| Retail | Grocery, clothing, convenience stores, specialty shops, general merchandise |
| Entertainment | Sports leagues, gyms, arcades, theaters, museums, event venues, recreation |
| Beauty & Wellness | Hair/nail salons, spas, yoga studios, personal trainers, dance studios |
| Home & Repair | Construction, cleaning, landscaping, HVAC, plumbing, electrical, handyman |
| Professional Services | Consulting, legal, accounting, IT/tech, marketing, real estate, staffing |
| Medical / Veterinary | Doctors, dentists, clinics, hospitals, physical therapy, vet services |
| Hospitality | Hotels, resorts, lodges, campgrounds |
| Personal Services | Auto repair, dry cleaning, photography, valet, car wash, funeral services |
| Caregiving | Child care, in-home care, animal boarding |
| Education | Schools, tutors, universities |
| Public or Nonprofit Organization | Churches, charities, government offices, community organizations |
| Transportation & Logistics | Delivery, warehousing, transit, moving services |

### Primary Method — Join to `public.locations`

```sql
SELECT
    t.event_date,
    loc.business_type_new     AS broad_industry,
    loc.business_category_new AS industry_subcategory,
    COUNT(DISTINCT t.user_id) AS employees_working
FROM dbt.temp_timeclock_data t
JOIN public.locations loc
    ON t.location_id = loc.location_id
WHERE t.has_clock_in = 1
  AND loc.state_cleaned NOT IN ('Not USA', 'Unclassified')
  AND loc.business_type_new IS NOT NULL
GROUP BY t.event_date, loc.business_type_new, loc.business_category_new
ORDER BY t.event_date, broad_industry;
```

This always produces the correct 13-category breakdown. Use it for any industry-segmented query.

### Fallback Method — NAICS Code CASE WHEN

Use only when `public.locations` is not joinable — e.g., when working with a pre-aggregated table that exposes `naics_code` but not `location_id`. The full reference is in `industry-classification.sql` in this folder.

```sql
-- In SELECT or WHERE clauses, replace the join with:
CASE
    WHEN naics_code IN (111998, 312120, 312130, 312140, 492210, 722320, 722330, 722410, 722511, 722513, 722515)
        THEN 'Food, Drink, & Dining'
    WHEN naics_code IN (327110, 423910, 441110, 442110, 443142, 444130, 445110, 445120, 445310, 446110, 446130, 448120, 448210, 448310, 451110, 451120, 451140, 451211, 452319, 453110, 453210, 453310, 453910, 453991, 453998, 455230, 532282)
        THEN 'Retail'
    WHEN naics_code IN (441228, 512131, 611620, 711110, 711130, 711190, 711310, 711320, 712110, 712130, 712190, 713110, 713940, 713950, 713990, 721120)
        THEN 'Entertainment'
    WHEN naics_code IN (611610, 621399, 812112, 812113, 812199)
        THEN 'Beauty & Wellness'
    WHEN naics_code IN (113310, 213111, 221310, 236115, 236118, 238140, 238160, 238170, 238190, 238210, 238220, 238310, 238320, 238330, 238340, 238350, 238390, 238910, 238990, 311212, 332312, 332313, 333415, 333921, 423830, 488410, 541310, 541350, 541370, 561622, 561710, 561720, 561730, 561740, 561790, 562119, 562991, 811211, 811310, 811412, 811420)
        THEN 'Home & Repair'
    WHEN naics_code IN (325412, 541940, 621111, 621112, 621210, 621310, 621320, 621330, 621340, 621391, 621492, 621512, 622110, 622210)
        THEN 'Medical / Veterinary'
    WHEN naics_code IN (211111, 511130, 512110, 523930, 524210, 531130, 531210, 531311, 541110, 541199, 541211, 541330, 541410, 541413, 541430, 541511, 541611, 541613, 541618, 541960, 551114, 561320, 561422, 561510, 561611, 561612, 561920, 711510, 925110)
        THEN 'Professional Services'
    WHEN naics_code IN (483112, 721110, 721211, 721214)
        THEN 'Hospitality'
    WHEN naics_code IN (624120, 624410, 812910)
        THEN 'Caregiving'
    WHEN naics_code IN (611110, 611691)
        THEN 'Education'
    WHEN naics_code IN (519120, 541320, 541720, 562920, 621910, 624110, 813110, 813312, 813410, 813910, 813940, 921110, 921190, 922110, 922120, 922140, 922160, 922190, 928120)
        THEN 'Public or Nonprofit Organization'
    WHEN naics_code IN (323111, 491110, 524125, 541921, 763101, 811111, 811192, 811490, 812210, 812320, 812930)
        THEN 'Personal Services'
    WHEN naics_code IN (484210, 485112, 485113, 485310, 485320, 485999, 488119, 488510, 492110, 493110, 532111)
        THEN 'Transportation & Logistics'
    ELSE 'Other / Unknown'
END AS broad_industry
```

> **Ambiguous NAICS codes:** Nine codes appear in more than one sub-category in `public.locations` (e.g. NAICS 713940 covers both fitness studios and sports clubs). In the CASE WHEN above they are assigned to the most common Homebase use case. The join method resolves these correctly via `business_type_new`. See `industry-classification.sql` for the full annotated reference.

---

## Weekly vs Monthly Formula Differences

Confirm the time grain before building any calculation.

| Dimension | Weekly (ad hoc) | Monthly (MSHR-equivalent) |
|---|---|---|
| Reporting period | Sunday–Saturday complete weeks | 28th of prior month to 27th of current month |
| Reference anchor | Any complete week | Sunday of the week containing the 12th |
| Labor metrics calculation | Raw counts or simple % change | 7-day rolling average of indexed daily values |
| Index baseline | None (use raw or YoY % change) | January of the current year = 0; all months expressed relative to it |
| MoM change | `(current_week − prior_week) / prior_week` | `current_month_7day_avg − prior_month_7day_avg` (both already indexed; result is percentage-point change) |
| Wages | Payroll cohort query (`../mshr.md → ## Example Queries → ### Payroll Cohort`), scoped to requested window | Same cohort queries; denominator anchored to Jan 2022 ($11.4829) for % change framing |
| Hiring/turnover | `### Hiring` / `### Turnover` queries from `../mshr.md`; `timeseries_data / ss` → MoM % change (`ss` = `COUNT(DISTINCT location_id)` from `location_info`) | Same normalization; then indexed to January of each year |
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

> **Wages are always payroll cohort — no exceptions.** Whether the request is ad hoc or monthly, national or by industry, always use the `### Payroll Cohort` queries in `../mshr.md → ## Example Queries`. The `dbt` tables (`dbt.new_data_weekly`, `dbt.temp_timeclock_data`) cover labor activity metrics only — they do not contain wage data.

| If the request needs... | Use this table |
|---|---|
| National weekly time series | `dbt.new_data_weekly` |
| State-level weekly time series | `dbt.new_state_data_weekly` |
| Custom segmentation (engagement, size band, industry) | `dbt.temp_timeclock_data` + `JOIN public.locations` for `business_type_new` |
| City or MSA level | `dbt.temp_timeclock_data` filtered to `city` or `msa` — no pre-aggregate exists |
| Wages (any cut: national, industry, state, MSA) | **Always** use the `### Payroll Cohort` queries from `../mshr.md → ## Example Queries`. Run the Setup section first. Do NOT use `dbt.temp_timeclock_data` or any pre-aggregated table for wages — those tables do not contain wage data. Scope the cohort variables to the requested window. |
| Hiring / turnover | Use `### Hiring` and `### Turnover` queries from `../mshr.md → ## Example Queries`. Run the Setup section first (`consideration_set`, `location_info` temp views). `ss` = `COUNT(DISTINCT location_id)` from `location_info`; normalize as `timeseries_data / ss` before comparing periods. |

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

---

## Event Impact Analysis

When the request describes a real-world event that may affect small business activity — sporting events, natural disasters, heatwaves, policy announcements, economic shocks — use the **`event-impact-template.py`** framework instead of writing a one-off query.

**When to invoke:** any request that mentions an event name, a disruption, or asks about impact before/during/after a specific period.

**How to use:**
1. Open `event-impact-template.py` in Databricks
2. Edit only the `CONFIG` block at the top — everything else auto-derives:

```python
CONFIG = {
    'event_name'  : 'Your Event Name',
    'event_type'  : 'planned',        # planned | natural_disaster | economic | policy | other
    'notes'       : 'Any context note',
    'city'        : 'CITYNAME',       # UPPER case — verified via discovery query
    'state'       : 'XX',
    'event_start' : '2026-MM-DD',     # set to None if event hasn't started yet
    'event_end'   : '2026-MM-DD',     # set to None if event hasn't ended yet
    'pre_weeks'   : 6,
    'post_weeks'  : 6,
    'prior_years' : [2024, 2025],
    'min_locs'    : 30,
    'p_threshold' : 0.05,
}
```

3. Run all cells — the template handles:
   - City string discovery (Step 1)
   - Weekly metrics pull with YoY alignment (Step 2)
   - Thin sample flagging (Step 3)
   - Period assignment: baseline / pre-event / during / post-event (Step 4)
   - Seasonality removal: YoY delta per ISO week (Step 5)
   - Statistical significance: Welch's t-test on event-window YoY delta vs baseline (Step 6)
   - 3-panel visualization per metric (Step 7)

**Pre-event-only runs:** if `event_start` is in the future, set `event_end` to `None`. The template will analyze only the pre-period and annotate the chart with a dashed "event start" line. This is the correct setup for analyzing anticipation effects or baseline conditions before a scheduled event.

**Seasonality note:** the template removes seasonal effects by computing `YoY delta = current_year − prior_year` for the same ISO week. A statistically significant positive delta during the event window means activity is higher than what the seasonal baseline alone would predict — evidence of an event-driven effect rather than normal seasonal variation.

## Key Differences from Monthly Workflow

| Dimension | Monthly | Ad Hoc |
|---|---|---|
| Trigger | Calendar | Request from leadership / GTM |
| Scope | Full metric set | Subset defined by request |
| Time window | Prior full month | Flexible |
| Output | Standard report format | Varies by request |
| Sign-off | Ray Sanza | Ray Sanza or Vlad |
