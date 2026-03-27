# Homebase Business Context

Load when you need entity relationships, revenue model, growth funnel, or diagnostic patterns for metric movements.

## Business Overview

Homebase is a **B2B workforce management SaaS platform** serving small businesses. Product offering includes scheduling, time tracking, hiring, payroll, team messaging, and HR tools. Customers include both paid and free-tier businesses. Additional features may be unlocked through various pricing tiers.

**User roles:**
- **Owners** — business owners who manage their Homebase account
- **Managers / General Managers** — employees with management permissions
- **Employees** — workers at a location who clock in/out, view schedules, etc.

---

## Key Entities

### Location
The **primary unit of analysis** for most Homebase metrics. A location represents a single physical business site. Most metrics are calculated at the location level first, then rolled up to company.

> When someone refers to "users," they most likely mean **locations**. Clarify if unclear.

### Company
A business entity that may own **one or more locations**. 

### Users
Any individual who uses the Homebase product. Could be an Owner, Manager, or Employee. This term is ambiguous — always clarify which user type is meant.

### Jobs
The specific relationship that describes an employee's role at a business. A job links a user to a location with a specific role. One user can have multiple jobs.

### Roster
The set of employees (jobs) assigned to a location. Many engagement thresholds are defined as a percentage of roster size (e.g., "20% of roster") to normalize for different business sizes.

---

## Pricing Tiers

### Team App

Unless on trial, Team App subspcriptions follow this pricing model: 


| Tier ID | Plan Name | Description | Paying Flag |
|---------|-----------|-------------|-------------|
| 1 | Free (Basic) | Free tier with limited features | no | 
| 2 | Essentials | First paid tier — unlocks geofencing, overtime preferences | yes |
| 3 | Plus | Mid-tier — unlocks department management | yes | 
| 4 | All-in-One (AiO) | Top tier — all features included | yes |

#### TA Pricing Identifiers in Data

| Column | Table | Description | 
|--------|-------|-------------|
| `tier_id` | `public.locations` | 2, 3, or 4 if CURRENTLY paying | 
| `tier_id` | `dbt.active_paying_history_for_looker` | 2, 3, or 4 if paying on specific snapshot day |

### Payroll

Payroll is a separate subscription with its own paying status. Monthly subscription model with additional per-employee fees per payroll run. 
More info on calculations provided in Payroll Domain Specific Files.

---

## How the Business Works

### Growth Funnel

```
Marketing Spend (paid / organic / partner)
  → Signups (new companies)
    → 1D1 Activation (action within 24h)
      → 2D7 (2+ active days in 7d)
        → Engaged (core usage + OAM activity)
          → Paying (upgrade to tier 2+)
            → Retained (still engaged in future months)
```

Retained = still engaged. Does NOT require paying. Paying retention and engagement retention are tracked separately.

### Revenue Model

| Product | Model | Unit | Key metric |
|---|---|---|---|
| **Team App** | Location-level subscription | Monthly per location, tiered (Essentials / Plus / AiO) | MRR, ARR, paying locations |
| **Payroll** | Separate subscription + per-employee fee | Monthly base + per-employee per payroll run | Payroll ARR, ran payroll %, win rate |
| **Cash Out** | Employee-driven, transaction-based | $4.99 per instant advance | CO ARR, CO users, instant advance rate |
| **Add-ons** | Subscription-based (varies) | Monthly per add-on | *Documentation gap — not yet centralized* |

Revenue streams are independent. A company can pay for any combination. Cross-sell (attaching Payroll, Hiring, or CO to Team App) is a key growth lever.

### Diagnostic Patterns

IF a metric moves → check what's upstream or adjacent:

| Symptom | First checks |
|---|---|
| Activation down (1D1 rate) | Marketing spend / channel mix (CPA spike?), signup volume by source, onboarding flow changes or experiments |
| Engagement down | Which component (TT, scheduling, OAM)? Cut by tier, tenure, company size. Check launch timeline and experiment registry. Level shift (one-week) vs. trend (4+ weeks)? |
| Churn up | Engagement churn or paying churn? (Independent.) Which segment by tier, geo, biz type, tenure. Pricing changes or plan migrations? |
| Revenue flat, locations growing | ASP compression — new locations at lower tiers? Tier mix shift? Cross-sell (payroll, hiring) keeping pace? |
| CO metrics declining | Check Looker first (source of truth) — Amplitude may be artifacting. Which funnel step? Segment by bank type. Non-repayment rate changes? |

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