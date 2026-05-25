-- =============================================================================
-- Recreate corona.location_usage_benchmarks_from_aph_jan_YYYY
-- Ported from original PostgreSQL script to Databricks SQL
--
-- Run once per year, in January, using that year's January data.
-- Change the table name and date range (two places marked ← CHANGE) each run.
--
-- DATE RANGE: manually chosen each January — no fixed algorithm.
-- Rule: 4 complete weeks (28 days) avoiding New Year's holiday distortion.
-- The window may extend into early February when needed (see 2021).
--
-- Confirmed historical ranges:
--   2026: 2026-01-04 to 2026-01-31
--   2025: 2025-01-05 to 2025-02-01
--   2024: 2024-01-07 to 2024-02-03
--   2023: 2023-01-08 to 2023-02-04
--   2022: 2022-01-03 to 2022-01-30
--   2021: 2021-01-09 to 2021-02-05  (extends into February)
--   2020: 2020-01-04 to 2020-01-31
--   2019: 2019-01-04 to 2019-01-31
--   2018: 2018-01-04 to 2018-01-31
--
-- DOW encoding: 0=Sunday … 6=Saturday  (PostgreSQL convention)
--   In Databricks: dayofweek(date) returns 1=Sun … use dayofweek()-1 to match.
--
-- Table grain: location_id, state, msa, industry, city, day_of_week
--
-- Column structure (three tiers):
--   1. Denominators  — count of distinct days where each metric had activity > 0
--   2. 4-week totals — raw sums across the 28-day window
--   3. Daily benchmarks — totals / denominators (what Looker uses for relative level)
--
-- Note on benchmark_locs_with_clock_ins:
--   NOT stored in this table. Derived in the Looker view as:
--     denominator_clock_ins / 4.0
--   = fraction of this DOW's 4 January days the location had ≥1 clock-in.
--   SUM() of this value across all locations = expected open-location count (aggregate
--   benchmark denominator for Relative Level Agg Locs with Clock Ins).
--
-- Source: corona.daily_agg_shifts_timecards_sales is deprecated.
-- This script replicates its per-location-per-day aggregation inline from
-- corona.shift_and_timecard_events. Sales columns omitted (not in source table;
-- MSHR never uses them).
-- =============================================================================

CREATE OR REPLACE TABLE corona.location_usage_benchmarks_from_aph_jan_2026  -- ← CHANGE YEAR
AS

WITH

-- ── Step 1: Daily location-level aggregates ───────────────────────────────────
-- Replicates corona.daily_agg_shifts_timecards_sales (deprecated).
-- No eligibility filter here — state/US filtering is applied in Looker at query time,
-- consistent with the original script.
daily_agg AS (
    SELECT
        location_id,
        state,
        msa,
        industry,
        city,
        event_date,

        -- Activity flags: 1 if location had ANY of this activity on this day
        MAX(has_clock_in)                                                           AS has_clock_in,
        MAX(CASE WHEN unscheduled = 0 THEN 1 ELSE 0 END)                           AS has_scheduled_shift,

        -- Daily metrics per location
        COUNT(DISTINCT CASE WHEN has_clock_in = 1 THEN user_id END)                AS users_with_clock_in,
        COUNT(CASE WHEN has_clock_in = 1 AND unscheduled = 0 THEN 1 END)           AS scheduled_clock_ins,
        COUNT(DISTINCT CASE WHEN unscheduled = 0 THEN user_id END)                 AS users_with_scheduled_shifts,
        COUNT(DISTINCT CASE WHEN unscheduled = 0 THEN shift_id END)                AS total_scheduled_shifts,
        COUNT(CASE WHEN has_clock_in = 1 THEN 1 END)                               AS total_clock_ins,
        SUM(COALESCE(hours_scheduled, 0))                                           AS total_hours_scheduled,
        SUM(CASE WHEN has_clock_in = 1 THEN COALESCE(hours_worked, 0) ELSE 0 END)  AS total_hours_worked

    FROM corona.shift_and_timecard_events
    WHERE event_date BETWEEN '2026-01-04' AND '2026-01-31'   -- ← CHANGE DATES EACH RUN
    GROUP BY location_id, state, msa, industry, city, event_date
),

-- ── Step 2: Aggregate to location × DOW ──────────────────────────────────────
benchmark AS (
    SELECT
        location_id,
        state,
        msa,
        industry,
        city,
        dayofweek(event_date) - 1                                                   AS day_of_week,  -- 0=Sun … 6=Sat

        COUNT(DISTINCT event_date)                                                  AS days_with_data,

        -- Denominators: days where each metric had activity > 0
        -- (zero-activity days excluded from the average per original methodology)
        NULLIF(COUNT(DISTINCT CASE WHEN has_clock_in = 1       THEN event_date END), 0) AS denominator_clock_ins,
        NULLIF(COUNT(DISTINCT CASE WHEN has_scheduled_shift = 1 THEN event_date END), 0) AS denominator_scheduled_shifts,
        NULLIF(COUNT(DISTINCT CASE WHEN has_clock_in = 1
                                    AND has_scheduled_shift = 1 THEN event_date END), 0) AS denominator_clock_ins_and_scheduled_shifts,

        -- 4-week totals
        SUM(users_with_clock_in)         AS users_with_clock_in_4weeks,
        SUM(scheduled_clock_ins)         AS scheduled_clock_ins_4weeks,
        SUM(users_with_scheduled_shifts) AS users_with_scheduled_shifts_4weeks,
        SUM(total_scheduled_shifts)      AS total_scheduled_shifts_4weeks,
        SUM(total_clock_ins)             AS total_clock_ins_4weeks,
        SUM(total_hours_scheduled)       AS total_hours_scheduled_4weeks,
        SUM(total_hours_worked)          AS total_hours_worked_4weeks

    FROM daily_agg
    GROUP BY location_id, state, msa, industry, city, dayofweek(event_date) - 1
)

-- ── Step 3: Daily benchmarks = totals / denominators ─────────────────────────
SELECT
    location_id,
    state,
    msa,
    industry,
    city,
    day_of_week,
    days_with_data,

    -- Denominators (stored for reference and for benchmark_locs_with_clock_ins derivation)
    denominator_clock_ins,
    denominator_scheduled_shifts,
    denominator_clock_ins_and_scheduled_shifts,

    -- 4-week totals (stored for reference)
    users_with_clock_in_4weeks,
    scheduled_clock_ins_4weeks,
    users_with_scheduled_shifts_4weeks,
    total_scheduled_shifts_4weeks,
    total_clock_ins_4weeks,
    total_hours_scheduled_4weeks,
    total_hours_worked_4weeks,

    -- Daily benchmarks (totals / denominators)
    -- These are the per-location values Looker sums to form the aggregate benchmark denominator
    CAST(users_with_clock_in_4weeks AS DOUBLE)
        / denominator_clock_ins                            AS users_with_clock_in,
    CAST(scheduled_clock_ins_4weeks AS DOUBLE)
        / denominator_clock_ins_and_scheduled_shifts       AS scheduled_clock_ins,
    CAST(users_with_scheduled_shifts_4weeks AS DOUBLE)
        / denominator_scheduled_shifts                     AS users_with_scheduled_shifts,
    CAST(total_scheduled_shifts_4weeks AS DOUBLE)
        / denominator_scheduled_shifts                     AS total_scheduled_shifts,
    CAST(total_clock_ins_4weeks AS DOUBLE)
        / denominator_clock_ins                            AS total_clock_ins,
    CAST(total_hours_scheduled_4weeks AS DOUBLE)
        / denominator_scheduled_shifts                     AS total_hours_scheduled,
    CAST(total_hours_worked_4weeks AS DOUBLE)
        / denominator_clock_ins                            AS total_hours_worked

FROM benchmark
;


-- =============================================================================
-- VERIFICATION QUERIES — run after CREATE TABLE to confirm correctness
-- =============================================================================

-- 1. Confirm DOW distribution is symmetric (should be same location count for all 7 DOWs)
SELECT day_of_week, COUNT(*) AS location_count
FROM corona.location_usage_benchmarks_from_aph_jan_2026
GROUP BY day_of_week
ORDER BY day_of_week;

-- 2. Confirm days_with_data = 4 for all rows (28-day window = 4 of each DOW)
SELECT MIN(days_with_data) AS min_days, MAX(days_with_data) AS max_days
FROM corona.location_usage_benchmarks_from_aph_jan_2026;
-- Both should be 4

-- 3. Sample relative level for a known date — compare to D-Employees_working in Excel
-- benchmark_locs_with_clock_ins is derived here as denominator_clock_ins / 4.0
SELECT
    e.event_date,
    SUM(e.users_with_clock_in) / NULLIF(SUM(b.users_with_clock_in), 0) - 1       AS rel_employees_working,
    SUM(e.total_hours_worked)  / NULLIF(SUM(b.total_hours_worked), 0)  - 1       AS rel_hours_worked,
    SUM(e.is_open)             / NULLIF(SUM(b.denominator_clock_ins / 4.0), 0) - 1 AS rel_businesses_open
FROM (
    SELECT
        event_date,
        location_id,
        dayofweek(event_date) - 1                                                   AS day_of_week,
        COUNT(DISTINCT CASE WHEN has_clock_in = 1 THEN user_id END)                AS users_with_clock_in,
        SUM(CASE WHEN has_clock_in = 1 THEN COALESCE(hours_worked, 0) ELSE 0 END)  AS total_hours_worked,
        MAX(CASE WHEN has_clock_in = 1 THEN 1 ELSE 0 END)                          AS is_open
    FROM corona.shift_and_timecard_events
    WHERE year(event_date) = 2026
      AND state NOT IN ('Not USA', 'Unclassified')
    GROUP BY event_date, location_id
) e
JOIN corona.location_usage_benchmarks_from_aph_jan_2026 b
    ON e.location_id = b.location_id AND e.day_of_week = b.day_of_week
GROUP BY e.event_date
ORDER BY e.event_date;
