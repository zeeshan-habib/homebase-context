# Key Tables & Join Patterns

## Overview

This document describes the most important data tables used across Homebase analytics, how they relate to each other, and what questions each table is best suited to answer. It is derived from the `pioneerworks/looker` LookML repository.

**When to use this file:** When writing SQL queries or asking Claude for analytics help, reference this file to understand which tables to use and how to connect them.

---

## The Central Table: `public.locations`

Almost every analysis at Homebase starts with `public.locations`. It is the **primary unit of analysis** — one row per physical business location — and is joined to nearly every other table.

| LookML View Name | SQL Table | Description |
|---|---|---|
| `locations_v2` | `public.locations` | Master location dimension: business type, tier, state, employee count, activity flags, billing |

**Key identifiers on this table:**
- `location_id` — unique ID for each location (primary join key)
- `company_id` — links a location to its parent company
- `owner_id` — the user ID of the location owner

---

## Core Tables

### 1. `public.locations`
**What it's for:** Describing and segmenting locations — industry, plan tier, size, geography, activity status.

**Most commonly used fields:**
- `business_type_new` — broad industry (Food and Drink, Retail, Services, etc.)
- `tier_id` — subscription plan (1=Basic, 2=Essentials, 3=Plus, 4=AiO)
- `archived_at` — filter to `IS NULL` to exclude churned locations
- `total_employees`, `company_size`
- `state_cleaned`, `msa`

---

### 2. `public.companies`
**What it's for:** Company-level attributes. A company can have one or many locations.

| LookML View Name | SQL Table |
|---|---|
| `companies_v2` | `public.companies` |

**Join to locations:**
```sql
JOIN public.companies c ON c.id = l.company_id
-- or in LookML: sql_on: ${locations_v2.company_id} = ${companies_v2.company_id}
```

**Common fields:** `owner_id`, `channel` (acquisition source), `created_at`, `location_count`

---

### 3. `postgres.jobs`
**What it's for:** Employee records. Each "job" is one employee's role at one location. Used for employee counts, tenure, wage analysis, and manager identification.

| LookML View Name | SQL Table |
|---|---|
| `jobs` | `postgres.jobs` |

**Join to locations:**
```sql
JOIN postgres.jobs j ON j.location_id = l.location_id
-- Filter active employees: WHERE j.archived_at IS NULL
```

**Common fields:** `user_id`, `location_id`, `level` (Employee / Manager / General Manager / Owner), `wage_rate`, `hire_date`, `archived_at`

**Common pattern:** Filter `archived_at IS NULL` for active employees only.

---

### 4. `public.fact_locations_by_day`
**What it's for:** A daily snapshot table tracking whether each location was paying and what plan they were on — on a specific date. Used for historical plan/tier analysis and point-in-time revenue reporting.

| LookML View Name | SQL Table |
|---|---|
| `active_paying_history` / used in derived tables | `public.fact_locations_by_day` |

**Join to locations:**
```sql
JOIN public.fact_locations_by_day f
  ON f.location_id = l.location_id
  AND f.date = <target_date>
```

**Common fields:** `location_id`, `date`, `tier_id`, `paying` (0/1)

**Important:** Always join on both `location_id` AND `date` — this table has one row per location per day.

---

### 5. `bizops.product_location_engagement_metrics`
**What it's for:** Daily engagement booleans for every location. The source of truth for whether a location is "engaged" and which features they're actively using.

| LookML View Name | SQL Table |
|---|---|
| `engagement_metrics` | `bizops.product_location_engagement_metrics` |

**Join to locations:**
```sql
JOIN bizops.product_location_engagement_metrics em
  ON em.location_id = l.location_id
  AND em.date = <target_date>
```

**Common fields:**
- `engagement_boolean` — core engaged (time tracking or scheduling + OAM activity)
- `time_tracking_engaged_boolean`
- `scheduling_engaged_boolean`
- `time_offs_engaged_boolean` — PTO feature usage
- `hiring_engaged_boolean`
- `mobile_time_tracking_engaged_boolean`

**Important:** Always join on both `location_id` AND `date`. Use `MAX(date)` per month for month-end snapshots to avoid double-counting.

---

### 6. `public.cashout_advances`
**What it's for:** Individual Cash Out advance records. Used for Cash Out revenue, volume, and user-level analysis.

| LookML View Name | SQL Table |
|---|---|
| `cashout_advances` | `public.cashout_advances` |

**Join pattern:** This table joins on `user_id`, not `location_id`. To connect advances to locations, you need to go through the employee/user tables.

```sql
JOIN public.cashout_advances ca ON ca.user_id = <user_id>
```

**Common fields:** `user_id`, `advance_id`, `amount`, `status`, `advance_date`, `node_id`, `plaid_item_id`

---

### 7. `dbt.fin_product_monthly_revenue`
**What it's for:** Monthly revenue by company and product line. The canonical source for MRR, ARR, and retention reporting.

| LookML View Name | SQL Table |
|---|---|
| `canonical_monthly_revenue_reporting` | `dbt.fin_product_monthly_revenue` |

**Join to companies:**
```sql
JOIN dbt.fin_product_monthly_revenue r ON r.company_id = c.id
-- Grain: one row per company + revenue_stream + month
```

**Common fields:** `company_id`, `revenue_stream` (e.g. 'Core HR SaaS', 'Payroll', 'Cash Out'), `monthly_revenue`, `month_end_date`, `company_paying_year_ago`, `company_paying_30days_ago`

**Important:** This table is at the **company** level, not location level. Join to `public.companies` on `company_id` to connect to locations.

---

### 8. `ext_amplitude.amplitude_events`
**What it's for:** Raw product event tracking from Amplitude. Used for in-product funnel analysis, feature adoption, and behavioral analytics.

**Join pattern:** Joins via `user_id` or `location_id` embedded in event properties. Typically queried standalone or joined to users/locations for segmentation.

**Note:** This table is large. Always filter by `event_type` and a date range. Not commonly joined directly to the core location/company tables in Looker — typically used in standalone Amplitude analyses.

---

### 9. `postgres.shifts`
**What it's for:** Scheduled shifts. Used for scheduling analysis, hours scheduled vs. worked, and labor cost analysis.

**Join pattern:** Joins to locations via `location_id`, and to jobs/employees via `job_id` or `user_id`.

```sql
JOIN postgres.shifts s ON s.location_id = l.location_id
```

**Common fields:** `location_id`, `job_id`, `start_time`, `end_time`, `published`, `acknowledged`

---

## Common Join Patterns

### Locations + Engagement (most common)
```sql
FROM public.locations l
JOIN bizops.product_location_engagement_metrics em
  ON em.location_id = l.location_id
  AND em.date = <target_date>
WHERE l.archived_at IS NULL
```

### Locations + Companies
```sql
FROM public.locations l
JOIN public.companies c ON c.id = l.company_id
WHERE l.archived_at IS NULL
```

### Locations + Employees
```sql
FROM public.locations l
JOIN postgres.jobs j ON j.location_id = l.location_id
WHERE l.archived_at IS NULL
  AND j.archived_at IS NULL  -- active employees only
```

### Locations + Daily Plan History
```sql
FROM public.fact_locations_by_day f
JOIN public.locations l ON l.location_id = f.location_id
WHERE f.date = <target_date>
  AND l.archived_at IS NULL
```

### Companies + Revenue
```sql
FROM dbt.fin_product_monthly_revenue r
JOIN public.companies c ON c.id = r.company_id
WHERE r.revenue_stream = 'Core HR SaaS'
```

### Full Hub Pattern (Locations + Engagement + Companies + Revenue)
This pattern appears in the `customer_maps_pdt` derived table in Looker:
```sql
FROM dbt.active_paying_history_for_looker aph
LEFT JOIN public.locations l ON l.location_id = aph.location_id
LEFT JOIN bizops.product_location_engagement_metrics em
  ON em.location_id = aph.location_id AND DATE(em.date) = DATE(aph.date)
LEFT JOIN public.companies c ON c.id = l.company_id
LEFT JOIN dbt.fin_product_monthly_revenue rev
  ON rev.company_id = aph.company_id AND DATE(rev.month_end_date) = DATE(aph.date)
WHERE l.archived_at IS NULL
```

---

## Join Key Reference

| From Table | To Table | Join Key |
|---|---|---|
| `public.locations` | `public.companies` | `locations.company_id = companies.id` |
| `public.locations` | `postgres.jobs` | `locations.location_id = jobs.location_id` |
| `public.locations` | `bizops.product_location_engagement_metrics` | `location_id` + `date` |
| `public.locations` | `public.fact_locations_by_day` | `location_id` + `date` |
| `public.locations` | `postgres.shifts` | `location_id` |
| `public.companies` | `dbt.fin_product_monthly_revenue` | `company_id` |
| `postgres.jobs` | `public.cashout_advances` | `jobs.user_id = cashout_advances.user_id` |

---

## Table Selection Guide

| Question | Primary Table | Secondary Join |
|---|---|---|
| How many locations are on each plan? | `public.locations` | — |
| How many locations are engaged this month? | `bizops.product_location_engagement_metrics` | `public.locations` |
| Which features are AiO locations using? | `bizops.product_location_engagement_metrics` | `public.locations` (filter `tier_id = 4`) |
| How many employees does a location have? | `public.locations` (`total_employees`) | — |
| What was a location's plan on a specific date? | `public.fact_locations_by_day` | `public.locations` |
| What is a company's MRR? | `dbt.fin_product_monthly_revenue` | `public.companies` |
| How many active employees at a location? | `postgres.jobs` | `public.locations` |
| Cash Out advance volume by user? | `public.cashout_advances` | — |
| Shifts scheduled vs. worked? | `postgres.shifts` | `public.locations` |
