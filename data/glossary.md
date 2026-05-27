<!-- Load when: looking up the canonical definition of any Homebase metric — this is the single source of truth for all metric definitions across the repo -->

---
owner: analytics
last_updated: 2026-05-26
review_cadence: quarterly
next_review: 2026-08-26
source: internal
refs:
  - data/product-areas/mshr/mshr.md
  - global/business-overview.md
---

# Homebase Metrics Glossary

Canonical definitions for all metrics referenced across this repo. Domain files and product-area files reference these definitions — they do not restate them.

**Rule:** If a metric name appears in a domain file without a link here, that is a bug.

---

## MSHR Metrics

Six metrics produced by the Main Street Health Report pipeline. For full SQL, cohort rules, and suppression logic, see [`data/product-areas/mshr/mshr.md`](product-areas/mshr/mshr.md).

| Metric | Definition | Primary source | Breakdown dimensions | Report slide |
|---|---|---|---|---|
| **Employees Working** | Count of distinct employees with ≥1 clock-in in the reference week (7-day rolling average centered on the 12th of the month). Indexed to January of the base year. | `corona.shift_and_timecard_events` | Overall; by region; by industry | Slide 3 |
| **Hours Worked** | Total timecard hours (`clock_out − clock_in`) logged in the reference week. Indexed to January baseline. | `corona.shift_and_timecard_events` | Overall; by region; by industry | Slide 4 |
| **Businesses Open** | Count of distinct locations with ≥1 clock-in in the reference week. Not normalized. | `corona.shift_and_timecard_events` | Overall; by Census region | Slide 5 |
| **Hourly Wages** | Average hourly wage across all jobs in the matched payroll cohort for the reference month. Expressed as a percentage above the January 2022 baseline ($11.4829). Computed as: average of (`SUM(total_wages_earned) / SUM(hours_worked)`) per `job_id`. | `corona.shift_and_timecard_events` joined to `postgres.payroll_payroll_runs` cohort | Overall; by industry (`locations.business_type_new`); by state; by MSA | Slides 7–8 |
| **Jobs Added** | Count of new roster jobs at qualifying locations in the reference month. Hire date = `MIN(postgres.jobs.created_at)` per employee per location. | `postgres.jobs` | Overall | Slide 9 |
| **Jobs Archived** | Count of archived roster jobs (`jobs.archived_at` in reference month) at qualifying locations, excluding system-driven archivations (rake jobs, lock workers, termination workers). | `postgres.jobs` + `postgres.job_versions` (filtered by `whodunnit`) | Overall | Slide 10 |

### MSHR Cohort and Suppression Rules

| Rule | Value | Applies to |
|---|---|---|
| Location qualification | `employee_count IN ('5–9','10–19','20–49','50–99')` AND `location_age ≥ 84 days` AND `loc_archived_at IS NULL` | All 6 metrics |
| Suppression threshold | Drop any week/region with fewer than 30 qualifying locations | Employees Working, Hours Worked, Businesses Open |
| Payroll cohort | Location must appear in `payroll_payroll_runs` for both the reference month and 12 months prior | Hourly Wages only |
| Index baseline | January of the reporting year (or Jan 2022 for Hourly Wages) | Employees Working, Hours Worked, Businesses Open, Hourly Wages |

---

## Engagement Metrics

| Metric | Definition | Source |
|---|---|---|
| **Engaged (Core)** | Location where an OAM was active in the last 30 days AND the location used time tracking or scheduling in the last 7 days. | `bizops.product_location_engagement_metrics.engagement_boolean` |
| **Scheduling Engaged** | Location that published ≥1 schedule in the last 7 days. | `bizops.product_location_engagement_metrics.scheduling_engaged_boolean` |
| **2D30** | Location active on ≥2 distinct days in the last 30 days (any product interaction). | `bizops.product_location_engagement_metrics.two_d_thirty_active_this_month` |

---

## Table Reference Convention

| Schema prefix | System | How to reference |
|---|---|---|
| `corona.*`, `dbt.*`, `operations.*` | Databricks (Hive Metastore) | Shorthand: `corona.shift_and_timecard_events`. Fully qualified: `hive_metastore.corona.shift_and_timecard_events` |
| `postgres.*`, `public.*` | Redshift (`prod_redshift_replica`) | Always use full path: `prod_redshift_replica.postgres.jobs`, `prod_redshift_replica.public.locations` |

Use shorthand Databricks paths in SQL examples (matching the default catalog context). Always use fully qualified paths for Redshift tables.
