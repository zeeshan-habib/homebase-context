# Engagement Metrics — Querying Details & SQL Examples

## Overview

This document provides additional guidance on querying engagement metrics.  Refer to this when calculating engagement metrics.

---

## Primary Tables

| Table | Schema | Catalog | Grain | Description |
|-------|--------|---------|-------|-------------|
| `product_location_engagement_metrics` | `bizops` | prod_redshift_replica | One row per location per date | Location-level engagement booleans |
| `product_company_engagement_metrics` | `bizops` | prod_redshift_replica | One row per company per date | Company-level engagement booleans |

### Join Pattern

```sql
-- Location metrics → Company metrics (via locations)
FROM bizops.product_location_engagement_metrics loc
JOIN public.locations l ON l.location_id = loc.location_id
JOIN bizops.product_company_engagement_metrics co
  ON co.company_id = l.company_id
  AND co.date = loc.date
```

### Boolean columns are integers, not booleans
Despite the name, all `*_boolean` columns in these tables are stored as integers (`1` = true, `0` = false), not native booleans. Always compare with `= 1` instead of using bare column references.
- **Correct:** `CASE WHEN engagement_boolean = 1 THEN location_id END`
- **Incorrect:** `CASE WHEN engagement_boolean THEN location_id END`

The bare-column style may work in Redshift/Looker but will not behave correctly in Databricks.

---

## Core Engagement Definition

A **location is engaged** if it meets **ALL** of these criteria:
1. **Core product usage:** Either time tracking engaged OR scheduling engaged (past 7 days)
2. **Management activity:** Any Owner, Admin, or Manager (OAM) activity (past 30 days)

This ensures we measure businesses actively using Homebase's core value proposition AND with active management oversight.

## Time Comparison: "On Day" vs "30d Ago"

Every engagement metric has two versions:
- **On Day** (`*_boolean`): Current engagement status as of the reporting date
- **30d Ago** (`*_boolean_30d_ago`): Engagement status 30 days prior to the reporting date

This enables month-over-month trend analysis, cohort tracking, and identifying engagement changes over time.

---

## Common Analysis Patterns

1. **Feature adoption funnel:** What % of time tracking engaged locations are also scheduling engaged? messaging engaged?
2. **Engagement trends:** Compare current boolean vs 30d_ago boolean to measure growth or decline
3. **Premium feature conversion:** Of geofencing/department management engaged locations, what's the plan distribution?
4. **Core vs expansion engagement:** Ratio of locations engaged with core features vs. expansion features (hiring, messaging, HR docs)

---

## Example SQL Queries

### Count engaged locations on a specific date
```sql
SELECT
    date,
    COUNT(DISTINCT CASE WHEN engagement_boolean = 1 THEN location_id END) AS engaged_locations
FROM bizops.product_location_engagement_metrics
WHERE date = '2024-01-15'
GROUP BY date;
```

### Month-over-month engagement change
```sql
SELECT
    DATE_TRUNC('month', date) AS month,
    COUNT(DISTINCT CASE WHEN engagement_boolean = 1 THEN location_id END) AS engaged_locations,
    COUNT(DISTINCT CASE WHEN engagement_boolean_30d_ago = 1 THEN location_id END) AS engaged_locations_30d_ago
FROM bizops.product_location_engagement_metrics
GROUP BY 1
ORDER BY 1;
```

### Feature adoption across engaged locations
```sql
SELECT
    loc.date,
    COUNT(DISTINCT CASE WHEN loc.engagement_boolean = 1 THEN loc.location_id END) AS engaged_locs,
    COUNT(DISTINCT CASE WHEN loc.time_tracking_engaged_boolean = 1 THEN loc.location_id END) AS tt_engaged,
    COUNT(DISTINCT CASE WHEN loc.scheduling_engaged_boolean = 1 THEN loc.location_id END) AS sched_engaged,
    COUNT(DISTINCT CASE WHEN co.messaging_engaged_boolean = 1 THEN loc.location_id END) AS msg_engaged
FROM bizops.product_location_engagement_metrics loc
JOIN public.locations l ON l.location_id = loc.location_id
LEFT JOIN bizops.product_company_engagement_metrics co
    ON co.company_id = l.company_id AND co.date = loc.date
WHERE loc.date = '2024-01-15'
GROUP BY loc.date;
```

### Company-level engagement counts
```sql
SELECT
    loc.date,
    COUNT(DISTINCT CASE WHEN loc.engagement_boolean = 1 THEN l.company_id END) AS engaged_companies
FROM bizops.product_location_engagement_metrics loc
JOIN public.locations l ON l.location_id = loc.location_id
WHERE loc.date = '2024-01-15'
GROUP BY loc.date;
```
