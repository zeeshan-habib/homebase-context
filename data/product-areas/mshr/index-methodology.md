---
owner: vlad-akimenko
last_updated: 2026-05-28
review_cadence: monthly
next_review: 2026-06-28
source: internal
refs:
  - data/product-areas/mshr/mshr.md
  - data/product-areas/mshr/schemas.md
  - data/product-areas/mshr/workflows/create_benchmark_table.sql
  - data/product-areas/mshr/workflows/indexed_values_query.sql
---

# MSHR Index Methodology

Load when you need to understand how the MSHR index values are calculated, how benchmarks are constructed, or how MoM changes are derived.

For source table schemas and column definitions, see `schemas.md`. For the ready-to-run SQL, see `workflows/indexed_values_query.sql` and `workflows/create_benchmark_table.sql`.

---

## Index Formula

Businesses Open, Employees Working, and Hours Worked are **not reported as raw counts**. They are reported as an index — the level relative to January of the same year, expressed as a decimal (e.g., 0.018 = +1.8% above January baseline). This allows side-by-side comparison of seasonal patterns across 2024, 2025, and 2026.

**Index formula (aggregate — Looker "Agg" method):**
```
relative_level (daily) = SUM(actual across all locations) / SUM(benchmark across all locations) − 1
```
- For Employees Working: `SUM(users_with_clock_in) / SUM(benchmark.users_with_clock_in) − 1`
- For Hours Worked: `SUM(total_hours_worked) / SUM(benchmark.total_hours_worked) − 1`
- For Businesses Open: `SUM(is_open) / SUM(benchmark.denominator_clock_ins / 4.0) − 1`

Ratios are summed at the aggregate level, **not** averaged per location. INNER JOIN ensures only locations with a January benchmark are included (consistent with Looker).

---

## Monthly Value — 7-Day Average

The monthly MSHR value for each metric is a **7-day average** over `[reference_sunday, reference_sunday + 6]`, where:

```
reference_sunday = Sunday of the week containing the 12th of the month
```

Compute as: `date_sub(make_date(yr, mo, 12), (dayofweek(make_date(yr, mo, 12)) - 1) % 7)`

This smooths out day-of-week effects and produces a stable monthly representative value.

---

## MoM Change

```
MoM_change = current_month_avg − prior_month_avg
```

Both averages are already indexed (relative to January of the same year). The result is therefore a **percentage-point change** — no additional division needed. January of each year has NULL (no prior month in the same year's series).

---

## Baseline Construction — Benchmark Tables

**Source:** `corona.daily_agg_shifts_timecards_sales` (deprecated) — if recreating, replicate inline from `corona.shift_and_timecard_events` (see `workflows/create_benchmark_table.sql`).

**Table grain:** `location_id, state, msa, industry, city, day_of_week` (5 grain dimensions)

**DOW encoding:** **0 = Sunday … 6 = Saturday** (PostgreSQL convention). In Databricks, use `dayofweek(date) - 1` to produce this encoding.

**Date range:** manually chosen each January — 4 complete weeks (28 days) avoiding New Year's holiday distortion. Window may extend into early February when needed. No algorithmic formula.

**Denominator:** `COUNT(DISTINCT event_date WHERE metric > 0)` — only days with actual activity; zero-activity days excluded from the per-location average.

**Column structure (three tiers):**
1. Denominators — count of days where each metric had activity > 0
2. 4-week totals — raw sums across the 28-day window
3. Daily benchmarks — totals / denominators (what Looker uses for relative level)

**`benchmark_locs_with_clock_ins`:** NOT stored in the benchmark table. Derived in Looker as `denominator_clock_ins / 4.0` per location per DOW. `SUM()` across locations = expected open-location count (aggregate benchmark denominator for Businesses Open).

---

## Benchmark Tables

One `_jan_YYYY` table is created each January. A new one must be created annually — see `workflows/data-sourcing.md → Recreating the Benchmark Table` for the full procedure.

| Table | Schema | Reference period (confirmed) | Status |
|---|---|---|---|
| `location_usage_benchmarks_from_aph_jan_2018` | `corona` | 2018-01-04 to 2018-01-31 | Superseded |
| `location_usage_benchmarks_from_aph_jan_2019` | `corona` | 2019-01-04 to 2019-01-31 | Superseded |
| `location_usage_benchmarks_from_aph_jan_2020` | `corona` | 2020-01-04 to 2020-01-31 | Superseded |
| `location_usage_benchmarks_from_aph_jan_2021` | `corona` | 2021-01-09 to 2021-02-05 (extends into Feb) | Active |
| `location_usage_benchmarks_from_aph_jan_2022` | `corona` | 2022-01-03 to 2022-01-30 | Active |
| `location_usage_benchmarks_from_aph_jan_2023` | `corona` | 2023-01-08 to 2023-02-04 | Active |
| `location_usage_benchmarks_from_aph_jan_2024` | `corona` | 2024-01-07 to 2024-02-03 | Active |
| `location_usage_benchmarks_from_aph_jan_2025` | `corona` | 2025-01-05 to 2025-02-01 | Active |
| `location_usage_benchmarks_from_aph_jan_2026` | `corona` | 2026-01-04 to 2026-01-31 | Active — current year |
| `location_usage_benchmarks_from_aph_weekly` | `corona` | Weekly aggregates (Jan 6 – Feb 2, 2020 baseline) | Supporting |
| `location_metadata_benchmarks_from_aph` | `corona` | Team size metadata (Jan 4–31, 2020) | Supporting |

**Supporting tables:**

| Table | Schema | What it provides | Status |
|---|---|---|---|
| `daily_agg_shifts_timecards_sales` | `corona` | **Deprecated.** Was a daily aggregation of `corona.shift_and_timecard_events` per location, with POS `has_sales` and `total_sales_dollars` columns added. MSHR never used sales data. If regenerating a benchmark, replace with an inline `GROUP BY location_id, state, msa, industry, city, event_date` aggregation from `corona.shift_and_timecard_events`. See `workflows/create_benchmark_table.sql`. | Inactive — do not use |
| `shifts_timecards_sales_aph` | `corona` | Date-spine table; provides a complete location × date grid for index calculations | Active |
| `jan_team_sizes` | `corona` | January weekly-average active users per location; used for team size benchmarking | Active |

---

## Reference Period Lookup — Reference Sundays by Month

The MSHR report uses the **Sunday of the week containing the 12th** of each month as the anchor date for the 7-day average window.

| Month | 2024 | 2025 | 2026 |
|---|---|---|---|
| January | Jan 7 | Jan 12 | Jan 11 |
| February | Feb 11 | Feb 9 | Feb 8 |
| March | Mar 10 | Mar 9 | Mar 8 |
| April | Apr 14 | Apr 6 | Apr 12 |
| May | May 12 | May 11 | May 10 |
| June | Jun 9 | Jun 8 | Jun 7 |
| July | Jul 7 | Jul 6 | Jul 12 |
| August | Aug 11 | Aug 10 | Aug 9 |
| September | Sep 8 | Sep 7 | Sep 6 |
| October | Oct 6 | Oct 12 | Oct 11 |
| November | Nov 10 | Nov 9 | Nov 8 |
| December | Dec 8 | Dec 7 | Dec 6 |

When adding a new year, compute each month's reference Sunday as: `DATE_TRUNC('week', DATE([year]-[month]-12))` (Trino/Presto: week starts Sunday by default).
