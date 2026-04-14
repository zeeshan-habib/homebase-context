# HRM — Data Field Guide

Specific definitions, data boundaries, and schema pointers for HRM data.
For product context, see `domains/hrm/`.

---

## Key Metrics

| Metric | Column / Source | Description |
|--------|----------------|-------------|
| NHP Completion Rate (D7) | Custom calc from `postgres.employee_onboarding_packets` | % of team members sent an NHP who complete it within 7 days. Current avg: ~52%. H1 2026 target: 70%+. |
| NHP Start Rate | Custom calc from `postgres.employee_onboarding_packets` | % of sent NHPs where the recipient opens and begins at least one document. Current avg: ~66%. |
| Median Hours to NHP Completion | Custom calc from `postgres.employee_onboarding_packets` | Median hours between NHP send and completion. Regressed from ~6h (Mar 2025) to ~28h (Dec 2025). |
| Onboarding Request Open Rate | Custom calc from `postgres.employee_onboarding_packets` | % of NHP invites opened by the recipient. Currently ~76%. H1 2026 target: 90%+. |
| Invite → Login Rate (D7) | Custom calc from `postgres.jobs` | % of invited Employees who log in within 7 days. Avg ~77%. Currently at Job level — migrating to Team Member level. H1 2026 target: 87%+. |
| % of New Hires with NHP | Custom calc from `postgres.employee_onboarding_packets` + `postgres.jobs` | % of all new jobs at active companies that receive structured onboarding. Currently <10%. H1 2026 target: 25%. |
| NHP Eligible Company Usage | Custom calc from `postgres.employee_onboarding_packets` | % of NHP-eligible companies that sent at least 1 packet in the month. Currently ~10–11%. |
| % New Team Members with First Mobile Login | Custom calc from `postgres.jobs` | % of new team members at non-Clover locations who worked at least 1 shift and completed a first mobile login. |
| 6-Month Revenue Retention | Revenue tables | Current revenue / revenue from 6 months ago for companies that were revenue-generating 6 months ago. Excludes Cash Out. HRM's primary business outcome metric. |
| HR Pro Subscribed | Company subscription data | % of companies with an active HR Pro (Mineral) subscription. No in-product usage visibility currently exists. |

---

## HRM Feature Engagement Definitions

#### HR Docs Engaged
**Measures:** Active use of digital onboarding and document management.
**Grain:** Company-level — propagates to all locations of the company
**Threshold:** Any of the 3 most recently added employees have an associated onboarding document
**Context:** Measures ongoing usage, not one-time historical adoption. Join via `public.locations` on `company_id` to use alongside location-level booleans.

| `hrdocs_engaged_boolean` | `hrdocs_engaged_boolean_30d_ago` |
|---|---|

Source: `bizops.product_company_engagement_metrics`

#### Time Offs Engaged
**Measures:** Active use of the time-off request and approval workflow.
**Lookback:** 7 days
**Threshold:** 2+ time off requests OR 10%+ of roster with a time off request
**Context:** ~40% of active companies by monthly ad-hoc measure.

| `time_offs_engaged_boolean` | `time_offs_engaged_boolean_30d_ago` |
|---|---|

Source: `bizops.product_location_engagement_metrics`

#### Manager Log Engaged
**Measures:** Use of Manager Log to capture performance signals and institutional knowledge.
**Lookback:** 7 days
**Threshold:** 2+ manager log posts OR 20%+ of managers have posted
**Context:** Foundation for HRM's H2 performance layer. Currently ~0.6% of active companies.

| `manager_log_engaged_boolean` | `manager_log_engaged_boolean_30d_ago` |
|---|---|

Source: `bizops.product_location_engagement_metrics`

#### Department Management Engaged
**Measures:** Use of departments for scheduling organization and permissions.
**Lookback:** 8 days
**Requirements (ONE path):**
- **Path 1:** Plus plan or higher AND department scheduling pageview in past 8 days
- **Path 2:** Department management permissions enabled AND at least one manager AND scheduling engaged
**Context:** ~20% of active companies by monthly ad-hoc measure.

| `department_management_engaged_boolean` | `department_management_engaged_boolean_30d_ago` |
|---|---|

Source: `bizops.product_location_engagement_metrics`

---

## Key Tables

| Table | What it's for | Join key |
|---|---|---|
| `prod_redshift_replica.bizops.product_company_engagement_metrics` | HR Docs and Messaging engagement booleans (company-level) | `company_id` |
| `prod_redshift_replica.bizops.product_location_engagement_metrics` | Time Offs, Manager Log, Departments engagement booleans | `location_id` |
| `prod_redshift_replica.postgres.employee_onboarding_packets` | NHP records — sent, started, completed states and timestamps | `id` |
| `prod_redshift_replica.postgres.time_offs` | Time-off requests and approvals | `id` |
| `prod_redshift_replica.postgres.employee_onboarding_packets` | Compliance and custom documents attached to team members | `id` |
| `prod_redshift_replica.postgres.jobs` | Employee-location relationships; role, pay rate, level | `location_id` |
| `prod_redshift_replica.public.locations` | Location attributes | `location_id` |
| `prod_redshift_replica.public.companies` | Company attributes | `company_id` |

---

## Disambiguation

| If you see… | Use this | Not this |
|---|---|---|
| HR Docs engagement | `hrdocs_engaged_boolean = 1` in `bizops.product_company_engagement_metrics` | Location-level booleans (HR Docs is company-scoped) |
| NHP completion rate | Custom query on `postgres.employee_onboarding_packets` | `hrdocs_engaged_boolean` (different threshold and definition) |
| "Active" in HRM context | `engagement_boolean = 1` in `bizops.product_location_engagement_metrics` | `active_now`, `is_active` flags |
| NHP grain | Team Member (user + company) | Job (user + location) |
| Time Offs / Manager Log engagement | Location-level booleans in `product_location_engagement_metrics` | Company-level table (these features are location-scoped) |

---

## Example SQL Queries

### NHP completion rate (7-day time bound) by month
```sql
SELECT
    DATE_TRUNC('month', eop.sent_at) AS month,
    COUNT(DISTINCT eop.id) AS packets_sent,
    COUNT(DISTINCT CASE
        WHEN eop.completed_at IS NOT NULL
         AND DATEDIFF(HOUR, eop.sent_at, eop.completed_at) <= 168
        THEN eop.id END) AS completed_d7,
    1.0 * COUNT(DISTINCT CASE
        WHEN eop.completed_at IS NOT NULL
         AND DATEDIFF(HOUR, eop.sent_at, eop.completed_at) <= 168
        THEN eop.id END)
        / NULLIF(COUNT(DISTINCT eop.id), 0) AS completion_rate_d7
FROM postgres.employee_onboarding_packets eop
GROUP BY 1
ORDER BY 1;
```

### Median hours to NHP completion by month
```sql
SELECT
    DATE_TRUNC('month', eop.sent_at) AS month,
    MEDIAN(DATEDIFF(HOUR, eop.sent_at, eop.completed_at)) AS median_hours_to_completion
FROM postgres.employee_onboarding_packets eop
WHERE eop.completed_at IS NOT NULL
GROUP BY 1
ORDER BY 1;
```

### Invite → Login rate (D7) by month
```sql
-- Note: currently tracked at Job level; migrating to Team Member level
SELECT
    DATE_TRUNC('month', j.created_at) AS month,
    COUNT(DISTINCT j.id) AS invited_employees,
    COUNT(DISTINCT CASE
        WHEN j.first_login_at IS NOT NULL
         AND DATEDIFF(DAY, j.created_at, j.first_login_at) <= 7
        THEN j.id END) AS logged_in_d7,
    1.0 * COUNT(DISTINCT CASE
        WHEN j.first_login_at IS NOT NULL
         AND DATEDIFF(DAY, j.created_at, j.first_login_at) <= 7
        THEN j.id END)
        / NULLIF(COUNT(DISTINCT j.id), 0) AS invite_login_rate_d7
FROM postgres.jobs j
WHERE j.level = 'Employee'
GROUP BY 1
ORDER BY 1;
```

### HR Docs engagement rate among active companies
```sql
SELECT
    co.date,
    COUNT(DISTINCT co.company_id) AS active_companies,
    COUNT(DISTINCT CASE WHEN co.hrdocs_engaged_boolean = 1 THEN co.company_id END) AS hrdocs_engaged,
    1.0 * COUNT(DISTINCT CASE WHEN co.hrdocs_engaged_boolean = 1 THEN co.company_id END)
        / NULLIF(COUNT(DISTINCT co.company_id), 0) AS pct_hrdocs_engaged
FROM bizops.product_company_engagement_metrics co
WHERE EXISTS (
    SELECT 1
    FROM bizops.product_location_engagement_metrics loc
    JOIN public.locations l ON l.location_id = loc.location_id
    WHERE l.company_id = co.company_id
      AND loc.date = co.date
      AND loc.engagement_boolean = 1
)
GROUP BY 1
ORDER BY 1;
```

### Time offs and manager log engagement rate among engaged locations
```sql
SELECT
    DATE_TRUNC('month', date) AS month,
    COUNT(DISTINCT CASE WHEN engagement_boolean = 1 THEN location_id END) AS engaged_locs,
    COUNT(DISTINCT CASE WHEN time_offs_engaged_boolean = 1 THEN location_id END) AS time_offs_engaged,
    COUNT(DISTINCT CASE WHEN manager_log_engaged_boolean = 1 THEN location_id END) AS manager_log_engaged,
    1.0 * COUNT(DISTINCT CASE WHEN time_offs_engaged_boolean = 1 THEN location_id END)
        / NULLIF(COUNT(DISTINCT CASE WHEN engagement_boolean = 1 THEN location_id END), 0) AS pct_time_offs,
    1.0 * COUNT(DISTINCT CASE WHEN manager_log_engaged_boolean = 1 THEN location_id END)
        / NULLIF(COUNT(DISTINCT CASE WHEN engagement_boolean = 1 THEN location_id END), 0) AS pct_manager_log
FROM bizops.product_location_engagement_metrics
WHERE date = LAST_DAY(ADD_MONTHS(CURRENT_DATE, -1))
GROUP BY 1;
```
