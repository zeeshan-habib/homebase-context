# Timetracking — Schema & Business Context


**When to use this file:** Questions about timecards, clock-in/out patterns, breaks, manager edits, payroll assistants, ACO/ACI.

**Context Source** `core_product.model.lkml` → 
Most important joins and field descriptions can be derived from the looker explore file  `timecard_metrics` in the `core_product.model.lkml` in the `pioneerworks/looker` repo.  
---

## Key Metrics 

**% of Non-EE Edits** Percentage of edits that was done by either an OAM or one of the Payroll Assistants. Used to help assess whether we are saving OAMs time through reducing manual edits.

**Payroll Assistant MAU/WAU** Counts total locations that have used a Payroll Assistant within each month. Aggregate to calendar month of last 30 days.  

## Explore Structure & Join Map

```
timecards  (base view — bizops.timecards + postgres.jobs)
  ├── timecard_clockouts      JOIN ON timecards.timecard_id = timecard_clockouts.timecard_id
  ├── timecard_clockins       JOIN ON timecards.timecard_id = timecard_clockins.timecard_id
  ├── timebreaks_enriched_with_edits  JOIN ON timecards.timecard_id = timebreaks_enriched_with_edits.timecard_id
  ├── timecard_manager_notes  JOIN ON timecards.timecard_id = timecard_manager_notes.timecard_id
  ├── engagement_metrics      JOIN ON timecards.location_id = engagement_metrics.location_id
  │                                AND engagement_metrics.date_date >= '01-01-25'
  └── locations_v2            JOIN ON timecards.location_id = locations_v2.location_id
```

## Key Business Logic & Caveats

- **"Manager Modified"** is the broadest edit flag — covers manager added, edited, or deleted. Use this for OKR tracking on manager time savings.
- **Payroll Assistants** are features designed to help assist OAMs by saving time spent on timetracking/payroll. Currently, tiers 3, 4 and non-Clover locations have access to these features.
- **ACO (Assisted Clock Out)** a type of Payroll Assistant.  Counts only when a clock-out via ACO is either auto-approved or manager-approved. A submitted but unresolved ACO request does not count. Initial rollout on 8/16/2025.  GA on 01/16/2026
- **ACI (Assisted Clock In)** A type of Payroll Assistant. Same logic as ACO for clock-ins. Initial rollout on 12/10/2025. GA on 02/03/2026.
- **`is_late_clock_out` threshold** is 10 minutes after scheduled shift end.
- **Unscheduled shifts** (`shift_unscheduled = true`) don't have a meaningful scheduled end time — be careful with late clock-out calculations on these.
- **`engagement_metrics` join** is filtered to `>= '01-01-25'` for performance. Always add a matching timecard date filter.
- **Clock-out/in method priority:** Manager actions > ACO/ACI > Normal employee actions > Auto/POS.

## Location Properties & Settings for Segmentation and Filtering


| Table | Schema | Description |
|-------|--------|-------------|
| `locations` | `public` | location attributes and properties | Join on `location_id` 
| `companies` | `public` | company attributes and properties | Join on `company_id` 
| `location_properties` | `postgres` | location settings and preferences | Join on `location_id` 
| `timesheets_settings` | `postgres` | location timetracking related settings  | Join on `location_id` 

---

## Example SQL Queries

### Manager edit rates on clock-outs
```sql
SELECT
    DATE_TRUNC('week', tc.timecard_created_at) AS week,
    COUNT(DISTINCT tc.timecard_id) AS total_timecards,
    COUNT(DISTINCT CASE WHEN co.manager_modified = 1 THEN tc.timecard_id END) AS manager_modified,
    1.0 * COUNT(DISTINCT CASE WHEN co.manager_modified = 1 THEN tc.timecard_id END)
        / NULLIF(COUNT(DISTINCT tc.timecard_id), 0) AS pct_manager_modified
FROM bizops.timecards tc
LEFT JOIN bizops.timecard_clockouts co ON tc.timecard_id = co.timecard_id
LEFT JOIN postgres.jobs j ON tc.job_id = j.id
GROUP BY 1
ORDER BY 1;
```

### Late clock-out rate by location
```sql
SELECT
    j.location_id,
    COUNT(DISTINCT tc.timecard_id) AS total_clock_outs,
    COUNT(DISTINCT CASE
        WHEN DATEDIFF(MINUTE, tc.shift_end_at, tc.timecard_end_at) >= 10
        THEN tc.timecard_id END) AS late_clock_outs,
    1.0 * COUNT(DISTINCT CASE
        WHEN DATEDIFF(MINUTE, tc.shift_end_at, tc.timecard_end_at) >= 10
        THEN tc.timecard_id END)
        / NULLIF(COUNT(DISTINCT CASE
            WHEN tc.timecard_end_at IS NOT NULL
            THEN tc.timecard_id END), 0) AS pct_late
FROM bizops.timecards tc
LEFT JOIN postgres.jobs j ON tc.job_id = j.id
WHERE tc.timecard_end_at IS NOT NULL
    AND tc.shift_end_at IS NOT NULL
GROUP BY 1;
```

### Break edit rates by timecard
```sql
SELECT
    tc.timecard_id,
    COUNT(DISTINCT tb.timebreak_id) AS total_breaks,
    COUNT(DISTINCT CASE WHEN tb.manager_modified = 1 THEN tb.timebreak_id END) AS manager_modified_breaks
FROM bizops.timecards tc
LEFT JOIN bizops.timebreaks_enriched_with_edits tb ON tc.timecard_id = tb.timecard_id
GROUP BY 1;
```

### Clock-out method breakdown
```sql
SELECT
    co.clockout_method,
    COUNT(DISTINCT co.timecard_id) AS timecard_count
FROM bizops.timecard_clockouts co
GROUP BY 1
ORDER BY 2 DESC;
```
