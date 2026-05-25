# MSHR Workflows

Production workflows for both MSHR report tracks.

## New to MSHR? Start here

Read in this order:

1. `domains/mshr/domain-overview.md` — what MSHR is, the two report tracks, and how they differ
2. `../data-model.md` — the three data pipelines, key entities, and disambiguation (business vs company, job vs payroll run, MSHR Jobs Added vs ad hoc jobs_added)
3. `../mshr.md` — full SQL, suppression rules, index methodology, and all production queries
4. This file (`workflows/CLAUDE.md`) — which workflow to load for a given task

**Two tracks, two different tools:**

| Track | Trigger | Primary tables | Key difference |
|---|---|---|---|
| Monthly MSHR | Calendar (monthly) | `corona.shift_and_timecard_events`, `postgres.jobs`, `postgres.payroll_payroll_runs` | Indexed to January baseline; 7-day rolling avg; matched payroll cohort for wages |
| Ad hoc MSHR | Leadership / GTM request | `dbt.new_data_weekly`, `dbt.temp_timeclock_data` (or monthly pipeline for wages) | Raw counts or simple % change; flexible window; wages still require payroll cohort |

> **If the request involves wages** — regardless of track — always use the payroll cohort queries in `../mshr.md → ## Example Queries`. The `dbt` tables do not produce publishable wage figures.

---

## File Index

| File | When to load |
|---|---|
| `monthly-report.md` | Producing the regular monthly MSHR — data cutoff, Looker pull, Python scripts, QA, publish |
| `adhoc-report.md` | Producing a scoped or event-driven MSHR on leadership/GTM request |
| `data-sourcing.md` | Identifying, refreshing, or validating source tables; full `dbt.new_data_weekly` column schema |
| `create_benchmark_table.sql` | Run each January in Databricks to recreate `corona.location_usage_benchmarks_from_aph_jan_[YYYY]` |
| `indexed_values_query.sql` | Direct Databricks query for Employees Working, Hours Worked, Businesses Open — indexed values for 2024/2025/2026 with MoM ppt changes |
| `create_new_data_weekly.sql` | Full CREATE TABLE SQL for `dbt.new_data_weekly` — reference for understanding the ad hoc pipeline |
| `industry-classification.sql` | NAICS code → `business_type_new` mapping reference. Full CASE WHEN block for ad hoc queries + canonical list of all 13 broad industry classifications and their sub-categories |
| `event-impact-template.py` | Generic event impact framework (Databricks PySpark). Edit CONFIG block only — works for any event type: sporting events, natural disasters, policy changes, economic shocks. Seasonality-adjusted YoY delta + stat sig. FIFA World Cup 2026 / Miami FL is the built-in example. |

## Which Workflow to Use

- Scheduled monthly report → `monthly-report.md`
- Leadership- or GTM-driven, scoped to a specific question or event → `adhoc-report.md`
- Question about which tables to use, data freshness, or `dbt.new_data_weekly` schema → `data-sourcing.md`
- Need to regenerate the January benchmark table → `create_benchmark_table.sql` + `data-sourcing.md → Recreating the Benchmark Table`
- Request involves an event (sporting event, hurricane, heatwave, policy announcement, etc.) → `event-impact-template.py` — edit the CONFIG block and run

---

## Code Generation Protocol

**When a user asks for MSHR data, a report, or any analysis — generate the SQL or Python directly.** Do not ask the user to specify the methodology, the table to use, or how to aggregate. Apply the rules below automatically based on what the request is describing.

### Detecting the request type

| If the user asks for... | Request type |
|---|---|
| Monthly numbers, indexed values, 7-day averages, MoM change, the standard MSHR report | Monthly MSHR |
| A specific segment, state, city, industry, custom time window, event-driven cut, or "ad hoc" | Ad Hoc |
| Wages — any cut, any cadence | Always payroll cohort regardless of track |
| Hiring or turnover — any cut | Always `### Hiring` / `### Turnover` queries from `../mshr.md` regardless of track |
| An event impact (sporting event, disaster, policy, etc.) | Event Impact — invoke `event-impact-template.py`, edit CONFIG block |

---

### Monthly MSHR — Auto-apply this methodology

Use when the request involves indexed values, the standard report, or any of the three core labor metrics (Employees Working, Hours Worked, Businesses Open).

**Automatically:**
1. Base table: `corona.shift_and_timecard_events`
2. Benchmark table: `corona.location_usage_benchmarks_from_aph_jan_[YYYY]` — join on `location_id × day_of_week` (DOW: `dayofweek(event_date) - 1`, 0=Sun)
3. Reference period: Sunday of the week containing the 12th of each month — compute as `date_sub(make_date(yr, mo, 12), (dayofweek(make_date(yr, mo, 12)) - 1) % 7)`
4. Aggregate method: 7-day average over `[reference_sunday, reference_sunday + 6]`
5. Index formula: `SUM(actual) / SUM(benchmark) - 1` — aggregate first, then divide (not per-location ratio)
6. US filter: `state NOT IN ('Not USA', 'Unclassified')`
7. MoM change: `current_month_avg - prior_month_avg` (both already indexed — result is percentage-point change, no division)

**Reference template:** `indexed_values_query.sql` in this folder is the complete, ready-to-run Databricks SQL covering 2024/2025/2026. Adapt year ranges and filters as needed — do not rewrite from scratch.

---

### Ad Hoc — Auto-apply this methodology

Use when the request specifies a custom segment (state, city, MSA, industry, size band, engagement) or a flexible time window.

**Automatically:**
1. Base table: `dbt.temp_timeclock_data` (aliased `t`)
2. Industry join: always `JOIN public.locations loc ON t.location_id = loc.location_id` — use `loc.business_type_new` for broad industry, `loc.business_category_new` for sub-category. **Never use `t.industry` directly** — it is not normalized (43 raw strings for 13 categories)
3. US filter: `loc.state_cleaned NOT IN ('Not USA', 'Unclassified')` or `t.state NOT IN ('Not USA', 'Unclassified')`
4. Active locations filter: `t.loc_archived_at IS NULL` (exclude closed locations unless the request explicitly asks for historical closed data)
5. Qualification flags — apply the correct flag(s) for the metric requested:

| Metric | Flag to apply | Employee size band | Min weeks active |
|---|---|---|---|
| Employees Working, Hours Worked | `qualified_for_hours = 1` | 5–100 | ≥ 12 of last 52 |
| Jobs Added, Jobs Archived | `qualified_for_jobs = 1` | 5–100 | ≥ 12 of last 52 |
| Turnover, Users Added | `qualified_for_turnover = 1` | 10–100 | ≥ 12 of last 52 |
| Wages | Payroll cohort method only — do not use `dbt` tables | — | — |
| Future shifts, Survival | `qualified_for_outlook = 1` | 5–100 | ≥ 26 of last 52 |

6. Industry segmentation: use the `industry-classification.sql` CASE WHEN block when `public.locations` is not joinable; otherwise use `loc.business_type_new`
7. Output: Databricks-ready SQL. Use Python (PySpark or `%sql` blocks) when the query has multiple dependent steps, date arithmetic, or looping across periods

#### City / Geographic String Handling

City values in `dbt.temp_timeclock_data` are mixed case (`'Miami'`, `'MIAMI'`, `'miami'` all appear). MSA values have similar variance. **Always:**

1. **Run the city discovery query first** to confirm exact string variants before filtering:
```sql
SELECT UPPER(city) AS city_upper, state, COUNT(DISTINCT location_id) AS locs
FROM dbt.temp_timeclock_data
WHERE state = '[STATE]' AND city ILIKE '%[cityname]%'
  AND event_date >= DATE_SUB(CURRENT_DATE, 90)
  AND loc_archived_at IS NULL
GROUP BY 1, 2 ORDER BY 3 DESC
```
2. Filter using `UPPER(city) = 'CITYNAME'` (not raw `city = 'Miami'`) to catch all variants
3. Always pair city with `state =` to exclude cross-state collisions (e.g., Miami FL vs Miami OH, Portland OR vs Portland ME)

#### Qualification Flag Scope Relaxation

The standard qualification flags are calibrated for national-scale analysis. For narrow geographic or industry cuts, samples can become thin:

- **Check sample size after applying flags:** if `COUNT(DISTINCT location_id WHERE flag=1) < 30`, flag the output as a thin sample
- **For small city or narrow industry cuts** (< 30 qualified locations with standard flags): relax to **5–200 employee band, ≥ 8 weeks active** and note the relaxation in the output
- **Always surface `active_qualified_locs`** as a column in the output — it lets the reader assess reliability without needing to re-run the query
- **Do not silently over-filter:** if the standard flag returns < 5 locations, the segment is too narrow for publishable output — flag it explicitly and consider rolling up to a broader geography or industry

---

### Efficiency Rules — Always Apply

These datasets are 3–4 GB. Every query generated must follow these rules:

| Rule | Why |
|---|---|
| **Filter `event_date` range first** — put it in the innermost subquery or the earliest CTE | Enables Databricks partition pruning; reduces data scanned from GB to MB |
| **Never `SELECT *`** — project only the columns required by the metric | Avoids reading unnecessary column files in Parquet/Delta format |
| **Aggregate before joining** — compute `COUNT`, `SUM`, `GROUP BY` in a CTE, then join to dimension tables | Prevents row explosion before aggregation |
| **Apply `state`, `has_clock_in`, `loc_archived_at` filters early** — in the innermost subquery, not in outer WHERE | Reduces rows carried through joins |
| **Use `INNER JOIN` for required dimension lookups** (`public.locations`) — use `LEFT JOIN` only when nulls in the dimension are expected and meaningful | INNER JOIN prunes non-matching rows earlier in the query plan |
| **Use `DATE_TRUNC('week', event_date)` or `DATE_TRUNC('month', event_date)` in GROUP BY** rather than extracting year/month separately | Single pass on date column; consistent with Databricks optimizer |
| **For `COUNT(DISTINCT user_id)` over a multi-month window** — pre-aggregate to weekly distinct counts in a CTE, then union/deduplicate | Avoids holding a massive distinct set in memory |
| **Use `NULLIF(denominator, 0)` in all division** — never divide without it | Prevents runtime errors on sparse segments |

**Preferred query structure for `dbt.temp_timeclock_data` ad hoc queries:**

```sql
WITH
-- Step 1: Filter raw events first (partition pruning + row reduction)
filtered_events AS (
    SELECT
        t.location_id,
        t.user_id,
        t.job_id,
        t.event_date,
        t.hours_worked,
        t.has_clock_in,
        t.qualified_for_hours,   -- or whichever flag the metric needs
        DATE_TRUNC('week', t.event_date) AS week_start
    FROM dbt.temp_timeclock_data t
    WHERE t.event_date BETWEEN '[start_date]' AND '[end_date]'   -- ← always first
      AND t.loc_archived_at IS NULL
      AND t.state NOT IN ('Not USA', 'Unclassified')
),

-- Step 2: Join to dimensions after filtering (smaller row set)
with_industry AS (
    SELECT
        f.*,
        loc.business_type_new AS broad_industry,
        loc.state_cleaned     AS state
    FROM filtered_events f
    INNER JOIN public.locations loc ON f.location_id = loc.location_id
    WHERE loc.business_type_new IS NOT NULL
),

-- Step 3: Apply qualification flag and aggregate
aggregated AS (
    SELECT
        week_start,
        broad_industry,
        COUNT(DISTINCT CASE WHEN qualified_for_hours = 1 THEN location_id END) AS active_locations,
        COUNT(DISTINCT CASE WHEN qualified_for_hours = 1 AND has_clock_in = 1 THEN user_id END) AS employees_working,
        SUM(CASE WHEN qualified_for_hours = 1 THEN COALESCE(hours_worked, 0) ELSE 0 END) AS hours_worked
    FROM with_industry
    GROUP BY week_start, broad_industry
)

SELECT * FROM aggregated ORDER BY week_start, broad_industry;
```

Adapt the SELECT list, flag, and GROUP BY dimensions to the specific request. This structure is the default starting point for all ad hoc queries.

---

### Normalization Rules — Always Apply for Ad Hoc Reports

> **Never report raw aggregate totals as headline metrics in ad hoc reports.** Raw counts conflate platform growth (more locations joining Homebase over time) with real economic signal. Normalized per-location metrics are comparable across time and geography.

**Apply these normalizations automatically to every ad hoc query:**

| Metric | Headline form | Formula | Denominator |
|---|---|---|---|
| Employees Working | `employees_per_location` | `COUNT(DISTINCT user_id WHERE qualified_for_hours=1 AND has_clock_in=1) / active_qualified_locs` | `COUNT(DISTINCT location_id WHERE qualified_for_hours = 1)` |
| Hours Worked | `hours_per_location` | `SUM(hours_worked WHERE qualified_for_hours=1) / active_qualified_locs` | Same — `qualified_for_hours` locations |
| Jobs Added | `hires_per_location` | `COUNT(jobs_added WHERE qualified_for_jobs=1) / active_qualified_locs` | `COUNT(DISTINCT location_id WHERE qualified_for_jobs = 1)` |
| Jobs Archived | `separations_per_location` | `COUNT(jobs_archived WHERE qualified_for_jobs=1) / active_qualified_locs` | Same — `qualified_for_jobs` locations |
| Users Added | `new_employees_per_location` | `COUNT(DISTINCT user_id WHERE qualified_for_turnover=1) / active_qualified_locs` | `COUNT(DISTINCT location_id WHERE qualified_for_turnover = 1)` |
| Wages | No change | Already expressed as $/hr — inherently normalized | — |
| Businesses Open | **Exception — raw count** | Raw count + YoY % change as the normalization proxy | Cannot normalize per-location |

**Two rules that override any deviation:**

1. **The denominator must match the metric's qualification flag.** `qualified_for_hours` locations for employees/hours; `qualified_for_jobs` locations for hiring/turnover. Never use a generic "active location" count across different metrics — the denominators will differ and mixing them produces misleading ratios.

2. **Raw totals are context, not headlines.** Always compute and return the raw totals (employees_working, hours_worked, etc.) alongside the normalized figures so the reader can sanity-check — but label them clearly as supporting data, not the primary metric.

**For Businesses Open specifically:** express as raw count and YoY % change side by side. The % change is the normalization proxy — it removes the absolute platform-size effect without requiring a denominator.

```sql
-- Normalization pattern — embed in every ad hoc query
COUNT(DISTINCT CASE WHEN qualified_for_hours = 1 THEN location_id END)
    AS active_qualified_locs,

COUNT(DISTINCT CASE WHEN qualified_for_hours = 1 AND has_clock_in = 1 THEN user_id END)
    AS employees_working_raw,

ROUND(
    COUNT(DISTINCT CASE WHEN qualified_for_hours = 1 AND has_clock_in = 1 THEN user_id END)
    / NULLIF(COUNT(DISTINCT CASE WHEN qualified_for_hours = 1 THEN location_id END), 0),
    2
) AS employees_per_location,   -- ← headline metric

ROUND(
    SUM(CASE WHEN qualified_for_hours = 1 THEN COALESCE(hours_worked, 0) ELSE 0 END)
    / NULLIF(COUNT(DISTINCT CASE WHEN qualified_for_hours = 1 THEN location_id END), 0),
    2
) AS hours_per_location        -- ← headline metric
```
