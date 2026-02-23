# Homebase Organizational Context

## Business Overview

B2B workforce management SaaS with paid and non-paid customers. Additional features may be added through various pricing models. Customers are business owners and end users will include managers and employees.

---

## Key Entities

### Location
The **primary unit of engagement measurement**. A location represents a single physical business site (e.g., one restaurant, one retail store). Most engagement metrics are calculated at the location level first, then rolled up to the company level. *When someone refers to 'users', they most likely are asking about locations, best to clarify if unclear.

### Company
A business entity that may own one or more locations. A company is considered "engaged" with a feature if **any** of its locations are engaged with that feature.

### Users 
Any individual who uses the Homebase product, could be a a business Owner, a Manager/General Manager or an employee at a business.

### Jobs
The specific relationship that describes the employee's role at the business.


---

## Core Engagement & Active Metric Definitions

The following metrics are considered 'golden' standard and measure how actively customers use Homebase features. Use these definitions first regarding questions around overall and feature specific engagement.

### Overall Engagement
Whether businesses are actively using Homebase's core value proposition (scheduling and/or time tracking) AND have active management oversight.
A **location is engaged** if it meets ALL of these criteria:
1. **Core product usage**: Either time tracking engaged OR scheduling engaged in the past 7 days
2. **Management activity**: Any owner, admin, or manager (OAM) activity in the past 30 days

| Column | Table | Description |
|--------|-------|-------------|
| `engagement_boolean` | `bizops.product_location_engagement_metrics` | 1 if location is engaged on this date |
| `engagement_boolean_30d_ago` | `bizops.product_location_engagement_metrics` | 1 if location was engaged 30 days prior |

### DAU / WAU / MAU 
Common questions around feature usage include counting distinct 'active' users on a daily, weekly or monthly basis.  These relate more to specific features.

### Team App Paying 
A company / location which are on one of our Team App paying plans (Essentials = 2, Plus = 3, AiO =  4).

| Column | Table | Description |
|--------|-------|-------------|
| `tier` | `public.locations` | 2, 3 or 4 if CURRENTLY paying |
| `tier` | `dbt.active_paying_history_for_looker` | 2, 3 or 4 if paying on specific day via snapshot |

### Payroll Paying
A company / location which are paying for Payroll. Monthly subscription model with additional fees per employee payroll run.
More info on calculations provided in Payroll Domain Specific Files.

### Payroll Active 
A company / location is considered Payroll Active if they ran payroll within a given time period, usually within a month or 30 day lookback window. 
More info on calculations provided in Payroll Domain Specific Files.

### 2D7
A company / location on two different days, within a continuous 7 day window, with at least one employee activity (like log in) on each day. Usually measured either on the very first 7 days after signup, or any given 7 day interval.  Location rolls up to company. 
| Column | Table | Description |
|--------|-------|-------------|
| `twod7_active_today_location` | `dbt.active_paying_history_for_looker` |  `true` if active on day via snapshot  |
| `signup_2d7` | `public.companies` | `true` if 2d7 active from signup |


### 1D1 
A company / location with activity (A new company/user inviting an employee and the employee logs in) within first 24 hr of signup. Location rolls up to company. 

| Column | Table | Description |
|--------|-------|-------------|
| `signup_1d1` | `public.companies` | `true` if 1d1 active at day of signup |


### 2d30
A company / location on two different days, within a continuous 30 day window, with at least one employee activity (like log in) on each day. Location rolls up to company.  

| Column | Table | Description |
|--------|-------|-------------|
| `two_d_thirty_active_this_month_location` | `dbt.active_paying_history_for_looker` |  `true` if active one day via snapshot  |
| `signup_2d30` | `public.companies` | `true` if 2d30 active from signup |

---

## Primary Tables

| Table | Schema | Description |
|-------|--------|-------------|
| `product_location_engagement_metrics` | `bizops` | Primary source for location-level engagement booleans. One row per location per date. |
| `product_company_engagement_metrics` | `bizops` | Company-level metrics (HR docs, messaging). One row per company per date. |
| `locations` | `public`| Location master data; used to join locations to their parent company. |
| `companies` | `public`| Company master data; locations join up to their parent company |

### Table Relationships

```
bizops.product_location_engagement_metrics (location_id, date)
    ↓
    JOIN postgres.locations ON locations.id = location_metrics.location_id
    ↓
    JOIN bizops.product_company_engagement_metrics 
        ON company_metrics.company_id = locations.company_id
        AND company_metrics.date = location_metrics.date
```

### Key Identifiers

| Column | Table | Description |
|--------|-------|-------------|
| `location_id` | `product_location_engagement_metrics` | Unique identifier for a location |
| `company_id` | `product_company_engagement_metrics`, `locations` | Unique identifier for a company |
| `date` | Both metrics tables | Reporting date for the engagement snapshot |

---


## Additional Feature Engagement Definitions

### Time Tracking Engaged
**What it measures**: Active use of Homebase's clock-in/clock-out functionality.

**Threshold**: A location qualifies if in the past 7 days they have:
- 3+ timecards, OR
- 20%+ of roster with a timecard

**Additional requirement**: At least one timecard must belong to an Employee (not just managers testing the system).

**Business context**: This is one of two "core" engagement features. Time tracking is essential for payroll, compliance, and labor cost management.

| Column | Table |
|--------|-------|
| `time_tracking_engaged_boolean` | `bizops.product_location_engagement_metrics` |
| `time_tracking_engaged_boolean_30d_ago` | `bizops.product_location_engagement_metrics` |

---

### Scheduling Engaged
**What it measures**: Active use of Homebase's shift scheduling functionality.

**Threshold**: A location qualifies if in the past 7 days they have:
- 3+ scheduled shifts, OR
- 20%+ of roster with a scheduled shift

**Additional requirement**: At least one shift must belong to an Employee.

**Business context**: This is one of two "core" engagement features. Scheduling is critical for workforce planning and communication.

| Column | Table |
|--------|-------|
| `scheduling_engaged_boolean` | `bizops.product_location_engagement_metrics` |
| `scheduling_engaged_boolean_30d_ago` | `bizops.product_location_engagement_metrics` |

---

### Mobile Time Tracking Engaged
**What it measures**: Employees clocking in/out via the Homebase mobile app (vs. web or timeclock device).

**Threshold**: A location qualifies if in the past 7 days they have:
- 3+ mobile timecards, OR
- 20%+ of roster with a mobile timecard

**Business context**: Mobile adoption indicates deeper product integration into daily workflows. Important for businesses with employees who work in the field or don't have access to a fixed timeclock.

| Column | Table |
|--------|-------|
| `mobile_time_tracking_engaged_boolean` | `bizops.product_location_engagement_metrics` |
| `mobile_time_tracking_engaged_boolean_30d_ago` | `bizops.product_location_engagement_metrics` |

---

### Shift Trades Engaged
**What it measures**: Use of Homebase's shift swap/trade functionality between employees.

**Threshold**: A location qualifies if in the past 7 days they have:
- 2+ shift trades, OR
- 10%+ of roster with a shift trade

**Business context**: Lower threshold than core features because shift trades are situational. Indicates employee self-service adoption and reduces manager workload.

| Column | Table |
|--------|-------|
| `shift_trades_engaged_boolean` | `bizops.product_location_engagement_metrics` |
| `shift_trades_engaged_boolean_30d_ago` | `bizops.product_location_engagement_metrics` |

---

### Time Offs Engaged
**What it measures**: Use of Homebase's time-off request system.

**Threshold**: A location qualifies if in the past 7 days they have:
- 2+ time off requests, OR
- 10%+ of roster with a time off request

**Business context**: Similar to shift trades—situational but indicates mature product usage. Centralizes PTO management and creates audit trail.

| Column | Table |
|--------|-------|
| `time_offs_engaged_boolean` | `bizops.product_location_engagement_metrics` |
| `time_offs_engaged_boolean_30d_ago` | `bizops.product_location_engagement_metrics` |

---

### Hiring Engaged
**What it measures**: Active use of Homebase's hiring and applicant tracking features.

**Threshold**: A location qualifies if in the past 30 days they have:
- 10+ hiring events (job posts, applicant views, etc.)

**Business context**: Longer lookback window (30 days vs 7 days) because hiring is episodic. Important expansion feature beyond core scheduling/time tracking.

| Column | Table |
|--------|-------|
| `hiring_engaged_boolean` | `bizops.product_location_engagement_metrics` |
| `hiring_engaged_boolean_30d_ago` | `bizops.product_location_engagement_metrics` |

---

### HR Docs Engaged
**What it measures**: Use of Homebase's digital onboarding and document management.

**Threshold**: A **company** qualifies if any of their three most recently added employees have an associated onboarding document.

**Scope note**: This is a **company-level metric**. When a company is engaged, ALL their locations are considered engaged.

**Business context**: Indicates adoption of HR workflow features. Focuses on recent hires to measure ongoing usage, not historical adoption.

| Column | Table |
|--------|-------|
| `hrdocs_engaged_boolean` | `bizops.product_company_engagement_metrics` |
| `hrdocs_engaged_boolean_30d_ago` | `bizops.product_company_engagement_metrics` |

---

### Messaging Engaged
**What it measures**: Use of Homebase's team communication features.

**Threshold**: A **company** qualifies if in the past 7 days they have:
- 10+ messages sent, OR
- 20%+ of roster with a message sent

**Scope note**: This is a **company-level metric**. When a company is engaged, ALL their locations are considered engaged.

**Business context**: Team communication indicates Homebase is becoming the central hub for workforce management, not just a scheduling tool.

| Column | Table |
|--------|-------|
| `messaging_engaged_boolean` | `bizops.product_company_engagement_metrics` |
| `messaging_engaged_boolean_30d_ago` | `bizops.product_company_engagement_metrics` |

---

### Geofencing Engaged
**What it measures**: Use of location-based clock-in/out restrictions.

**Requirements** (ALL must be met):
- Proximity enforcement enabled in settings
- On Essentials plan or higher
- Mobile time tracking engaged

**Business context**: Premium feature requiring paid plan. Indicates sophisticated time theft prevention and compliance needs.

| Column | Table |
|--------|-------|
| `geofencing_engaged_boolean` | `bizops.product_location_engagement_metrics` |
| `geofencing_engaged_boolean_30d_ago` | `bizops.product_location_engagement_metrics` |

---

### Manager Log Engaged
**What it measures**: Use of Homebase's manager communication/logging feature.

**Threshold**: A location qualifies if in the past 7 days they have:
- 2+ manager log posts, OR
- 20%+ of managers have posted a log

**Business context**: Manager logs help with shift handoffs and operational continuity. Indicates management-level adoption beyond basic scheduling.

| Column | Table |
|--------|-------|
| `manager_log_engaged_boolean` | `bizops.product_location_engagement_metrics` |
| `manager_log_engaged_boolean_30d_ago` | `bizops.product_location_engagement_metrics` |

---

### Department Management Engaged
**What it measures**: Use of department-based scheduling and permissions.

**Requirements** (ONE path must be met):
- **Path 1**: Plus plan or higher AND department scheduling pageview in past 8 days
- **Path 2**: Department management permissions enabled for managers AND has at least one manager AND scheduling engaged

**Business context**: Multi-department management indicates larger, more complex businesses with specialized scheduling needs.

| Column | Table |
|--------|-------|
| `department_management_engaged_boolean` | `bizops.product_location_engagement_metrics` |
| `department_management_engaged_boolean_30d_ago` | `bizops.product_location_engagement_metrics` |

---

### Overtime Preferences Engaged
**What it measures**: Use of overtime tracking and alerting features.

**Requirements** (ALL must be met):
- Essentials plan or higher
- Any overtime settings enabled
- Time tracking engaged

**Business context**: Overtime management is critical for labor cost control and compliance. Indicates mature time tracking usage.

| Column | Table |
|--------|-------|
| `overtime_preferences_engaged_boolean` | `bizops.product_location_engagement_metrics` |
| `overtime_preferences_engaged_boolean_30d_ago` | `bizops.product_location_engagement_metrics` |

---

### Break Preferences Engaged
**What it measures**: Use of break tracking and enforcement features.

**Requirements** (ALL must be met):
- 1+ break type enabled where at least one is mandatory
- Time tracking engaged

**Business context**: Break compliance is a major legal requirement in many jurisdictions. Indicates businesses using Homebase for compliance management.

| Column | Table |
|--------|-------|
| `break_preferences_engaged_boolean` | `bizops.product_location_engagement_metrics` |
| `break_preferences_engaged_boolean_30d_ago` | `bizops.product_location_engagement_metrics` |

---

### Shift Notes Engaged
**What it measures**: Use of shift-level notes and instructions.

**Requirements** (ALL must be met):
- At least one shift note attached to a shift scheduled in the last 7 days
- Scheduling engaged

**Business context**: Shift notes indicate detailed operational communication. Shows scheduling is being used for more than just time assignment.

| Column | Table |
|--------|-------|
| `shift_notes_engaged_boolean` | `bizops.product_location_engagement_metrics` |
| `shift_notes_engaged_boolean_30d_ago` | `bizops.product_location_engagement_metrics` |

---

### OAM Activity
**What it measures**: Any Owner, Admin, or Manager activity in the product.

**Threshold**: Any UX event activity in the past 30 days.

**Business context**: This is a component of the core engagement definition. Ensures the business has active management oversight, not just employee self-service usage.

| Column | Table |
|--------|-------|
| `oam_activity_boolean` | `bizops.product_location_engagement_metrics` |
| `oam_activity_boolean_30d_ago` | `bizops.product_location_engagement_metrics` |

---

## Quick Reference: All Columns

### Location-Level Metrics
**Table**: `bizops.product_location_engagement_metrics`

| Feature | Current Column | 30 Days Ago Column | Lookback Window |
|---------|----------------|-------------------|-----------------|
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

### Company-Level Metrics
**Table**: `bizops.product_company_engagement_metrics`

| Feature | Current Column | 30 Days Ago Column | Lookback Window |
|---------|----------------|-------------------|-----------------|
| HR Docs | `hrdocs_engaged_boolean` | `hrdocs_engaged_boolean_30d_ago` | Recent hires |
| Messaging | `messaging_engaged_boolean` | `messaging_engaged_boolean_30d_ago` | 7 days |

---
## General Rules 

2. Default to last 30 days for time ranges unless otherwise specified
3. Exclude test locations
4. Exclude internal Homebase employees where `email` contains "@joinhomebase.com"

---
## Common Disambiguation 

**Handling Missing Context** Prompts may refer to definitions/logic that is not defined in any of the context files.  In the event that happens, ask for clarity and go as far as list out out possible relevant context.

**Engaged vs Active** If prompt/question is abstract when referencing utilization of our product, ask clarifying questions on to determine if they referring already defined engagement metrics, active users or something else entirely.  Include the definition that is being used in response to help clarify on the source of truth.

**Entities**  If prompt/question is abstract when referencing 'users', ask for clarification on whether to reference locations, companies, Owners, General Managers, Managers, employees, etc to help inform which entity they wish to conduct analysis on. It is usually safe to assume they are looking at locations, but make sure to specify if making that assumption.

---
## Common Analysis Patterns

1. **Feature adoption funnel**: What % of time tracking engaged locations are also scheduling engaged? messaging engaged?

2. **Engagement trends**: Compare current boolean vs 30d_ago boolean to measure growth or decline

3. **Premium feature conversion**: Of geofencing/department management engaged locations, what's the plan distribution?

4. **Core vs expansion engagement**: Ratio of locations engaged with core features vs. expansion features (hiring, messaging, HR docs)

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
    date,
    COUNT(DISTINCT CASE WHEN engagement_boolean THEN location_id END) AS engaged_locs,
    COUNT(DISTINCT CASE WHEN time_tracking_engaged_boolean THEN location_id END) AS tt_engaged_locs,
    COUNT(DISTINCT CASE WHEN scheduling_engaged_boolean THEN location_id END) AS sched_engaged_locs,
    COUNT(DISTINCT CASE WHEN messaging_engaged_boolean THEN location_id END) AS msg_engaged_locs
FROM bizops.product_location_engagement_metrics loc
LEFT JOIN postgres.locations l ON l.id = loc.location_id
LEFT JOIN bizops.product_company_engagement_metrics co 
    ON co.company_id = l.company_id AND co.date = loc.date
WHERE loc.date = '2024-01-15'
GROUP BY date;
```

### Company-level engagement counts
```sql
SELECT 
    loc.date,
    COUNT(DISTINCT CASE WHEN loc.engagement_boolean THEN l.company_id END) AS engaged_companies
FROM bizops.product_location_engagement_metrics loc
JOIN postgres.locations l ON l.id = loc.location_id
WHERE loc.date = '2024-01-15'
GROUP BY loc.date;
```
