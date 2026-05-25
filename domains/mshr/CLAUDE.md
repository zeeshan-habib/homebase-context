# MSHR Domain (Main Street Health Report)

Product context for the MSHR domain — a standalone reporting product that surfaces aggregated Homebase data as insights about small business health.

## File Index

| File | When to load |
|---|---|
| `mshr.md` | **Canonical data field guide.** Full SQL definitions, table schemas, column logic, suppression rules, index formulas, and report production pipeline. Load this for any Databricks query or calculation task. |
| `domain-overview.md` | What MSHR is, how the report is produced, key workflows and stakeholders |
| `customers.md` | Audience archetypes — who reads MSHR, what they need from it |
| `data-model.md` | Key entities, data sources, and how MSHR data relates to core Homebase entities |
| `okrs-and-metrics.md` | The six MSHR metrics — business definitions and which slide each appears on |

| Subfolder | When to load |
|---|---|
| `workflows/` | Specific MSHR processes — report production, data sourcing, ad hoc scoping |

## How to Use This Domain

### Generating a Monthly MSHR Report

Follow `workflows/monthly-report.md` end-to-end. Key points:
- Labor metrics (Employees Working, Hours Worked, Businesses Open) come from Looker Explore `coronavirus_data_aph_jan_[YYYY]` — values arrive already indexed to January; no further indexing needed
- Wages, hiring, and turnover come from the Databricks notebook: [Wages, Hiring & Turnover](https://homebase-staging.cloud.databricks.com/editor/notebooks/2248482107468255?o=373323366197249)
- All numbers flow through the master Excel file (`Main Street Health Report - 2026.xlsx`) before entering the PPTX

### Generating an Ad Hoc Report

Follow `workflows/adhoc-report.md`. Always ask the required clarifying questions before pulling any data. Fast path by use case:

| Need | Table to use |
|---|---|
| National weekly time series | `dbt.new_data_weekly` |
| State-level weekly time series | `dbt.new_state_data_weekly` |
| Custom segmentation (engagement, size band, industry) | `dbt.temp_timeclock_data` (filter directly) |
| City or MSA level | `dbt.temp_timeclock_data` — no pre-aggregate exists for city/MSA |
| Wages | Payroll cohort query from `mshr.md` scoped to the requested window |
| Hiring or turnover | Hiring/turnover queries from `mshr.md` scoped to the requested window |

DBT tables are built by the [DBT notebook](https://homebase-staging.cloud.databricks.com/editor/notebooks/155412963220333?o=373323366197249) in Databricks.

### Where Metrics Are Defined

| What you need | Where to look |
|---|---|
| Business definition (what it means, why it matters) | `okrs-and-metrics.md` |
| Technical definition (SQL, table, column, formula) | `mshr.md` |
| Which PPTX slide a metric appears on | `okrs-and-metrics.md` |
| Ready-to-run example queries | `mshr.md` — Example Queries section |
| Which Databricks notebook produces it | `workflows/data-sourcing.md` |

### Databricks Connection Notes

- **Labor metrics (indexed):** already computed in Looker via `corona.location_usage_benchmarks_from_aph_jan_[YYYY]`; you can also derive them directly from `corona.shift_and_timecard_events` using the index formula in `mshr.md`
- **Wages:** query `postgres.payroll_payroll_runs` + `corona.shift_and_timecard_events` using the matched-cohort method in `mshr.md`
- **Hiring / turnover:** query `postgres.jobs` + `postgres.job_versions`; always exclude system archivations via `whodunnit` filters
- **Ad hoc:** `dbt.new_data_weekly` is the fastest entry point — pre-qualified, pre-aggregated, ready to filter and format

## Domain Owner

- **PM:** Vlad Akimenko
- **Slack:** #main_street_health_report
