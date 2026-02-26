# Locations 

## Overview

This document provides business context for the Homebase locations table and what locations represent at Homebase. A **location** represents a single physical business site (e.g., one restaurant, one retail store) and is the primary unit of analysis for most Homebase metrics, unless otherwise specified. Companies may have one or more locations.  

---

## Data Source

### Primary Table

| Table | Schema | Description |
|-------|--------|-------------|
| `locations` | `public` | Master dimension table for all Homebase locations. Contains attributes, classification, activity flags, and geographic data. This is a cleaned version of `postgres.locations` where it removes likely duplicate locations|

### Key Identifiers

| Column | Type | Description |
|--------|------|-------------|
| `location_id` | `number` | Unique identifier for a location (primary key) |
| `company_id` | `string` | Unique identifier for the parent company |
| `owner_id` | `number` | The `user_id` of the location owner |

---

## Lifecycle Dates

These timestamps track key milestones in a location's journey with Homebase.

| Column | Description |
|--------|-------------|
| `created_at` | Timestamp when the location was first created in Homebase |
| `activated` | Timestamp when the location first published a schedule OR created a timecard. This marks the transition from "signed up" to "actually using the product." |
| `archived_at` | Timestamp when the location was archived (soft-deleted). NULL if location is still active. |

### Derived Fields

| Concept | Logic | Description |
|---------|-------|-------------|
| Is Archived | `archived_at IS NOT NULL` | TRUE if the location has been archived |
| Created Day of Week | `DATE_PART('dow', created_at)` | Day of week (0=Sunday, 6=Saturday) when location was created |
| Clover | `clover_merchant_id` is not NULL | TRUE if the location is a Clover Location |
---

## Geographic Attributes

Geographic data is **owner-controlled** via the settings page and may not always be accurate or complete.

| Column | Description |
|--------|-------------|
| `city` | City name (owner-entered). Stored in lowercase. |
| `state` | State abbreviation (owner-entered). May contain inconsistent formatting. |
| `state_cleaned` | Standardized state abbreviation using internal mapping table. Preferred for analysis. |
| `zip` | ZIP/postal code (owner-entered) |
| `latitude` | Latitude coordinate for the location |
| `longitude` | Longitude coordinate for the location |
| `time_zone` | Time zone setting for the location (e.g., "America/Los_Angeles") |
| `msa` | Metropolitan Statistical Area—the metropolitan region where the location is situated |

### State Regions

Locations can be grouped into regions based on Bureau of Economic Analysis definitions:

| Region | States |
|--------|--------|
| New England | CT, ME, MA, NH, RI, VT |
| MidEast | DE, DC, MD, NJ, PA, NY |
| Great Lakes | IL, IN, MI, OH, WI |
| Plains | IA, KS, MN, MO, NE, SD, ND |
| Southeast | AL, AR, FL, GA, KY, LA, MS, NC, VA, WV, SC, TN |
| Southwest | AZ, NM, OK, TX |
| Rocky Mountain | CO, ID, MT, WY, UT |
| Far West | AK, CA, HI, NV, WA, OR |

---

## Business Classification

Homebase uses a combination of Google Places data and text-based classification to categorize businesses.

| Column | Description |
|--------|-------------|
| `business_type_new` | Broad industry classification (e.g., "Retail", "Food and Drink", "Services"). This is the "Biz Type 2.0" classification introduced 9/15/20. |
| `business_category_new` | More detailed industry classification (e.g., "Coffee Shop", "Electrician", "Pizza Restaurant") |
| `naics_code` | Estimated NAICS (North American Industry Classification System) code based on business type and category |
| `project_or_shift` | Primary use case classification: whether the business primarily uses Homebase for project-based work or shift-based scheduling |

**Business context**: Business classification is important for segmentation, industry benchmarking, and understanding product-market fit across different verticals. Homebase historically has strong penetration in restaurants and retail.

---

## Size & Scale Metrics

| Column | Type | Description |
|--------|------|-------------|
| `company_size` | `number` | Count of unarchived locations belonging to the same company. Single-location companies have value = 1. |
| `total_employees` | `number` | Count of unarchived jobs (employees) at this location |
| `total_active_users` | `number` | Count of unarchived employees who have logged in via web or mobile app. Includes owner/managers. |

**Business context**: These metrics help segment customers by size. A "small" location might have <10 employees, while "large" might be 50+. Multi-location companies (`company_size` > 1) often have different needs and behaviors than single-location businesses.

---

## Activity & Usage Flags

These flags indicate recent product usage and are typically refreshed on a rolling basis.

### Core Activity Flags

| Column | Type | Description |
|--------|------|-------------|
| `mau` | `boolean` | Monthly Active Location. TRUE if the location had a timecard created or schedule published in the last 30 days. |
| `active_now` | `boolean` | TRUE if the location has had a schedule publish/timecard, OR had a user login with >1 pageview on web, OR had a user login on mobile app. Broader than MAU. |

### Feature Usage Flags (Last 30 Days)

| Column | Type | Description |
|--------|------|-------------|
| `used_mobile` | `number` (0/1) | Anyone at the location signed into a mobile device |
| `used_web` | `number` (0/1) | Anyone at the location signed into the web app |
| `used_scheduling` | `number` (0/1) | Location published a schedule |
| `used_timecards` | `number` (0/1) | Location created a timecard |
| `used_messaging` | `number` (0/1) | Anyone at the **company** (not just location) used messaging |

### Hiring Usage

| Column | Description |
|--------|-------------|
| `used_hiring` | 1 if location has ever had a hiring post event |
| `used_hiring_last_30` | 1 if location had a hiring post event in the last 30 days |
| `used_hiring_last_60` | 1 if location had a hiring post event in the last 60 days |

**Note**: Hiring flags are derived from a subquery against `hiring_post_events` table.

---

## Plan & Billing

| Column | Type | Description |
|--------|------|-------------|
| `tier_id` | `number` | The subscription tier/plan the location is currently on. See mapping below. |
| `billing_source` | `string` | Payment source (e.g., "stripe", "apple", "clover"). May not populate until first payment. |

### Tier / Plan Mapping

| tier_id | Plan Name |
|---------|-----------|
| 1 | Basic |
| 2 | Essentials |
| 3 | Plus |
| 4 | All-in-One (AiO) |

**Business context**: Tier determines feature access. Many engagement metrics have tier prerequisites (e.g., geofencing requires Essentials+).

### Trial Periods

New locations get a 2-week onboarding trial at Enterprise tier. During an active trial, `tier_id` reflects the trial tier — not a paid plan. Filter out active trials when identifying paying locations.

| Table | Schema | Join | Key Columns |
|-------|--------|------|-------------|
| `trial_periods` | `postgres` | `location_id` | `state`, `trial_tier_id`, `downgrade_to_tier_id`, `start_at`, `end_at`, `source` |

| `state` value | Meaning |
|---------------|---------|
| `started` | Active trial — `tier_id` is inflated |
| `completed` | Trial ended, location downgraded |
| `interrupted` | Trial stopped early (merchant chose a paid plan) |

**Exclude active trials from paying-plan queries:**
`WHERE location_id NOT IN (SELECT location_id FROM postgres.trial_periods WHERE state = 'started')`

---

## Partner & Integration Data

| Column | Type | Description |
|--------|------|-------------|
| `partner_id` | `number` | ID of the partner/channel through which this location was acquired |
| `clover_merchant_id` | `string` | Clover POS merchant ID if integrated with Clover |
| `payroll_provider` | `number` | ID of connected payroll provider (see mapping below) |
| `integrated_payroll` | `number` (0/1) | Whether location has an integrated payroll connection |
| `us_foods_account_number` | `number` | US Foods account number if applicable |

### Payroll Provider Mapping

| ID | Provider Name |
|----|---------------|
| 1 | Quickbooks |
| 2 | Bank of America |
| 3 | Paychex Preview |
| 4 | Wells Fargo |
| 5 | SurePayroll |
| 6 | Excel / CSV |
| 7 | ADP Pay eXpert |
| 8 | Millennium Payroll |
| 9 | Heartland Payroll |
| 10 | Square |
| 11 | ADP Workforce Now |
| 13 | Gusto |
| 14 | ADP Run |
| 15 | Paychex Flex |

### Clover Integration

| Column | Description |
|--------|-------------|
| `clover_merchant_id` | Clover merchant ID for this location |
| `first_clover_embedded_activated_date` | Timestamp when Clover embedded integration was first activated |

---

## Feature Settings

| Column | Type | Description |
|--------|------|-------------|
| `mobile_timeclock_enabled` | `number` (0/1) | Whether mobile clock-in/out is enabled for this location |
| `timesheet_approval_enabled` | `number` (0/1) | Whether timesheet approval (locking timecards) is enabled. Derived from `postgres.location_properties`. |

---

## Contact Information

| Column | Description |
|--------|-------------|
| `name` | Location name (business name) |
| `phone` | Phone number for the location |

---

## Quick Reference: All Columns

### Identifiers & Keys
| Column | Table | Description |
|--------|-------|-------------|
| `location_id` | `public.locations` | Primary key |
| `company_id` | `public.locations` | Foreign key to company |
| `owner_id` | `public.locations` | User ID of owner |

### Lifecycle Timestamps
| Column | Table | Description |
|--------|-------|-------------|
| `created_at` | `public.locations` | Location creation time |
| `activated` | `public.locations` | First schedule publish or timecard |
| `archived_at` | `public.locations` | Archive timestamp (NULL if active) |

### Geographic
| Column | Table | Description |
|--------|-------|-------------|
| `city` | `public.locations` | City (lowercase) |
| `state` | `public.locations` | State (raw) |
| `state_cleaned` | `public.locations` | State (standardized) |
| `zip` | `public.locations` | ZIP code |
| `latitude` | `public.locations` | Latitude |
| `longitude` | `public.locations` | Longitude |
| `time_zone` | `public.locations` | Time zone |
| `msa` | `public.locations` | Metro statistical area |

### Business Classification
| Column | Table | Description |
|--------|-------|-------------|
| `business_type_new` | `public.locations` | Broad industry type |
| `business_category_new` | `public.locations` | Detailed industry category |
| `naics_code` | `public.locations` | Estimated NAICS code |
| `project_or_shift` | `public.locations` | Use case classification |

### Size & Scale
| Column | Table | Description |
|--------|-------|-------------|
| `company_size` | `public.locations` | # of locations in company |
| `total_employees` | `public.locations` | # of employees at location |
| `total_active_users` | `public.locations` | # of active users at location |

### Activity Flags
| Column | Table | Description |
|--------|-------|-------------|
| `mau` | `public.locations` | Monthly active (30d) |
| `active_now` | `public.locations` | Currently active |
| `used_mobile` | `public.locations` | Used mobile (30d) |
| `used_web` | `public.locations` | Used web (30d) |
| `used_scheduling` | `public.locations` | Published schedule (30d) |
| `used_timecards` | `public.locations` | Created timecard (30d) |
| `used_messaging` | `public.locations` | Company used messaging (30d) |

### Plan & Billing
| Column | Table | Description |
|--------|-------|-------------|
| `tier_id` | `public.locations` | Subscription tier ID |
| `billing_source` | `public.locations` | Payment source |

### Integrations
| Column | Table | Description |
|--------|-------|-------------|
| `partner_id` | `public.locations` | Acquisition partner ID |
| `clover_merchant_id` | `public.locations` | Clover merchant ID |
| `payroll_provider` | `public.locations` | Payroll provider ID |
| `integrated_payroll` | `public.locations` | Has payroll integration |
| `us_foods_account_number` | `public.locations` | US Foods account # |
| `first_clover_embedded_activated_date` | `public.locations` | Clover activation date |

### Settings
| Column | Table | Description |
|--------|-------|-------------|
| `mobile_timeclock_enabled` | `public.locations` | Mobile clock-in enabled |

---

## Common Analysis Patterns

1. **Active location counts**: Filter to `mau = TRUE` or `active_now = TRUE` for currently engaged locations

2. **Exclude archived**: Always filter `archived_at IS NULL` unless analyzing churn

3. **Activation funnel**: Compare `created_at` to `activated` to measure time-to-activation and activation rates

4. **Geographic segmentation**: Use `state_cleaned` (not `state`) for consistent state-level analysis

5. **Industry analysis**: Group by `business_type_new` for broad segments, `business_category_new` for detailed

6. **Size segmentation**: Use `total_employees` for location size, `company_size` for multi-location analysis

---

## Example SQL Queries

### Count active vs total locations
```sql
SELECT 
    COUNT(DISTINCT location_id) AS total_locations,
    COUNT(DISTINCT CASE WHEN mau = true THEN location_id END) AS mau_locations,
    COUNT(DISTINCT CASE WHEN active_now = true THEN location_id END) AS active_now_locations
FROM public.locations
WHERE archived_at IS NULL;
```

### Locations by business type
```sql
SELECT 
    business_type_new,
    COUNT(DISTINCT location_id) AS location_count,
    SUM(total_employees) AS total_employees
FROM public.locations
WHERE archived_at IS NULL
GROUP BY 1
ORDER BY 2 DESC;
```

### Activation rate by cohort
```sql
SELECT 
    DATE_TRUNC('month', created_at) AS signup_month,
    COUNT(DISTINCT location_id) AS signups,
    COUNT(DISTINCT CASE WHEN activated IS NOT NULL THEN location_id END) AS activated,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN activated IS NOT NULL THEN location_id END) 
        / COUNT(DISTINCT location_id), 2) AS activation_rate
FROM public.locations
GROUP BY 1
ORDER BY 1;
```

### Geographic distribution
```sql
SELECT 
    state_cleaned,
    COUNT(DISTINCT location_id) AS locations,
    COUNT(DISTINCT company_id) AS companies
FROM public.locations
WHERE archived_at IS NULL
  AND state_cleaned IS NOT NULL
GROUP BY 1
ORDER BY 2 DESC;
```

### Multi-location vs single-location companies
```sql
SELECT 
    CASE WHEN company_size = 1 THEN 'Single Location' ELSE 'Multi-Location' END AS company_type,
    COUNT(DISTINCT location_id) AS locations,
    COUNT(DISTINCT company_id) AS companies
FROM public.locations
WHERE archived_at IS NULL
GROUP BY 1;
```
