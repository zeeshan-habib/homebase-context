"""
MSHR dashboard query layer.

Wage / hiring / turnover logic is a direct port of:
  reference/PR_Standard_EOM_Metrics.ipynb

Indexed values (Employees Working, Hours Worked, Businesses Open) use:
  homebase-context/data/product-areas/mshr/workflows/indexed_values_query.sql

All queries run via the Databricks SQL Statement Execution API (warehouse
16984dfe9a2c3705). Each execute_statement call is a separate session, so
temp views are NOT used — every dependency is an inline CTE.

Caching: CACHE_TTL_FAST (5 min) for labor, CACHE_TTL_SLOW (1 hr) for
wages/hiring/turnover (heavy scans, monthly cadence).
"""

import time
import arrow
from databricks.sdk import WorkspaceClient
from databricks.sdk.service.sql import StatementState

w = WorkspaceClient()
WAREHOUSE_ID = "16984dfe9a2c3705"

_cache: dict = {}
CACHE_TTL_FAST = 300
CACHE_TTL_SLOW = 3600


def _run_sql(sql: str) -> list[dict]:
    """Execute SQL and return rows as list of dicts. Polls past 50 s timeout."""
    result = w.statement_execution.execute_statement(
        warehouse_id=WAREHOUSE_ID,
        statement=sql,
        wait_timeout="50s",
    )
    while result.status.state in (StatementState.PENDING, StatementState.RUNNING):
        time.sleep(3)
        result = w.statement_execution.get_statement(result.statement_id)

    if result.status.state != StatementState.SUCCEEDED:
        raise RuntimeError(f"Query failed [{result.status.state}]: {result.status.error}")

    schema   = result.manifest.schema.columns
    col_names = [c.name for c in schema]
    rows      = result.result.data_array or []
    return [dict(zip(col_names, row)) for row in rows]


def _cached(key: str, ttl: int, fn):
    if key in _cache and time.time() - _cache[key]["ts"] < ttl:
        return _cache[key]["data"]
    data = fn()
    _cache[key] = {"data": data, "ts": time.time()}
    return data


# ── Date math (mirrors notebook cell 4) ──────────────────────────────────────

def _report_dates() -> dict:
    current_date = arrow.utcnow()
    if arrow.now().day > 27:
        report_end_date = arrow.get(current_date.year, current_date.month, 27)
    else:
        report_end_date = current_date.shift(months=-1).replace(day=27)

    return {
        "DATE":               report_end_date.format("YYYY-MM-DD"),
        "cohort_year_start":  report_end_date.shift(years=-1).year,
        "cohort_year_end":    report_end_date.year,
        "cohort_month_start": report_end_date.shift(years=-1).month,
        "cohort_month_end":   report_end_date.month,
    }


# ── Shared inline CTE builders ────────────────────────────────────────────────

def _month_end_cte(DATE: str, start: str = "2024-01-27") -> str:
    """Inline equivalent of the month_end_dates temp view (notebook cell 6)."""
    return f"""
month_end_dates AS (
    SELECT
        date_add(ADD_MONTHS(month_end, -12), 1) AS year_beginning,
        date_add(ADD_MONTHS(month_end, -1),  1) AS month_beginning,
        month_end
    FROM (
        SELECT EXPLODE(sequence(to_date('{start}'), to_date('{DATE}'), interval 1 month)) AS month_end
    )
)"""


def _consideration_and_location_ctes() -> str:
    """Inline equivalent of consideration_set + location_info temp views (cells 18-19)."""
    return """
consideration_set AS (
    SELECT company_id, created_at
    FROM public.companies
    WHERE created_at < date_add(current_date(), -365)
),
location_info AS (
    SELECT
        locations.location_id,
        cs.company_id,
        cs.created_at                  AS company_created_date,
        locations.created_at           AS location_created_date,
        locations.naics_code,
        locations.msa,
        locations.state_cleaned        AS state,
        locations.business_type_new    AS business_type,
        locations.business_category_new AS business_category
    FROM consideration_set cs
    INNER JOIN public.locations ON cs.company_id = locations.company_id
    WHERE locations.state_cleaned NOT IN ('Not USA', 'Unclassified')
      AND locations.msa                IS NOT NULL
      AND locations.naics_code         IS NOT NULL
      AND locations.business_type_new  IS NOT NULL
      AND locations.business_category_new IS NOT NULL
)"""


# ── Wage queries (mirrors notebook cells 8, 10, 12, 14) ──────────────────────
# NOTE: by-industry uses locations.business_type (legacy) to match notebook exactly.

def _fetch_wages_raw() -> dict:
    d = _report_dates()
    DATE               = d["DATE"]
    cyr_start          = d["cohort_year_start"]
    cyr_end            = d["cohort_year_end"]
    cmo_start          = d["cohort_month_start"]
    cmo_end            = d["cohort_month_end"]

    # Shared CTEs: month_end_dates + payroll cohort + timeseries_data
    # Start from 2022-01-01 (need Jan 2022 as baseline for pct_above_jan2022)
    shared = f"""WITH
{_month_end_cte(DATE, start="2022-01-27")},
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
),"""

    # ── National (cell 8) ────────────────────────────────────────────────────
    national = _run_sql(shared + """
job_averages AS (
    SELECT
        'national' AS segmented_by,
        'national' AS segment,
        month_end_dates.month_end AS period_end,
        timeseries_data.job_id,
        SUM(timeseries_data.total_wages_earned) / SUM(timeseries_data.hours_worked) AS wage_rate
    FROM timeseries_data
    JOIN month_end_dates
      ON timeseries_data.timecard_created_at::DATE
         BETWEEN month_end_dates.month_beginning AND month_end_dates.month_end
    GROUP BY segmented_by, segment, period_end, job_id
)
SELECT segmented_by, segment, period_end,
       AVG(wage_rate)          AS wage_rate,
       COUNT(DISTINCT job_id)  AS sample_size_jobs
FROM job_averages
GROUP BY segmented_by, segment, period_end
HAVING sample_size_jobs > 20
ORDER BY segment, period_end
""")

    # ── By industry (cell 10) — uses legacy locations.business_type ──────────
    by_industry = _run_sql(shared + """
job_averages AS (
    SELECT
        location_id,
        month_end_dates.month_end AS period_end,
        timeseries_data.job_id,
        SUM(timeseries_data.total_wages_earned) / SUM(timeseries_data.hours_worked) AS wage_rate
    FROM timeseries_data
    JOIN month_end_dates
      ON timeseries_data.timecard_created_at::DATE
         BETWEEN month_end_dates.month_beginning AND month_end_dates.month_end
    GROUP BY location_id, period_end, job_id
)
SELECT ja.period_end,
       loc.business_type,
       AVG(ja.wage_rate)         AS wage_rate,
       COUNT(DISTINCT ja.job_id) AS sample_size_jobs
FROM public.locations loc
INNER JOIN job_averages ja ON loc.location_id = ja.location_id
WHERE loc.state NOT IN ('Not USA', 'Unclassified')
GROUP BY loc.business_type, ja.period_end
HAVING sample_size_jobs > 20
ORDER BY loc.business_type, ja.period_end
""")

    # ── By state (cell 12) ───────────────────────────────────────────────────
    by_state = _run_sql(shared + """
job_averages AS (
    SELECT
        location_id,
        month_end_dates.month_end AS period_end,
        timeseries_data.job_id,
        SUM(timeseries_data.total_wages_earned) / SUM(timeseries_data.hours_worked) AS wage_rate
    FROM timeseries_data
    JOIN month_end_dates
      ON timeseries_data.timecard_created_at::DATE
         BETWEEN month_end_dates.month_beginning AND month_end_dates.month_end
    GROUP BY location_id, period_end, job_id
)
SELECT ja.period_end,
       loc.state_cleaned,
       AVG(ja.wage_rate)         AS wage_rate,
       COUNT(DISTINCT ja.job_id) AS sample_size_jobs
FROM public.locations loc
INNER JOIN job_averages ja ON loc.location_id = ja.location_id
WHERE loc.state NOT IN ('Not USA', 'Unclassified')
GROUP BY loc.state_cleaned, ja.period_end
HAVING sample_size_jobs > 20
ORDER BY loc.state_cleaned, ja.period_end
""")

    # ── By MSA (cell 14) ─────────────────────────────────────────────────────
    by_msa = _run_sql(shared + """
job_averages AS (
    SELECT
        location_id,
        month_end_dates.month_end AS period_end,
        timeseries_data.job_id,
        SUM(timeseries_data.total_wages_earned) / SUM(timeseries_data.hours_worked) AS wage_rate
    FROM timeseries_data
    JOIN month_end_dates
      ON timeseries_data.timecard_created_at::DATE
         BETWEEN month_end_dates.month_beginning AND month_end_dates.month_end
    GROUP BY location_id, period_end, job_id
)
SELECT ja.period_end,
       loc.msa,
       AVG(ja.wage_rate)         AS wage_rate,
       COUNT(DISTINCT ja.job_id) AS sample_size_jobs
FROM public.locations loc
INNER JOIN job_averages ja ON loc.location_id = ja.location_id
WHERE loc.state NOT IN ('Not USA', 'Unclassified')
GROUP BY loc.msa, ja.period_end
HAVING sample_size_jobs > 20
ORDER BY loc.msa, ja.period_end
""")

    # ── Dynamic Jan 2022 baseline — derived from query, never hardcoded ───────
    jan2022 = next(
        (r for r in national if str(r.get("period_end", "")).startswith("2022-01")),
        None,
    )
    jan2022_baseline = float(jan2022["wage_rate"]) if jan2022 else None

    for row in national:
        row["pct_above_jan2022"] = (
            round((float(row["wage_rate"]) - jan2022_baseline) / jan2022_baseline * 100, 2)
            if jan2022_baseline and row.get("wage_rate") else None
        )

    return {
        "national":         national,
        "by_industry":      by_industry,
        "by_state":         by_state,
        "by_msa":           by_msa,
        "jan2022_baseline": jan2022_baseline,
    }


def get_wages() -> dict:
    return _cached("wages", CACHE_TTL_SLOW, _fetch_wages_raw)


# ── Hiring & turnover (mirrors notebook cells 21, 25) ────────────────────────
# All temp views inlined as CTEs — each _run_sql is a separate session.

def _hiring_sql(DATE: str) -> str:
    return f"""
WITH
{_month_end_cte(DATE)},
{_consideration_and_location_ctes()}
SELECT
    month_end_dates.month_end                     AS period_end,
    COUNT(DISTINCT location_info.location_id)     AS ss,
    COUNT(*)                                      AS timeseries_data
FROM location_info
INNER JOIN postgres.jobs
        ON location_info.location_id = jobs.location_id
INNER JOIN month_end_dates
        ON jobs.created_at::DATE
           BETWEEN month_end_dates.month_beginning AND month_end_dates.month_end
WHERE location_info.state NOT IN ('Not USA')
  AND location_info.company_created_date < month_end_dates.year_beginning
GROUP BY period_end
ORDER BY period_end
"""


def _turnover_sql(DATE: str) -> str:
    return f"""
WITH
{_month_end_cte(DATE)},
{_consideration_and_location_ctes()}
SELECT
    month_end_dates.month_end                     AS period_end,
    COUNT(DISTINCT location_info.location_id)     AS ss,
    COUNT(*)                                      AS timeseries_data
FROM location_info
INNER JOIN postgres.jobs
        ON location_info.location_id = jobs.location_id
INNER JOIN month_end_dates
        ON jobs.archived_at::DATE
           BETWEEN month_end_dates.month_beginning AND month_end_dates.month_end
LEFT JOIN postgres.job_versions jv
        ON jv.item_id = jobs.id
       AND jv.created_at::date = jobs.archived_at::date
WHERE location_info.state NOT IN ('Not USA')
  AND location_info.company_created_date < month_end_dates.year_beginning
  AND month_end_dates.month_end > '2018-12-01'
  AND lower(jv.whodunnit) NOT LIKE '%rake businesses:archive_invoiced_company%'
  AND lower(jv.whodunnit) NOT LIKE '%lockjobworker%'
  AND lower(jv.whodunnit) NOT LIKE '%handlejobterminationworker%'
GROUP BY period_end
ORDER BY period_end
"""


def _normalise_and_index(rows: list[dict]) -> list[dict]:
    """Compute per-location value and index to January of each year."""
    for r in rows:
        ss = float(r.get("ss") or 1)
        r["per_loc"] = round(float(r["timeseries_data"]) / ss, 4) if ss else None

    jan_by_year: dict[int, float] = {}
    for r in rows:
        yr = int(str(r["period_end"])[:4])
        mo = int(str(r["period_end"])[5:7])
        if mo == 1 and r["per_loc"] is not None:
            jan_by_year[yr] = r["per_loc"]

    for r in rows:
        yr  = int(str(r["period_end"])[:4])
        jan = jan_by_year.get(yr)
        r["indexed"] = (
            round((r["per_loc"] - jan) / jan * 100, 2)
            if jan and r["per_loc"] is not None else None
        )
    return rows


def _fetch_jobs_raw() -> dict:
    d    = _report_dates()
    DATE = d["DATE"]
    hiring   = _run_sql(_hiring_sql(DATE))
    turnover = _run_sql(_turnover_sql(DATE))
    return {
        "hiring":   _normalise_and_index(hiring),
        "turnover": _normalise_and_index(turnover),
    }


def get_jobs() -> dict:
    return _cached("jobs", CACHE_TTL_SLOW, _fetch_jobs_raw)


# ── Indexed labor metrics ─────────────────────────────────────────────────────
# Source: indexed_values_query.sql — benchmark tables from corona schema.
# Falls back to inline benchmark computation if tables are inaccessible.

_INDEXED_SQL = """
WITH
reference_months AS (
    SELECT yr, mo,
        date_sub(
            make_date(yr, mo, 12),
            (dayofweek(make_date(yr, mo, 12)) - 1) % 7
        ) AS reference_sunday
    FROM (VALUES
        (2024,1),(2024,2),(2024,3),(2024,4),(2024,5),(2024,6),
        (2024,7),(2024,8),(2024,9),(2024,10),(2024,11),(2024,12),
        (2025,1),(2025,2),(2025,3),(2025,4),(2025,5),(2025,6),
        (2025,7),(2025,8),(2025,9),(2025,10),(2025,11),(2025,12),
        (2026,1),(2026,2),(2026,3),(2026,4),(2026,5),(2026,6),
        (2026,7),(2026,8),(2026,9),(2026,10),(2026,11),(2026,12)
    ) AS t(yr, mo)
),
daily_actuals AS (
    SELECT
        event_date,
        year(event_date)            AS yr,
        dayofweek(event_date) - 1   AS day_of_week,
        location_id,
        COUNT(DISTINCT CASE WHEN has_clock_in = 1 THEN user_id END)                AS users_with_clock_in,
        SUM(CASE WHEN has_clock_in = 1 THEN COALESCE(hours_worked, 0) ELSE 0 END)  AS total_hours_worked,
        MAX(CASE WHEN has_clock_in = 1 THEN 1 ELSE 0 END)                          AS is_open
    FROM corona.shift_and_timecard_events
    WHERE event_date >= '2024-01-01'
      AND event_date <= current_date()
      AND state NOT IN ('Not USA', 'Unclassified')
    GROUP BY event_date, location_id
),
daily_index AS (
    SELECT
        a.event_date,
        a.yr,
        SUM(a.users_with_clock_in) / NULLIF(SUM(b.users_with_clock_in), 0) - 1  AS idx_employees,
        SUM(a.total_hours_worked)  / NULLIF(SUM(b.total_hours_worked), 0)  - 1  AS idx_hours,
        SUM(a.is_open) / NULLIF(SUM(b.denominator_clock_ins / 4.0), 0)    - 1  AS idx_open
    FROM daily_actuals a
    INNER JOIN (
        SELECT location_id, day_of_week, users_with_clock_in, total_hours_worked, denominator_clock_ins, 2024 AS yr FROM corona.location_usage_benchmarks_from_aph_jan_2024
        UNION ALL
        SELECT location_id, day_of_week, users_with_clock_in, total_hours_worked, denominator_clock_ins, 2025 AS yr FROM corona.location_usage_benchmarks_from_aph_jan_2025
        UNION ALL
        SELECT location_id, day_of_week, users_with_clock_in, total_hours_worked, denominator_clock_ins, 2026 AS yr FROM corona.location_usage_benchmarks_from_aph_jan_2026
    ) b ON a.location_id = b.location_id
       AND a.day_of_week = b.day_of_week
       AND a.yr = b.yr
    GROUP BY a.event_date, a.yr
),
monthly AS (
    SELECT
        rm.yr,
        rm.mo,
        rm.reference_sunday,
        ROUND(AVG(di.idx_employees) * 100, 2) AS employees_working_pct,
        ROUND(AVG(di.idx_hours)     * 100, 2) AS hours_worked_pct,
        ROUND(AVG(di.idx_open)      * 100, 2) AS businesses_open_pct
    FROM reference_months rm
    JOIN daily_index di
        ON  di.event_date >= rm.reference_sunday
        AND di.event_date <  date_add(rm.reference_sunday, 7)
        AND di.yr = rm.yr
    GROUP BY rm.yr, rm.mo, rm.reference_sunday
    HAVING COUNT(di.event_date) > 0
)
SELECT
    yr   AS year,
    mo   AS month,
    CAST(reference_sunday AS STRING) AS reference_sunday,
    employees_working_pct,
    hours_worked_pct,
    businesses_open_pct,
    ROUND(employees_working_pct - LAG(employees_working_pct) OVER (PARTITION BY yr ORDER BY mo), 2) AS employees_mom_ppt,
    ROUND(hours_worked_pct     - LAG(hours_worked_pct)     OVER (PARTITION BY yr ORDER BY mo), 2) AS hours_mom_ppt,
    ROUND(businesses_open_pct  - LAG(businesses_open_pct)  OVER (PARTITION BY yr ORDER BY mo), 2) AS open_mom_ppt
FROM monthly
ORDER BY yr, mo
"""

# Inline benchmark fallback — used when benchmark tables are inaccessible.
_INDEXED_SQL_INLINE = """
WITH
reference_months AS (
    SELECT yr, mo,
        date_sub(
            make_date(yr, mo, 12),
            (dayofweek(make_date(yr, mo, 12)) - 1) % 7
        ) AS reference_sunday
    FROM (VALUES
        (2024,1),(2024,2),(2024,3),(2024,4),(2024,5),(2024,6),
        (2024,7),(2024,8),(2024,9),(2024,10),(2024,11),(2024,12),
        (2025,1),(2025,2),(2025,3),(2025,4),(2025,5),(2025,6),
        (2025,7),(2025,8),(2025,9),(2025,10),(2025,11),(2025,12),
        (2026,1),(2026,2),(2026,3),(2026,4),(2026,5),(2026,6),
        (2026,7),(2026,8),(2026,9),(2026,10),(2026,11),(2026,12)
    ) AS t(yr, mo)
),
daily_actuals AS (
    SELECT
        event_date,
        year(event_date)            AS yr,
        month(event_date)           AS mo_num,
        dayofweek(event_date) - 1   AS day_of_week,
        location_id,
        COUNT(DISTINCT CASE WHEN has_clock_in = 1 THEN user_id END)                AS users_with_clock_in,
        SUM(CASE WHEN has_clock_in = 1 THEN COALESCE(hours_worked, 0) ELSE 0 END)  AS total_hours_worked,
        MAX(CASE WHEN has_clock_in = 1 THEN 1 ELSE 0 END)                          AS is_open
    FROM corona.shift_and_timecard_events
    WHERE event_date >= '2024-01-01'
      AND event_date <= current_date()
      AND state NOT IN ('Not USA', 'Unclassified')
    GROUP BY event_date, location_id
),
jan_benchmark AS (
    SELECT yr, location_id, day_of_week,
        AVG(users_with_clock_in)   AS users_with_clock_in,
        AVG(total_hours_worked)    AS total_hours_worked,
        COUNT(DISTINCT event_date) AS denominator_clock_ins
    FROM daily_actuals
    WHERE mo_num = 1
    GROUP BY yr, location_id, day_of_week
),
daily_index AS (
    SELECT
        a.event_date,
        a.yr,
        SUM(a.users_with_clock_in) / NULLIF(SUM(b.users_with_clock_in), 0) - 1  AS idx_employees,
        SUM(a.total_hours_worked)  / NULLIF(SUM(b.total_hours_worked), 0)  - 1  AS idx_hours,
        SUM(a.is_open) / NULLIF(SUM(b.denominator_clock_ins / 4.0), 0)    - 1  AS idx_open
    FROM daily_actuals a
    INNER JOIN jan_benchmark b
           ON a.location_id = b.location_id
          AND a.day_of_week = b.day_of_week
          AND a.yr = b.yr
    GROUP BY a.event_date, a.yr
),
monthly AS (
    SELECT
        rm.yr,
        rm.mo,
        rm.reference_sunday,
        ROUND(AVG(di.idx_employees) * 100, 2) AS employees_working_pct,
        ROUND(AVG(di.idx_hours)     * 100, 2) AS hours_worked_pct,
        ROUND(AVG(di.idx_open)      * 100, 2) AS businesses_open_pct
    FROM reference_months rm
    JOIN daily_index di
        ON  di.event_date >= rm.reference_sunday
        AND di.event_date <  date_add(rm.reference_sunday, 7)
        AND di.yr = rm.yr
    GROUP BY rm.yr, rm.mo, rm.reference_sunday
    HAVING COUNT(di.event_date) > 0
)
SELECT
    yr   AS year,
    mo   AS month,
    CAST(reference_sunday AS STRING) AS reference_sunday,
    employees_working_pct,
    hours_worked_pct,
    businesses_open_pct,
    ROUND(employees_working_pct - LAG(employees_working_pct) OVER (PARTITION BY yr ORDER BY mo), 2) AS employees_mom_ppt,
    ROUND(hours_worked_pct     - LAG(hours_worked_pct)     OVER (PARTITION BY yr ORDER BY mo), 2) AS hours_mom_ppt,
    ROUND(businesses_open_pct  - LAG(businesses_open_pct)  OVER (PARTITION BY yr ORDER BY mo), 2) AS open_mom_ppt
FROM monthly
ORDER BY yr, mo
"""


def _fetch_labor_raw() -> list[dict]:
    try:
        return _run_sql(_INDEXED_SQL)
    except Exception:
        return _run_sql(_INDEXED_SQL_INLINE)


def get_labor() -> list[dict]:
    return _cached("labor", CACHE_TTL_FAST, _fetch_labor_raw)


# ── Overview: latest month snapshot for all 6 KPI cards ──────────────────────

def get_overview() -> dict:
    labor = get_labor()
    wages = get_wages()
    jobs  = get_jobs()

    latest_labor = labor[-1] if labor else {}

    nat          = wages.get("national", [])
    latest_wage  = nat[-1] if nat else {}
    prev_wage    = nat[-2] if len(nat) >= 2 else {}

    hiring       = jobs.get("hiring", [])
    turnover     = jobs.get("turnover", [])
    latest_hire  = hiring[-1]   if hiring   else {}
    prev_hire    = hiring[-2]   if len(hiring)   >= 2 else {}
    latest_turn  = turnover[-1] if turnover else {}
    prev_turn    = turnover[-2] if len(turnover) >= 2 else {}

    def _mom(cur, prev, key):
        c, p = cur.get(key), prev.get(key)
        return round(float(c) - float(p), 2) if c is not None and p is not None else None

    return {
        "as_of":   latest_labor.get("reference_sunday"),
        "metrics": {
            "employees_working": {
                "value":      latest_labor.get("employees_working_pct"),
                "unit":       "% vs Jan baseline",
                "mom_change": latest_labor.get("employees_mom_ppt"),
            },
            "hours_worked": {
                "value":      latest_labor.get("hours_worked_pct"),
                "unit":       "% vs Jan baseline",
                "mom_change": latest_labor.get("hours_mom_ppt"),
            },
            "businesses_open": {
                "value":      latest_labor.get("businesses_open_pct"),
                "unit":       "% vs Jan baseline",
                "mom_change": latest_labor.get("open_mom_ppt"),
            },
            "hourly_wages": {
                "value":             latest_wage.get("wage_rate"),
                "unit":              "$/hr",
                "pct_above_jan2022": latest_wage.get("pct_above_jan2022"),
                "mom_change":        _mom(latest_wage, prev_wage, "wage_rate"),
            },
            "jobs_added": {
                "value":      latest_hire.get("per_loc"),
                "unit":       "jobs/location",
                "indexed":    latest_hire.get("indexed"),
                "mom_change": _mom(latest_hire, prev_hire, "per_loc"),
            },
            "jobs_archived": {
                "value":      latest_turn.get("per_loc"),
                "unit":       "jobs/location",
                "indexed":    latest_turn.get("indexed"),
                "mom_change": _mom(latest_turn, prev_turn, "per_loc"),
            },
        },
    }
