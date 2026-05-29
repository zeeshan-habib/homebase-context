# MSHR Workflows

Load when routing a task to the correct workflow file. This file is a routing index only — the actual methodology, pitfalls, and output rules are in dedicated files listed below.

## New to MSHR? Start here

Read in this order:

1. `domains/mshr/domain-overview.md` — what MSHR is, the two report tracks, and how they differ
2. `../data-model.md` — the three data pipelines, key entities, and disambiguation
3. `../mshr.md` — terminology, key metrics, suppression rules
4. `../schemas.md` — table/column definitions for each pipeline
5. This file (`workflows/CLAUDE.md`) — which workflow to load for a given task

**Two tracks, two different tools:**

| Track | Trigger | Primary tables | Key difference |
|---|---|---|---|
| Monthly MSHR | Calendar (monthly) | `corona.shift_and_timecard_events`, `postgres.jobs`, `postgres.payroll_payroll_runs` | Indexed to January baseline; 7-day rolling avg; matched payroll cohort for wages |
| Ad hoc MSHR | Leadership / GTM request | `dbt.new_data_weekly`, `dbt.temp_timeclock_data` (or monthly pipeline for wages) | Raw counts or simple % change; flexible window; wages still require payroll cohort |

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
| `industry-classification.sql` | NAICS code → `business_type_new` mapping reference |
| `event-impact-template.py` | Reference implementation of the event impact methodology. Edit CONFIG block for the target event. See `event-impact-methodology.md` for the statistical approach. |
| `event-impact-methodology.md` | Statistical methodology behind `event-impact-template.py` — YoY seasonality-adjusted delta, Welch's t-test, three-segment business model |
| `code-generation-protocol.md` | Request type classification, monthly and ad hoc methodology details, efficiency rules, normalization rules |
| `known-pitfalls.md` | 8 known bugs and required code structure for Databricks SQL/Python |
| `output-formats.md` | How to deliver results — Google Doc vs Databricks App, chart extraction from HTML exports |

## Which Workflow to Use

- Scheduled monthly report → `monthly-report.md`
- Leadership- or GTM-driven, scoped to a specific question or event → `adhoc-report.md`
- Question about which tables to use, data freshness, or `dbt.new_data_weekly` schema → `data-sourcing.md`
- Need to regenerate the January benchmark table → `create_benchmark_table.sql` + `data-sourcing.md → Recreating the Benchmark Table`
- Request involves an event (sporting event, hurricane, heatwave, policy announcement, etc.) → `event-impact-methodology.md` first, then `event-impact-template.py`
- Generating SQL or Python for MSHR data → `code-generation-protocol.md` + `known-pitfalls.md`
