# Timetracking Specific Context


**When to use this file:** Questions about timecards, clock-in/out patterns, breaks, manager edits, payroll assistants, ACO/ACI.

**Context Source** `core_product.model.lkml` → 
Most important joins and field descriptions can be derived from the looker explore file  `timecard_metrics` in the `core_product.model.lkml` in the `pioneerworks/looker` repo.  

---

## Key Metrics 

**% of Non-EE Edits** Percentage of edits that was done by either an OAM or one of the Payroll Assistants. Used to help assess whether we are saving OAMs time through reducing manual edits.

**Payroll Assistant MAU/WAU** Counts total locations that have used a Payroll Assistant within each month. Aggregate to calendar month of last 30 days.  

**# of Timecards Created** Counts number of Timecards that were created within a given time period.

## Time Tracking Feature Engagement Definitions

#### Time Tracking Engaged
**Measures:** Active use of clock-in/clock-out functionality.
**Lookback:** 7 days
**Threshold:** 3+ timecards OR 20%+ of roster with a timecard
**Requirement:** At least one timecard must belong to an Employee (not just managers testing).
**Context:** One of two "core" engagement features. Essential for payroll, compliance, and labor cost management.

| `time_tracking_engaged_boolean` | `time_tracking_engaged_boolean_30d_ago` |
|---|---|

#### Mobile Time Tracking Engaged
**Measures:** Employees clocking in/out via the Homebase mobile app (vs. web or timeclock device).
**Lookback:** 7 days
**Threshold:** 3+ mobile timecards OR 20%+ of roster with a mobile timecard
**Context:** Mobile adoption indicates deeper product integration. Important for field workers or businesses without a fixed timeclock.

| `mobile_time_tracking_engaged_boolean` | `mobile_time_tracking_engaged_boolean_30d_ago` |
|---|---|

#### Overtime Preferences Engaged
**Measures:** Use of overtime tracking and alerting features.
**Lookback:** 7 days
**Requirements (ALL):**
- Essentials plan or higher
- Any overtime settings enabled
- Time tracking engaged
**Context:** Critical for labor cost control and compliance.

| `overtime_preferences_engaged_boolean` | `overtime_preferences_engaged_boolean_30d_ago` |
|---|---|

#### Break Preferences Engaged
**Measures:** Use of break tracking and enforcement features.
**Lookback:** 7 days
**Requirements (ALL):**
- 1+ break type enabled where at least one is mandatory
- Time tracking engaged
**Context:** Break compliance is a major legal requirement in many jurisdictions.

| `break_preferences_engaged_boolean` | `break_preferences_engaged_boolean_30d_ago` |
|---|---|

#### Geofencing Engaged
**Measures:** Use of location-based clock-in/out restrictions.
**Lookback:** 7 days
**Requirements (ALL):**
- Proximity enforcement enabled in settings
- On Essentials plan or higher
- Mobile time tracking engaged
**Context:** Premium feature requiring paid plan. Indicates sophisticated time theft prevention.

| `geofencing_engaged_boolean` | `geofencing_engaged_boolean_30d_ago` |
|---|---|
## Key Business Logic & Caveats

- **"Manager Modified"** is the broadest edit flag — covers manager added, edited, or deleted. Use this for OKR tracking on manager time savings.
- **Payroll Assistants** are features designed to help assist OAMs by saving time spent on timetracking/payroll. Currently, tiers 3, 4 and non-Clover locations have access to these features.
- **ACO (Assisted Clock Out)** a type of Payroll Assistant.  Counts only when a clock-out via ACO is either auto-approved or manager-approved. A submitted but unresolved ACO request does not count. Initial rollout on 8/16/2025.  GA on 01/16/2026
`postgres.time_tracking_timecard_change_requests.status` = 'approved' AND `postgres.time_tracking_timecard_change_requests.source` = 'assisted_clock_out'
- **ACI (Assisted Clock In)** A type of Payroll Assistant. Same logic as ACO for clock-ins. Initial rollout on 12/10/2025. GA on 02/03/2026.
`postgres.time_tracking_timecard_change_requests.status` = 'approved' AND `postgres.time_tracking_timecard_change_requests.source` = 'assisted_clock_in'
- **ACO/ACI join key:** `time_tracking_timecard_change_requests` joins to `timecards` on `timecard_uuid` (not `timecard_id`). Use `cr.timecard_uuid = tc.timecard_uuid`.
- **Getting `location_id` from timecards:** `bizops.timecards.location_id` is usually null. Always join through `postgres.jobs` to get the location: `FROM bizops.timecards t LEFT JOIN postgres.jobs j ON t.job_id = j.id` and use `j.location_id`.
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
