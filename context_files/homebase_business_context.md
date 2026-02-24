# Homebase Business Context

## Business Overview

Homebase is a **B2B workforce management SaaS platform** serving small businesses, primarily in the restaurant and retail industries. The platform offers scheduling, time tracking, hiring, payroll, team messaging, and HR tools. Customers include both paid and free-tier businesses. Additional features may be unlocked through various pricing tiers.

**User roles:**
- **Owners** — business owners who manage their Homebase account
- **Managers / General Managers** — employees with management permissions
- **Employees** — workers at a location who clock in/out, view schedules, etc.

---

## Key Entities

### Location
The **primary unit of analysis** for most Homebase metrics. A location represents a single physical business site (e.g., one restaurant, one retail store). Most metrics are calculated at the location level first, then rolled up to the company level.

> When someone refers to "users," they most likely mean **locations**. Clarify if unclear.

### Company
A business entity that may own **one or more locations**. A company is considered "engaged" with a feature if **any** of its locations are engaged with that feature.

### Users
Any individual who uses the Homebase product. Could be an Owner, Manager, or Employee. This term is ambiguous — always clarify which user type is meant.

### Jobs
The specific relationship that describes an employee's role at a business. A job links a user to a location with a specific role. One user can have multiple jobs (e.g., working at two locations).

### Roster
The set of employees (jobs) assigned to a location. Many engagement thresholds are defined as a percentage of roster size (e.g., "20% of roster") to normalize for businesses of different sizes.

---

## Pricing Tiers

| Tier ID | Plan Name | Description |
|---------|-----------|-------------|
| 0 | Free (Basic) | Free tier with limited features |
| 2 | Essentials | First paid tier — unlocks geofencing, overtime preferences |
| 3 | Plus | Mid-tier — unlocks department management |
| 4 | All-in-One (AiO) | Top tier — all features included |

**Team App Paying** = locations/companies on Essentials (2), Plus (3), or AiO (4).

**Payroll** is a separate subscription with its own paying status. Monthly subscription model with additional per-employee fees per payroll run.

---

## Primary Tables & Relationships

### Core Tables

| Table | Schema | Grain | Description |
|-------|--------|-------|-------------|
| `locations` | `public` | One row per location | Location master data (cleaned, deduplicated) |
| `locations` | `postgres` | One row per location | Raw location data from production |
| `companies` | `public` | One row per company | Company master data |
| `jobs` | `postgres` | One row per job | Employee-location role assignments |
| `product_location_engagement_metrics` | `bizops` | One row per location per date | Location-level engagement booleans |
| `product_company_engagement_metrics` | `bizops` | One row per company per date | Company-level engagement booleans |
| `active_paying_history_for_looker` | `dbt` | One row per location per date | Historical paying status snapshots |

### Entity Relationships

```
Company (company_id)
  └── Location (location_id)
        ├── Jobs (job_id) → links employees to locations
        │     └── Timecards (timecard_id) → clock-in/out records
        ├── Shifts (shift_id) → scheduled shifts
        └── Engagement Metrics → daily engagement snapshots
```

### Key Join Patterns

```sql
-- Location to Company
JOIN public.locations l ON l.location_id = <source>.location_id
-- then use l.company_id

-- Location engagement to Company engagement
FROM bizops.product_location_engagement_metrics loc
JOIN public.locations l ON l.location_id = loc.location_id
JOIN bizops.product_company_engagement_metrics co
  ON co.company_id = l.company_id
  AND co.date = loc.date

-- Jobs to Location
FROM postgres.jobs j
JOIN public.locations l ON l.location_id = j.location_id
```

### Key Identifiers

| Column | Found In | Description |
|--------|----------|-------------|
| `location_id` | Most tables | Unique identifier for a location |
| `company_id` | `locations`, company-level tables | Unique identifier for a company |
| `job_id` | `jobs`, `timecards` | Unique identifier for an employee-location role |
| `user_id` | `users`, `jobs`, `shifts` | Unique identifier for a person |
| `date` | Metrics tables | Reporting date for daily snapshots |

---

## Activation & Lifecycle Metrics

| Metric | Definition |
|--------|------------|
| **1D1** | Company/location with activity (new user invites employee + employee logs in) within first 24 hours of signup |
| **2D7** | Company/location active on 2 different days within a continuous 7-day window, with at least one employee activity each day |
| **2D30** | Same as 2D7 but within a 30-day window |
| **Activated** | Location that first published a schedule OR created a timecard |

### Lifecycle Metric Columns

| Column | Table | Description |
|--------|-------|-------------|
| `signup_1d1` | `public.companies` | `true` if 1D1 active at signup |
| `signup_2d7` | `public.companies` | `true` if 2D7 active from signup |
| `signup_2d30` | `public.companies` | `true` if 2D30 active from signup |
| `twod7_active_today_location` | `dbt.active_paying_history_for_looker` | `true` if 2D7 active on snapshot day |
| `two_d_thirty_active_this_month_location` | `dbt.active_paying_history_for_looker` | `true` if 2D30 active on snapshot day |

---

## Paying Status Columns

### Team App Paying

| Column | Table | Description |
|--------|-------|-------------|
| `tier` | `public.locations` | 2, 3, or 4 if CURRENTLY paying |
| `tier` | `dbt.active_paying_history_for_looker` | 2, 3, or 4 if paying on specific snapshot day |

### Payroll Paying

A company / location which are paying for Payroll. Monthly subscription model with additional fees per employee payroll run. More info on calculations provided in Payroll Domain Specific Files.

### Payroll Active
A company/location is **Payroll Active** if they ran payroll within a given time period (usually 30-day lookback).
