# Schema Reference

Core tables, join patterns, and column reference for Homebase data. For business context (what Homebase is, entity model, pricing), see `global/business-overview.md`. For metric definitions, see `glossary.md`.

---

## Core Entity Tables

| Table | Grain | Description |
|---|---|---|
| `prod_redshift_replica.public.locations` | One row per location | Location master data (cleaned, deduplicated, fake/demo accounts removed) |
| `prod_redshift_replica.public.companies` | One row per company | Company master data (cleaned, deduplicated, fake/demo accounts removed) |
| `prod_redshift_replica.postgres.locations` | One row per location | Raw location data from production |
| `prod_redshift_replica.postgres.jobs` | One row per job | Employee-location role assignments |
| `prod_redshift_replica.dbt.active_paying_history_for_looker` | One row per location per date | Historical paying status snapshots |
| `prod_redshift_replica.postgres.trial_periods` | One row per trial | Trial state, tier, dates |

**When to use Location vs Company as unit of analysis:**
- **Location** for most operational and product metrics — Team App is billed per location, engagement is measured per location, schedules and timecards live at the location level.
- **Company** for acquisition metrics (signups, 1D1), trial metrics, and payroll — payroll spans the whole company and is billed per company, and signup/owner context lives here.

Note: postgres entity tables use `id` as the primary key (e.g., `id` in `postgres.locations`), while public/semantic tables use the full name (e.g., `location_id` in `public.locations`).

## Key Identifiers

| Column | Found in | Description |
|---|---|---|
| `location_id` | Most public/semantic tables | Unique identifier for a location |
| `company_id` | `locations`, company-level tables | Unique identifier for a company |
| `job_id` | `jobs`, `timecards` | Unique identifier for an employee-location role |
| `user_id` | `users`, `jobs`, `shifts` | Unique identifier for a person |
| `owner_id` | `public.locations` | User ID of the location owner |

## Key Join Patterns

```sql
-- Location to Company
JOIN public.locations l ON l.location_id = <source>.location_id
-- then use l.company_id

-- Jobs to Location
FROM postgres.jobs j
JOIN public.locations l ON l.location_id = j.location_id
```

---

## Pricing Tier Data

| Column | Table | Description |
|---|---|---|
| `tier_id` | `public.locations` | Current tier (2, 3, or 4 if paying) |
| `tier_id` | `dbt.active_paying_history_for_looker` | Tier on a specific snapshot day |

### Trial Periods

New locations get a 2-week onboarding trial at Enterprise tier. During an active trial, `tier_id` reflects the trial tier, not a paid plan.

| `state` value | Meaning |
|---|---|
| `started` | Active trial — `tier_id` is inflated |
| `completed` | Trial ended, location downgraded |
| `interrupted` | Trial stopped early (chose a paid plan) |

Exclude active trials from paying queries:
`WHERE location_id NOT IN (SELECT location_id FROM postgres.trial_periods WHERE state = 'started')`

---

## Locations Table (`public.locations`)

### Lifecycle Dates

| Column | Description |
|---|---|
| `created_at` | When the location was first created |
| `activated` | First published schedule OR first timecard |
| `archived_at` | When archived (NULL if still active) |

### Geographic Attributes

Geographic data is owner-controlled — inputted at time of sign up, can be updated via settings. May not always be accurate.

| Column | Description |
|---|---|
| `city` | City name (lowercase, owner-entered) |
| `state` | State abbreviation (raw, may have inconsistent formatting) |
| `state_cleaned` | Standardized state abbreviation — use this for analysis |
| `zip` | ZIP/postal code |
| `latitude` / `longitude` | Coordinates |
| `time_zone` | Time zone (e.g., "America/Los_Angeles") |
| `msa` | Metropolitan Statistical Area |

### Business Classification

| Column | Description |
|---|---|
| `business_type_new` | Broad industry (e.g., "Retail", "Food and Drink"). Biz Type 2.0, introduced 9/15/20. Inputted at time of sign up, can be updated via settings. |
| `business_category_new` | Detailed category (e.g., "Coffee Shop", "Pizza Restaurant") |
| `naics_code` | Estimated NAICS code based on type and category |

### Size & Scale

| Column | Description |
|---|---|
| `company_size` | Count of unarchived locations in the same company (1 = single-location) |
| `total_employees` | Count of unarchived jobs at this location |
| `total_active_users` | Count of unarchived employees who have logged in (includes owner/managers) |

### Plan & Billing

| Column | Description |
|---|---|
| `tier_id` | Current subscription tier (see Pricing Tier Data above) |
| `billing_source` | Payment source (e.g., "stripe", "apple", "clover") |

### Partner & Integration Data

| Column | Description |
|---|---|
| `partner_id` | Acquisition partner/channel ID |
| `clover_merchant_id` | Clover POS merchant ID (NULL if not Clover) |
| `first_clover_embedded_activated_date` | When Clover embedded was first activated |
| `payroll_provider` | Connected payroll provider ID |
| `integrated_payroll` | 0/1 — has payroll integration |

#### Payroll Provider Mapping

| ID | Provider |
|---|---|
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

### Feature Settings

| Column | Description |
|---|---|
| `mobile_timeclock_enabled` | 0/1 — mobile clock-in/out enabled |
| `timesheet_approval_enabled` | 0/1 — timesheet locking enabled (from `postgres.location_properties`) |

### Other

| Column | Description |
|---|---|
| `name` | Location/business name |
| `phone` | Phone number |
