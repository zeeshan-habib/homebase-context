# Data Sources & Query Logic

## Reference notebook

**`reference/PR_Standard_EOM_Metrics.ipynb`** is the canonical source for wage, hiring, and turnover SQL. A copy lives in this repo. When Databricks changes the notebook, update this copy and re-check all queries in `queries.py`.

> **Rule:** when writing or updating wage/hiring/turnover SQL, always open the notebook first and match the query exactly. The notebook is ground truth.

### Notebook cell map

| Cell | Purpose | Equivalent in queries.py |
|---|---|---|
| 2 | Date math (anchor to 27th) | `_report_dates()` |
| 3 | `month_end_dates` temp view | `_month_end_cte(DATE, start)` |
| 4 | National avg hourly wage | `_fetch_wages_raw()` → national section |
| 5 | Wage by industry | `_fetch_wages_raw()` → by_industry section |
| 6 | Wage by state | `_fetch_wages_raw()` → by_state section |
| 7 | Wage by MSA | `_fetch_wages_raw()` → by_msa section |
| 9 | `consideration_set` temp view | `_consideration_and_location_ctes()` |
| 10 | `location_info` temp view | `_consideration_and_location_ctes()` |
| 11 | Hiring query | `_hiring_sql(DATE)` |
| 13 | Turnover query (whodunnit filter) | `_turnover_sql(DATE)` |

---

## Anchor date logic

The report period always ends on the **27th of the month**. If the current day is on or before the 27th, use last month's 27th; if after the 27th, use this month's 27th.

```python
# Mirrors notebook cell 2 exactly
current_date = arrow.utcnow()
if arrow.now().day > 27:
    report_end_date = arrow.get(current_date.year, current_date.month, 27)
else:
    report_end_date = current_date.shift(months=-1).replace(day=27)

DATE = report_end_date.format("YYYY-MM-DD")
```

The `cohort_year_start/end` and `cohort_month_start/end` variables define the payroll cohort window: companies that had payroll **12 months ago AND last month** (meaning they've been running payroll continuously).

---

## Pipeline 1 — Labor (Employees Working, Hours Worked, Businesses Open)

### Tables

| Table | Alias | Role |
|---|---|---|
| `corona.shift_and_timecard_events` | — | Daily per-location clock-in activity |
| `corona.location_usage_benchmarks_from_aph_jan_2024` | — | Jan 2024 DOW averages for indexing |
| `corona.location_usage_benchmarks_from_aph_jan_2025` | — | Jan 2025 DOW averages |
| `corona.location_usage_benchmarks_from_aph_jan_2026` | — | Jan 2026 DOW averages |

### Logic

For each month, take the 7-day window centered on the **reference Sunday** (Sunday on or before the 12th of the month). Compute:

```
idx_employees = SUM(daily_users_with_clock_in) / SUM(benchmark_users) - 1
idx_hours     = SUM(daily_hours_worked)         / SUM(benchmark_hours) - 1
idx_open      = SUM(is_open_locations)          / SUM(benchmark_denominator / 4.0) - 1
```

The benchmark table provides the Jan 2024/2025/2026 DOW averages by location and day-of-week. The result is a percentage indexed to January (e.g., `-2.3%` means 2.3 pp below the January baseline).

MoM change is computed via `LAG()` partitioned by year.

### Fallback query

If the benchmark tables (`corona.location_usage_benchmarks_from_aph_jan_*`) are inaccessible (permission issue or table not yet created for the new year), `_fetch_labor_raw()` catches the exception and runs `_INDEXED_SQL_INLINE`, which **derives the January benchmark inline** from the same `shift_and_timecard_events` table:

```sql
jan_benchmark AS (
    SELECT yr, location_id, day_of_week,
        AVG(users_with_clock_in)   AS users_with_clock_in,
        AVG(total_hours_worked)    AS total_hours_worked,
        COUNT(DISTINCT event_date) AS denominator_clock_ins
    FROM daily_actuals
    WHERE mo_num = 1
    GROUP BY yr, location_id, day_of_week
)
```

This produces the same result — slightly less precise because it uses actual January data rather than the pre-computed benchmark — but is fully self-contained.

### Date filter

The query scans `event_date >= '2024-01-01' AND event_date <= current_date()`. Always use the raw date column (not `year()` or `month()` functions) to allow partition pruning.

---

## Pipeline 2 — Wages (Hourly Wages)

### Tables

| Table | Role |
|---|---|
| `postgres.payroll_payroll_runs` | Defines the payroll cohort (companies with payroll both last month and 12 months ago) |
| `corona.shift_and_timecard_events` | Timecard-level hours worked and wages earned |
| `public.locations` | Industry (`business_type`), state, MSA segmentation |

### Cohort definition

The payroll cohort filters to locations that ran payroll in **both** the start month (12 months ago) and the end month (last month). This ensures consistent coverage — we're not comparing apples to oranges as businesses enter/exit the payroll system.

```sql
consideration_jobs_start AS (
    SELECT location_id FROM postgres.payroll_payroll_runs
    WHERE year(payday) = {cyr_start} AND month(payday) = {cmo_start}
),
consideration_jobs_end AS (
    SELECT location_id FROM postgres.payroll_payroll_runs
    WHERE year(payday) = {cyr_end} AND month(payday) = {cmo_end}
),
timeseries_data AS (
    SELECT * FROM corona.shift_and_timecard_events
    WHERE date(timecard_created_at) BETWEEN '2022-01-01' AND '{DATE}'
      AND location_id IN (SELECT location_id FROM consideration_jobs_start)
      AND location_id IN (SELECT location_id FROM consideration_jobs_end)
)
```

Wage rate per job per month = `SUM(total_wages_earned) / SUM(hours_worked)`. Then averaged across jobs.

### Jan 2022 baseline — dynamic, never hardcoded

The Jan 2022 national wage is used as the baseline for the `% above Jan 2022` metric. This value **changes on every run** because retroactive payroll updates (corrected time cards, amended W-2s) alter historical records.

```python
jan2022 = next(
    (r for r in national if str(r.get("period_end", "")).startswith("2022-01")),
    None,
)
jan2022_baseline = float(jan2022["wage_rate"]) if jan2022 else None
```

The `pct_above_jan2022` field on every row is computed against this live baseline — not a stored constant.

### Column naming — IMPORTANT

The by-industry wage query uses `locations.business_type` — the **legacy** column. This matches the notebook exactly (notebook cell 5). Do **not** change this to `business_type_new` without re-validating the query produces the same industry labels.

The by-state query selects `locations.state_cleaned` (cleaned) and filters on `locations.state NOT IN ('Not USA', 'Unclassified')` (raw). Both columns exist on `public.locations`.

```sql
-- Correct (matches notebook):
WHERE locations.state NOT IN ('Not USA', 'Unclassified')
GROUP BY locations.state_cleaned

-- NOT:
WHERE locations.state_cleaned NOT IN ...
```

### Date range

`timeseries_data` is scanned from `2022-01-01` (not 2019-01-01 as in the original notebook). This is intentional to reduce query cost. The Jan 2022 baseline is still captured because the sequence starts from 2022-01-27 (`_month_end_cte(DATE, start="2022-01-27")`).

---

## Pipeline 3 — Hiring & Turnover (Jobs Added, Jobs Archived)

### Tables

| Table | Role |
|---|---|
| `public.companies` | Filters to companies created > 365 days ago (consideration set) |
| `public.locations` | US locations with non-null MSA, NAICS, industry |
| `postgres.jobs` | Job creation date (hiring) and archivation date (turnover) |
| `postgres.job_versions` | `whodunnit` field for excluding system-driven archivations |

### Consideration set

Only locations at companies that have been operating for at least 365 days, with valid MSA and NAICS codes. This prevents new-business noise from distorting the trend.

```sql
consideration_set AS (
    SELECT company_id, created_at FROM public.companies
    WHERE created_at < date_add(current_date(), -365)
),
location_info AS (
    SELECT ...
    FROM consideration_set cs
    INNER JOIN public.locations ON cs.company_id = locations.company_id
    WHERE locations.state_cleaned NOT IN ('Not USA', 'Unclassified')
      AND locations.msa IS NOT NULL
      AND locations.naics_code IS NOT NULL
      AND locations.business_type_new IS NOT NULL   -- note: _new here (not legacy)
      AND locations.business_category_new IS NOT NULL
)
```

Note: `location_info` uses `business_type_new` (unlike the wage query which uses the legacy `business_type`). This is consistent with the notebook.

### Turnover filters

System-driven archivations (automated business rules, not real employee departures) are excluded:

```sql
LEFT JOIN postgres.job_versions jv ON jv.item_id = jobs.id
   AND jv.created_at::date = jobs.archived_at::date
WHERE lower(jv.whodunnit) NOT LIKE '%rake businesses:archive_invoiced_company%'
  AND lower(jv.whodunnit) NOT LIKE '%lockjobworker%'
  AND lower(jv.whodunnit) NOT LIKE '%handlejobterminationworker%'
```

### Normalization and indexing

Raw counts are normalized per qualifying location, then indexed to January of each year:

```python
def _normalise_and_index(rows):
    # Step 1: per-location count
    for r in rows:
        r["per_loc"] = float(r["timeseries_data"]) / float(r["ss"] or 1)

    # Step 2: index to January (per year)
    jan_by_year = {
        int(str(r["period_end"])[:4]): r["per_loc"]
        for r in rows if int(str(r["period_end"])[5:7]) == 1
    }
    for r in rows:
        yr  = int(str(r["period_end"])[:4])
        jan = jan_by_year.get(yr)
        r["indexed"] = (r["per_loc"] - jan) / jan * 100 if jan else None
```

---

## Column reference

| Column | Table | Notes |
|---|---|---|
| `event_date` | `corona.shift_and_timecard_events` | Date partition — use raw for pruning |
| `timecard_created_at` | same | Timestamp — use `date()` cast in wages query |
| `state` | `public.locations` | Raw state (e.g., "Not USA"), used in WHERE |
| `state_cleaned` | `public.locations` | Clean state name, used in GROUP BY |
| `business_type` | `public.locations` | Legacy field — used in wage by-industry query to match notebook |
| `business_type_new` | `public.locations` | Current field — used in location_info for jobs queries |
| `business_category_new` | `public.locations` | Required non-null in consideration set |
| `whodunnit` | `postgres.job_versions` | Text field identifying who archived a job |
