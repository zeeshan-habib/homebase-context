# Engagement Metrics — Definitions, Columns & SQL Examples

## Overview

This document is the **single source of truth** for Homebase's product engagement metric definitions. These metrics measure how actively customers use various Homebase features and are considered the "golden standard."

**When to use this file:** Any question about general engagement, feature adoption, active locations/companies, or DAU/WAU/MAU.

---

## Primary Tables

| Table | Schema | Grain | Description |
|-------|--------|-------|-------------|
| `product_location_engagement_metrics` | `bizops` | One row per location per date | Location-level engagement booleans |
| `product_company_engagement_metrics` | `bizops` | One row per company per date | Company-level engagement booleans (HR docs, messaging) |

### Join Pattern

```sql
-- Location metrics → Company metrics (via locations)
FROM bizops.product_location_engagement_metrics loc
JOIN public.locations l ON l.location_id = loc.location_id
JOIN bizops.product_company_engagement_metrics co
  ON co.company_id = l.company_id
  AND co.date = loc.date
```

---

## Core Engagement Definition

A **location is engaged** if it meets **ALL** of these criteria:
1. **Core product usage:** Either time tracking engaged OR scheduling engaged (past 7 days)
2. **Management activity:** Any Owner, Admin, or Manager (OAM) activity (past 30 days)

This ensures we measure businesses actively using Homebase's core value proposition AND with active management oversight.

| Column | Table | Description |
|--------|-------|-------------|
| `engagement_boolean` | `bizops.product_location_engagement_metrics` | 1 if location is engaged on this date |
| `engagement_boolean_30d_ago` | `bizops.product_location_engagement_metrics` | 1 if location was engaged 30 days prior |

---

## Feature Engagement Definitions

### Location-Level Features

#### Time Tracking Engaged
**Measures:** Active use of clock-in/clock-out functionality.
**Lookback:** 7 days
**Threshold:** 3+ timecards OR 20%+ of roster with a timecard
**Requirement:** At least one timecard must belong to an Employee (not just managers testing).
**Context:** One of two "core" engagement features. Essential for payroll, compliance, and labor cost management.

| `time_tracking_engaged_boolean` | `time_tracking_engaged_boolean_30d_ago` |
|---|---|

#### Scheduling Engaged
**Measures:** Active use of shift scheduling.
**Lookback:** 7 days
**Threshold:** 3+ scheduled shifts OR 20%+ of roster with a scheduled shift
**Requirement:** At least one shift must belong to an Employee.
**Context:** One of two "core" engagement features. Critical for workforce planning and communication.

| `scheduling_engaged_boolean` | `scheduling_engaged_boolean_30d_ago` |
|---|---|

#### Mobile Time Tracking Engaged
**Measures:** Employees clocking in/out via the Homebase mobile app (vs. web or timeclock device).
**Lookback:** 7 days
**Threshold:** 3+ mobile timecards OR 20%+ of roster with a mobile timecard
**Context:** Mobile adoption indicates deeper product integration. Important for field workers or businesses without a fixed timeclock.

| `mobile_time_tracking_engaged_boolean` | `mobile_time_tracking_engaged_boolean_30d_ago` |
|---|---|

#### Shift Trades Engaged
**Measures:** Use of shift swap/trade functionality between employees.
**Lookback:** 7 days
**Threshold:** 2+ shift trades OR 10%+ of roster with a shift trade
**Context:** Lower threshold — shift trades are situational. Indicates employee self-service adoption.

| `shift_trades_engaged_boolean` | `shift_trades_engaged_boolean_30d_ago` |
|---|---|

#### Time Offs Engaged
**Measures:** Use of time-off request system.
**Lookback:** 7 days
**Threshold:** 2+ time off requests OR 10%+ of roster with a time off request
**Context:** Situational but indicates mature product usage. Centralizes PTO management.

| `time_offs_engaged_boolean` | `time_offs_engaged_boolean_30d_ago` |
|---|---|

#### Hiring Engaged
**Measures:** Active use of hiring and applicant tracking features.
**Lookback:** 30 days (longer because hiring is episodic)
**Threshold:** 10+ hiring events (job posts, applicant views, etc.)
**Context:** Important expansion feature beyond core scheduling/time tracking.

| `hiring_engaged_boolean` | `hiring_engaged_boolean_30d_ago` |
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

#### Manager Log Engaged
**Measures:** Use of manager communication/logging feature.
**Lookback:** 7 days
**Threshold:** 2+ manager log posts OR 20%+ of managers have posted a log
**Context:** Helps with shift handoffs and operational continuity.

| `manager_log_engaged_boolean` | `manager_log_engaged_boolean_30d_ago` |
|---|---|

#### Department Management Engaged
**Measures:** Use of department-based scheduling and permissions.
**Lookback:** 8 days
**Requirements (ONE path):**
- **Path 1:** Plus plan or higher AND department scheduling pageview in past 8 days
- **Path 2:** Department management permissions enabled for managers AND has at least one manager AND scheduling engaged
**Context:** Indicates larger, more complex businesses with specialized scheduling needs.

| `department_management_engaged_boolean` | `department_management_engaged_boolean_30d_ago` |
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

#### Shift Notes Engaged
**Measures:** Use of shift-level notes and instructions.
**Lookback:** 7 days
**Requirements (ALL):**
- At least one shift note attached to a shift scheduled in the last 7 days
- Scheduling engaged
**Context:** Indicates scheduling is used for more than just time assignment.

| `shift_notes_engaged_boolean` | `shift_notes_engaged_boolean_30d_ago` |
|---|---|

#### OAM Activity
**Measures:** Any Owner, Admin, or Manager activity in the product.
**Lookback:** 30 days
**Threshold:** Any UX event activity
**Context:** Component of the core engagement definition. Ensures active management oversight.

| `oam_activity_boolean` | `oam_activity_boolean_30d_ago` |
|---|---|

---

### Company-Level Features

> When a company is engaged with these features, **ALL** of its locations are considered engaged.

#### HR Docs Engaged
**Measures:** Use of digital onboarding and document management.
**Threshold:** Any of the three most recently added employees have an associated onboarding document.
**Context:** Focuses on recent hires to measure ongoing usage, not historical adoption.

| `hrdocs_engaged_boolean` | `hrdocs_engaged_boolean_30d_ago` |
|---|---|

#### Messaging Engaged
**Measures:** Use of team communication features.
**Lookback:** 7 days
**Threshold:** 10+ messages sent OR 20%+ of roster with a message sent
**Context:** Indicates Homebase is becoming the central hub for workforce management.

| `messaging_engaged_boolean` | `messaging_engaged_boolean_30d_ago` |
|---|---|

---

## Quick Reference: All Columns

### Location-Level (`bizops.product_location_engagement_metrics`)

| Feature | Current Column | 30 Days Ago Column | Lookback |
|---------|----------------|-------------------|----------|
| Core Engaged | `engagement_boolean` | `engagement_boolean_30d_ago` | 7d + 30d |
| Time Tracking | `time_tracking_engaged_boolean` | `time_tracking_engaged_boolean_30d_ago` | 7 days |
| Scheduling | `scheduling_engaged_boolean` | `scheduling_engaged_boolean_30d_ago` | 7 days |
| Mobile Time Tracking | `mobile_time_tracking_engaged_boolean` | `mobile_time_tracking_engaged_boolean_30d_ago` | 7 days |
| Shift Trades | `shift_trades_engaged_boolean` | `shift_trades_engaged_boolean_30d_ago` | 7 days |
| Time Offs | `time_offs_engaged_boolean` | `time_offs_engaged_boolean_30d_ago` | 7 days |
| Hiring | `hiring_engaged_boolean` | `hiring_engaged_boolean_30d_ago` | 30 days |
| Geofencing | `geofencing_engaged_boolean` | `geofencing_engaged_boolean_30d_ago` | 7 days |
| Manager Log | `manager_log_engaged_boolean` | `manager_log_engaged_boolean_30d_ago` | 7 days |
| Dept Management | `department_management_engaged_boolean` | `department_management_engaged_boolean_30d_ago` | 8 days |
| Overtime Prefs | `overtime_preferences_engaged_boolean` | `overtime_preferences_engaged_boolean_30d_ago` | 7 days |
| Break Prefs | `break_preferences_engaged_boolean` | `break_preferences_engaged_boolean_30d_ago` | 7 days |
| Shift Notes | `shift_notes_engaged_boolean` | `shift_notes_engaged_boolean_30d_ago` | 7 days |
| OAM Activity | `oam_activity_boolean` | `oam_activity_boolean_30d_ago` | 30 days |

### Company-Level (`bizops.product_company_engagement_metrics`)

| Feature | Current Column | 30 Days Ago Column | Lookback |
|---------|----------------|-------------------|----------|
| HR Docs | `hrdocs_engaged_boolean` | `hrdocs_engaged_boolean_30d_ago` | Recent hires |
| Messaging | `messaging_engaged_boolean` | `messaging_engaged_boolean_30d_ago` | 7 days |

---

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
    COUNT(DISTINCT CASE WHEN engagement_boolean THEN location_id END) AS engaged_locations
FROM bizops.product_location_engagement_metrics
WHERE date = '2024-01-15'
GROUP BY date;
```

### Month-over-month engagement change
```sql
SELECT
    DATE_TRUNC('month', date) AS month,
    COUNT(DISTINCT CASE WHEN engagement_boolean THEN location_id END) AS engaged_locations,
    COUNT(DISTINCT CASE WHEN engagement_boolean_30d_ago THEN location_id END) AS engaged_locations_30d_ago
FROM bizops.product_location_engagement_metrics
GROUP BY 1
ORDER BY 1;
```

### Feature adoption across engaged locations
```sql
SELECT
    loc.date,
    COUNT(DISTINCT CASE WHEN loc.engagement_boolean THEN loc.location_id END) AS engaged_locs,
    COUNT(DISTINCT CASE WHEN loc.time_tracking_engaged_boolean THEN loc.location_id END) AS tt_engaged,
    COUNT(DISTINCT CASE WHEN loc.scheduling_engaged_boolean THEN loc.location_id END) AS sched_engaged,
    COUNT(DISTINCT CASE WHEN co.messaging_engaged_boolean THEN loc.location_id END) AS msg_engaged
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
    COUNT(DISTINCT CASE WHEN loc.engagement_boolean THEN l.company_id END) AS engaged_companies
FROM bizops.product_location_engagement_metrics loc
JOIN public.locations l ON l.location_id = loc.location_id
WHERE loc.date = '2024-01-15'
GROUP BY loc.date;
```
