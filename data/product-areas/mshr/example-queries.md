---
owner: vlad-akimenko
last_updated: 2026-05-28
review_cadence: monthly
next_review: 2026-06-28
source: internal
refs:
  - data/product-areas/mshr/mshr.md
  - data/product-areas/mshr/schemas.md
  - data/product-areas/mshr/workflows/code-generation-protocol.md
---

# MSHR — Example Queries

Load when you need production-ready SQL for wages, hiring, turnover, or shifts — or the Python setup code that prepares cohort dates and temp views.

For methodology rules and qualification flags for ad hoc queries, see `workflows/code-generation-protocol.md`. For indexed values SQL, see `workflows/indexed_values_query.sql`.

> **Table reference convention:** `corona.*`, `dbt.*`, and `operations.*` tables are Databricks-native schemas under `hive_metastore` (e.g. `hive_metastore.corona.shift_and_timecard_events`). SQL here uses shorthand paths matching the Databricks query context where `hive_metastore` is the default catalog. `postgres.*` and `public.*` tables are Redshift tables accessed via `prod_redshift_replica`.

---

## Setup — Python Date Calculation and Temp Views

Run this setup code once per session in Databricks before running any queries below.

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

> **`ss` = sample size.** In every hiring, turnover, and shifts query, `COUNT(DISTINCT location_info.location_id) AS ss` is the number of qualifying locations in that reporting period. This flows into the D-Hiring+Turnover sheet as the `ss` column and is used as the denominator when normalizing per-location (`timeseries_data / ss`). The `ss` value comes from `location_info`, which is built from `consideration_set` — so the sample size is always the set of US locations at companies that existed at least one year before the reporting month.

---

## Payroll Cohort Average by Job (National)

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

## Payroll Cohort Average by Job by Industry

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

## Payroll Cohort Average by State

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

## Payroll Cohort Average by MSA

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

## Hiring

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

## Turnover

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

## Shifts Worked

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
