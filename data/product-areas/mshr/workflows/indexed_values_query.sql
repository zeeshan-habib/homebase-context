-- =============================================================================
-- MSHR: Indexed Values — Employees Working, Hours Worked, Businesses Open
-- Aggregate (national), 3-year overlay: 2024 / 2025 / 2026
--
-- Methodology (per mshr.md):
--   1. Join daily actuals to corona.location_usage_benchmarks_from_aph_jan_[YYYY]
--      on location_id × day_of_week (0=Sun … 6=Sat)
--   2. Relative level (daily) = SUM(actual) / SUM(benchmark) − 1
--      For businesses open: SUM(is_open) / SUM(denominator_clock_ins / 4.0) − 1
--   3. Monthly value = 7-day avg over [reference_sunday, reference_sunday + 6]
--      where reference_sunday = Sunday of the week containing the 12th of each month
--   4. MoM change = current_month_avg − prior_month_avg (both in indexed units → ppt)
--
-- Source tables:
--   corona.shift_and_timecard_events     — daily actuals
--   corona.location_usage_benchmarks_from_aph_jan_[YYYY]  — per-location DOW benchmarks
--
-- DOW join: benchmark table uses 0=Sun … 6=Sat (PostgreSQL convention)
--   Databricks dayofweek() returns 1=Sun … so use dayofweek()-1 on both sides.
-- =============================================================================

WITH

-- ── Reference Sunday for each report month ────────────────────────────────────
-- Sunday of the week containing the 12th.
-- dayofweek() in Databricks: 1=Sun → (dayofweek()-1) % 7 gives 0=Sun offset.
-- Subtract offset from the 12th to land on the preceding (or same-day) Sunday.
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
        (2026,1),(2026,2),(2026,3),(2026,4),(2026,5)
    ) AS t(yr, mo)
),

-- ── Daily location-level actuals ──────────────────────────────────────────────
daily_actuals AS (
    SELECT
        event_date,
        year(event_date)            AS yr,
        dayofweek(event_date) - 1   AS day_of_week,   -- 0=Sun … 6=Sat (matches benchmark table)
        location_id,
        COUNT(DISTINCT CASE WHEN has_clock_in = 1 THEN user_id END)                AS users_with_clock_in,
        SUM(CASE WHEN has_clock_in = 1 THEN COALESCE(hours_worked, 0) ELSE 0 END)  AS total_hours_worked,
        MAX(CASE WHEN has_clock_in = 1 THEN 1 ELSE 0 END)                          AS is_open
    FROM corona.shift_and_timecard_events
    WHERE year(event_date) IN (2024, 2025, 2026)
      AND event_date >= '2024-01-01'
      AND state NOT IN ('Not USA', 'Unclassified')
    GROUP BY event_date, location_id
),

-- ── Daily aggregate relative level ───────────────────────────────────────────
-- Join each day's actuals to the benchmark for that year, on location × DOW.
-- Ratio of aggregate actuals to aggregate benchmarks (Looker's "Agg" approach:
-- sum actuals / sum benchmarks, not per-location ratios averaged).
-- INNER JOIN: only locations with a January benchmark included (consistent with Looker).
daily_index AS (
    SELECT
        a.event_date,
        a.yr,
        -- Employees Working: SUM(actual users) / SUM(benchmark users) − 1
        SUM(a.users_with_clock_in) / NULLIF(SUM(b.users_with_clock_in), 0) - 1       AS idx_employees,
        -- Hours Worked: SUM(actual hours) / SUM(benchmark hours) − 1
        SUM(a.total_hours_worked)  / NULLIF(SUM(b.total_hours_worked), 0)  - 1       AS idx_hours,
        -- Businesses Open: SUM(is_open) / SUM(denominator_clock_ins/4) − 1
        -- denominator_clock_ins/4 = fraction of Jan DOW days that location was open
        -- SUM across locations = expected open location count (aggregate benchmark)
        SUM(a.is_open) / NULLIF(SUM(b.denominator_clock_ins / 4.0), 0) - 1          AS idx_open
    FROM daily_actuals a
    INNER JOIN (
        -- Union all three years' benchmark tables
        SELECT location_id, day_of_week, users_with_clock_in, total_hours_worked, denominator_clock_ins, 2024 AS yr FROM corona.location_usage_benchmarks_from_aph_jan_2024
        UNION ALL
        SELECT location_id, day_of_week, users_with_clock_in, total_hours_worked, denominator_clock_ins, 2025 AS yr FROM corona.location_usage_benchmarks_from_aph_jan_2025
        UNION ALL
        SELECT location_id, day_of_week, users_with_clock_in, total_hours_worked, denominator_clock_ins, 2026 AS yr FROM corona.location_usage_benchmarks_from_aph_jan_2026
    ) b ON a.location_id = b.location_id
       AND a.day_of_week = b.day_of_week
       AND a.yr          = b.yr
    GROUP BY a.event_date, a.yr
),

-- ── 7-day average for each month's reference window ──────────────────────────
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
        AND di.yr          = rm.yr
    GROUP BY rm.yr, rm.mo, rm.reference_sunday
)

-- ── Final output ──────────────────────────────────────────────────────────────
-- Values are expressed as % relative to January of each year (January ≈ 0).
-- MoM change = current − prior (both indexed → result is percentage-point change).
SELECT
    yr                        AS year,
    mo                        AS month,
    reference_sunday,
    employees_working_pct,
    hours_worked_pct,
    businesses_open_pct,
    -- MoM changes (ppt): partitioned by year so January has NULL (no prior month in same index year)
    ROUND(employees_working_pct - LAG(employees_working_pct) OVER (PARTITION BY yr ORDER BY mo), 2) AS employees_mom_ppt,
    ROUND(hours_worked_pct     - LAG(hours_worked_pct)     OVER (PARTITION BY yr ORDER BY mo), 2) AS hours_mom_ppt,
    ROUND(businesses_open_pct  - LAG(businesses_open_pct)  OVER (PARTITION BY yr ORDER BY mo), 2) AS open_mom_ppt
FROM monthly
ORDER BY yr, mo
;
