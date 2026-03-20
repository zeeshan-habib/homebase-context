# Hiring Assistant: Analytics, Data & Reporting Context

> This document provides context for AI assistants (like Claude) and team members when working on Hiring Assistant analytics, data pipelines, and reporting.

## Product Overview

### What is Hiring Assistant?
Hiring Assistant is Homebase's recruitment solution that helps businesses post jobs, receive applications, screen candidates, and manage the hiring process. The product launched as Version 2 (V2) on **2025-06-18**.

### Key Stakeholders
- Analytics/Data team for reporting and insights
- Product team for feature performance tracking
- Revenue/Finance team for MRR/ARR reporting
- Customer Success for monitoring job post health

## Data Infrastructure

### Data Schemas
The Hiring Assistant data model spans multiple schemas:

- **`postgres`**: Core production tables (hiring_job_requests, hiring_job_applications, hiring_applicants, hiring_settings, hiring_interviews, hiring_job_request_boosts, biller_product_subscriptions, applied_discounts, discounts, pricing_products)
- **`playground`**: Staging/analytics tables (hiring_job_requests, hiring_job_applications, mm_hiring_product)
- **`public`**: Shared dimension tables (locations, companies, users)
- **`ext_firehose`**: Event data (team_change_events, experiment_tracking_events)
- **`ext_homebase1.homebase1_public`**: External/legacy data (hiring_company_free_trials)
- **`business_users.hiring`**: Analytics-ready tables (job_post_history_by_day)

### Key Tables & Views

#### Core Tables

**`hiring_job_requests`** (postgres/playground)
- Contains all job postings
- Key fields:
  - `id`: Unique job post identifier
  - `created_at`: Microsecond timestamp of job creation
  - `activated_at`: When job was activated/published
  - `flagged_at`: When job was flagged for review
  - `title`, `description`: Job details
  - `status`: Job status (draft, active, etc.)
  - `hiring_version`: Version flag (2 for V2 launch)
  - `location_id`: Associated location
  - `billing_plan`: trial vs subscription

**`hiring_job_applications`** (postgres/playground)
- All applications to job posts
- Key fields:
  - `id`: Unique application identifier
  - `owner_id`: Foreign key to job request (hiring_job_requests.id)
  - `owner_type`: Always 'Hiring::JobRequest'
  - `created_at`: Application timestamp
  - `source`: Application source (various channels)
  - `hiring_applicant_id`: Foreign key to applicant

**`mm_hiring_product`** (playground)
- Screener and matching metrics
- Key fields:
  - `application_id`: Foreign key to hiring_job_applications.id
  - `application_created_at`: Application timestamp
  - `screener_opened_timestamp`: When screener was opened
  - `screener_completed_timestamp`: When screener was completed
  - `is_top_match`: Boolean flag for top match candidates

**`hiring_applicants`** (postgres)
- Applicant profile information
- Key fields:
  - `id`: Applicant identifier
  - `first_name`, `last_name`: Applicant name

**`hiring_interviews`** (playground)
- Interview scheduling data
- Key fields:
  - `id`: Interview identifier
  - `application_id`: Foreign key to applications

**`hiring_job_request_boosts`** (postgres)
- Job post boost/promotion data
- Key fields:
  - `id`: Boost identifier
  - `hiring_job_request_id`: Foreign key to job requests

**`hiring_settings`** (postgres)
- Company-level hiring settings
- Key fields:
  - `company_id`: Company identifier
  - `syndicatable`: Whether job can be syndicated
  - `indeed_syndication`, `zip_recruiter_syndication`: Syndication flags

**`biller_product_subscriptions`** (postgres)
- Subscription data
- Key fields:
  - `id`, `subscription_id`: Subscription identifiers
  - `owner_id`: Location ID
  - `owner_type`: Always 'Location'
  - `subscription_type`: Filter for 'hiring_assistant'
  - `product_id`: Product SKU (925, 1057, 1058)
  - `created_at`: Subscription start date
  - `archived_at`: Subscription end date (null if active)

**`team_change_events`** (ext_firehose)
- Employee hiring events
- Key fields:
  - `type`: Event type ('job_created', 'user_created')
  - `location_id`: Location where event occurred
  - `user_id`: User/employee identifier
  - `profile_after`: JSON with employee details
  - `created_at`: Event timestamp

**`hiring_company_free_trials`** (ext_homebase1.homebase1_public)
- Trial start and expiration tracking
- Key fields:
  - `company_uuid`: Company identifier
  - `created_at`: Microsecond timestamp of trial start
  - `expires_at`: Microsecond timestamp of trial expiration
- **Timestamp conversion**: Both `created_at` and `expires_at` are in **microseconds** — convert with `TO_TIMESTAMP(created_at / 1000000.0)`
- Companies can technically have multiple trial records — always take the most recent one using `QUALIFY ROW_NUMBER() OVER (PARTITION BY company_uuid ORDER BY created_at DESC) = 1`

**`job_post_history_by_day`** (business_users.hiring)
- Pre-aggregated job metrics by day
- Key fields:
  - `id`: Job request ID
  - `job_age_days`: Days since job was activated
  - `application_count`: Applications at that day
  - `top_match_count`: Top matches at that day

#### Dimension Tables

**`locations`** (public)
- Location master table
- Key fields:
  - `location_id`: Primary key
  - `company_id`: Parent company
  - `name`: Location name

**`companies`** (public)
- Company master table
- Key fields:
  - `company_id`: Primary key
  - `uuid`: Company UUID
  - `name`: Company name
  - `employee_count`, `location_count`: Company size metrics
  - `created_at`: Company signup date

**`users`** (public)
- User/employee data
- Key fields:
  - `user_id`: Primary key
  - `role_name`: Employee role

### Data Pipeline
Production data flows from operational databases (postgres) to analytics staging (playground) to business-ready tables (business_users). Firehose captures event streams (ext_firehose).

### Aggregated Tables (Databricks Pipelines)

**Location**: `/Shared/Hiring Assistant Pipelines/Hiring Profile/Table Creation Pipeline`
**Schedule**: Daily
**Purpose**: Pre-aggregated tables for easier consumption and faster queries

#### 1. `business_users.hiring.aggregate_hiring_profile` (ICP Profile)
**Notebook**: `CREATE aggregate_hiring_profile (ICP Profile)`
**Description**: Master profile per company combining hiring stats, Homebase engagement, ML predictions, ICP definitions, and target segment classification

**Key Fields**:
- Company info: `company_id`, `company_name`, `company_uuid`, `owner_first_name`, `owner_last_name`, `email`, `phone`
- Homebase engagement: `max_team_app_tier`, `active_payroll_customer`, `time_tracking_engaged`, `scheduling_engaged`, `oam_activity`
- Historical hiring (L12M): `months_live_on_platform_L12`, `ee_added_L12M`, `ee_added_per_month_L12M`, `ee_add_per_location_per_month_L12M`, `months_with_hires_L12`
- Top roles: `top_role_1`, `top_role_1_count`, `top_role_2`, `top_role_2_count`, `top_role_3`, `top_role_3_count`
- ML predictions: `pattern_type`, `predicted_role`, `total_hires_this_role`, `months_since_last_hired`, `predicted_role_2`, `predicted_role_3`
- Hiring Assistant usage: `first_draft_created_at`, `first_zsp_view`
- External data: `google_place_id`
- V1 flag: `has_v1_location` (true if company has any location that was in the V1 experiment)

**ICP Logic**:
- `icp_hiring_facts`: `months_with_hires_L12 >= 6` AND `ee_add_per_location_per_month_L12M BETWEEN 2 AND 7` AND `location_count < 6`
- `icp_homebase_facts`: (Plus+ OR Payroll) AND (Time Tracking OR Scheduling engaged) AND OAM engaged
- `is_icp`: Both hiring facts AND Homebase facts = TRUE

**Target Segment Logic** (H1 2026):
- `is_target_segment`: `employee_count > 25` AND `business_type IN ('Food, Drink, & Dining', 'Hospitality')` AND `engaged = 1` AND `ee_added_per_month_L12M > 1.5` AND `months_with_hires_L12 > 5` AND `location_count < 6` AND `oam_activity = 1`
- This is specifically tuned for H1 2026 sales activities targeting high-frequency F&B and Hospitality hirers

**Sources**: Joins `hb_company_profile`, `hiring_assistant_usage`, `ml_hiring_intelligence`, `company_last_12_months_hiring_stats`, companies, users, google places, V1 experiment flags

#### 2. `business_users.hiring.job_post_history_by_day` (Historical Status by Day)
**Notebook**: `CREATE job_post_history_by_day (Historical status by day)`
**Description**: Daily time series of job metrics from activation to expiration with cumulative and daily values

**Key Fields**:
- Identifiers: `id` (job_id), `reporting_date`, `location_id`
- Time tracking: `job_age_days`, `activated_at`, `expires_at`, `is_expiration_date`, `is_first_job_post`
- Cumulative metrics: `application_count`, `top_match_count`, `screener_started_count`, `screener_completed_count`, `scheduled_interview_count`, `top_match_interview_count`
- Daily additions: `applications_added_today`, `top_matches_added_today`, `screeners_started_today`, `screeners_completed_today`, `interviews_scheduled_today`, `top_match_interviews_today`
- Syndication: `partner_toggles` (JSON field)

**Logic**:
- Creates date spine from `activated_at` to `expires_at` for each V2 job
- Uses window functions to calculate cumulative counts
- Joins daily metrics for applications, screeners (opened/completed), and interviews
- Filters: `hiring_version = 2`, `activated_at IS NOT NULL`, `location_id IS NOT NULL`

**Data Sources**: `postgres.hiring_job_requests`, `postgres.hiring_job_applications`, `playground.mm_hiring_product`, `playground.hiring_interviews`, `postgres.hiring_syndication_settings`

#### 3. `business_users.hiring.job_post_level_details`
**Notebook**: `CREATE job_post_level_details`
**Description**: Simple job-level aggregation with application metrics

**Key Fields**:
- Job details: `job_post_id`, `title`, `status`, `description`, `job_post_created_at`, `posted_at`, `activated_at`
- Location/Company: `location_id`, `company_id`, `company_UUID`
- Metrics: `applications`, `screener_starts`, `screener_completes`, `top_matches`

**Filters**: `created_at >= '2025-06-18'`, `hiring_version = 2`, `status NOT IN ('draft')`, `(activated_at OR flagged_at OR posted_at) IS NOT NULL`

**Data Sources**: `postgres.hiring_job_requests`, `postgres.hiring_job_applications`, `playground.mm_hiring_product`

#### 4. `business_users.hiring.ml_hiring_intelligence` (Hiring Phenotypes and Role Prediction)
**Notebook**: `CREATE ml_hiring_intelligence (Hiring Phenotypes and Role Prediction)`
**Description**: ML-powered hiring pattern classification and role prediction per company

**Key Fields**:
- Company info: `company_id`, `company_uuid`, `company_name`
- Pattern classification: `pattern_type` (consistent, trending, spike-driven, etc.)
- Top 3 predicted roles: `predicted_role`, `total_hires_this_role`, `months_since_last_hired`, `predicted_role_2`, `predicted_role_3`, etc.
- Confidence scores: Pattern confidence + role prediction confidence
- Actionability: Combined scoring for sales recommendations

**Logic**:
- Aggregates last 12 months of hiring data from `postgres.jobs` and `postgres.roles`
- Calculates monthly hiring volume, peak months, role diversity (Shannon entropy), top role concentration
- Uses Python ML (scikit-learn, pandas) for pattern classification via clustering
- Predicts top 3 roles using recency-weighted scoring and role normalization
- Filters companies with 5+ hires in L12M

**Technology**: SQL + Python (pandas, scikit-learn, numpy, scipy, statsmodels)

**Data Sources**: `postgres.jobs`, `postgres.roles`, `public.companies`, `public.locations`, `business_users.hiring.company_last_12_months_hiring_stats`

#### 5. `business_users.hiring.hb_company_profile` (Homebase Engagement)
**Notebook**: `CREATE hb_company_profile (Homebase Engagement)`
**Description**: Company-level Homebase product engagement metrics

**Key Fields**:
- Company basics: `company_id`, `company_uuid`, `company_signup_date`, `company_age_in_months`, `employee_count`, `location_count`
- Payroll: `active_payroll_customer` (boolean)
- Geography: `state`, `MSA`, `business_type`
- Team App engagement: `max_team_app_tier`, `engaged`, `time_tracking_engaged`, `scheduling_engaged`, `oam_activity`

**Data Sources**: `public.companies`, `public.locations`, `bizops.product_location_engagement_metrics`, `bizops.payroll_canonical_mrr_looker`

#### 6. `business_users.hiring.company_last_12_months_hiring_stats` (Historical Hiring Activity)
**Notebook**: `CREATE company_last_12_months_hiring_stats (Historical Hiring Activity)`
**Description**: Summary stats of company's historical hiring over last 12 months

**Key Fields**:
- Company info: `company_id`, `company_uuid`, `company_name`, `company_signup`
- Hiring volume: `months_live_on_platform_L12`, `ee_added` (total employees added), `EE_add_per_month` (average per month)
- Hiring patterns: `months_with_hires_L12`, `peak_hiring_month_number`
- Top roles: `top_role_1`, `top_role_1_count`, `top_role_2`, `top_role_2_count`, `top_role_3`, `top_role_3_count`

**Logic**:
- Aggregates `postgres.jobs` by month for last 12 months
- Calculates employees added (excludes first 30 days after location creation)
- Ranks top 3 roles by hire count per company
- Determines peak hiring month

**Data Sources**: `postgres.jobs`, `postgres.roles`, `public.companies`, `public.locations`

#### 7. `business_users.hiring.hiring_assistant_usage` (Hiring Assistant Activity)
**Notebook**: `CREATE hiring_assistant_usage (Hiring Assistant Activity)`
**Description**: Company usage stats for Hiring Assistant (V2)

**Key Fields**:
- Company info: `company_id`, `uuid`
- Syndication: `syndicated` (boolean - both Indeed and ZipRecruiter enabled)
- ZSP engagement: `ZSP_Visits`, `First_Hiring_ZSP_View__c`, `Last_Hiring_ZSP_View__c` (Zero State Page views from Amplitude)
- Job activity: `first_draft_created_at`, `first_job_posted`, `first_job_activated`, `jobs_activated`
- Application funnel: `Applications`, `Screeners`, `Top_Matches`

**Data Sources**: `postgres.hiring_job_requests` (V2 only), `postgres.hiring_job_applications`, `playground.mm_hiring_product`, `postgres.hiring_settings`, `ext_amplitude.amplitude_events`

#### 8. `business_users.hiring.jobs_with_metadata`
**Notebook**: `CREATE jobs_with_metadata`
**Description**: Row per hiring request with application and screener metrics

> ⚠️ **Contains both V1 and V2 jobs** — always filter `WHERE hiring_version = 2` unless explicitly analyzing V1.

**Key Fields**:
- Job details: `job_request_id`, `hiring_version`, `location_id`, `company_uuid`, `created_at`, `updated_at`, `expires_at`
- Job attributes: `title`, `role_id`, `role_type`, `standardized_role_id`, `target_wage_rate`, `target_wage_rate_max`, `status`, `view_count`
- Hierarchy: `original_parent_id`, `direct_parent_id` (for reposts)
- Metrics: `applicants`, `screener_starts`, `screener_completes`, `top_matches`
- Health: `healthy_job` (1 if >= 15 applicants AND >= 3 top matches, else 0)

**Trial Period Data Quality Note**:
Trial periods (`trial_started_at`) were not properly recorded before **2025-08-27**. When joining jobs to a trial window, use this pattern to handle pre-cutoff jobs:
```sql
LEFT JOIN business_users.hiring.jobs_with_metadata jm
  ON jm.company_uuid = cc.company_uuid
  AND (jm.activated_at >= cc.trial_started_at OR jm.activated_at <= '2025-08-27')
  AND jm.activated_at <= cc.trial_expires_at
  AND jm.hiring_version = 2
```
The `OR jm.activated_at <= '2025-08-27'` clause ensures jobs from before the cutoff are still included even if they predate the recorded trial start.

**Trial Start Product Behavior**:
The trial period is triggered by posting the **first job** — a company cannot have a trial record without having posted at least one V2 job. Companies with a trial record but zero jobs during the trial window are likely **blocked by fraud detection** and should be excluded from trial engagement analysis. Add this filter to the `company_trial_stats` CTE or final SELECT:
```sql
WHERE jobs_posted > 0
```

**Data Sources**: `postgres.hiring_job_requests`, `postgres.hiring_job_applications`, `playground.mm_hiring_product`

#### 9. `business_users.hiring.company_hiring_milestones` (Value Milestones)
**Notebook**: `CREATE company_hiring_milestones (Hiring User Milestones)`
**Description**: One row per company. Captures the timestamp when each value milestone was first reached in Hiring Assistant (V2). Used for funnel analysis and lifecycle stage tracking.

**Milestones (in order)**:
1. `first_zsp_visit_at` — Visited Zero State Page (from `hiring_assistant_usage`)
2. `first_draft_at` — Started a job draft (first `created_at` in `hiring_job_requests` V2)
3. `first_job_posted_at` — Posted first job; also triggers trial start (first non-draft with `activated_at` or `posted_at`)
4. `first_application_at` — Received first application
5. `tenth_application_at` — Received 10th application
6. `first_top_match_at` — Received first top match (from `playground.mm_hiring_product` where `is_top_match = TRUE`)
7. `first_healthy_job_at` — First day a job crossed 20+ applications AND 5+ top matches (from `job_post_history_by_day`)
8. `first_interview_at` — First interview scheduled (from `playground.hiring_interviews`)
9. `first_subscription_created_at` — First ever subscription created (not necessarily a trial conversion; some companies subscribe directly)

**Filters**:
- Only includes companies with at least one of: `first_draft_at`, `first_job_posted_at`, or `first_zsp_visit_at` (i.e. any V2 engagement)
- All milestones use `hiring_version = 2`

**Data Sources**: `postgres.hiring_job_requests`, `postgres.hiring_job_applications`, `playground.mm_hiring_product`, `playground.hiring_interviews`, `business_users.hiring.hiring_assistant_usage`, `business_users.hiring.job_post_history_by_day`, `postgres.biller_product_subscriptions`, `public.companies`, `public.locations`

#### 10. `business_users.hiring.hiring_subscriptions` (Subscription Status)
**Notebook**: `CREATE hiring_subscriptions`
**Description**: One row per location, showing the most recent subscription and its current status. Includes both active and churned subscriptions in a single table distinguished by `subscription_status`.

**Key Fields**:
- Identifiers: `location_id`, `location_name`, `subscription_id`, `company_id`, `company_name`, `company_uuid`
- Company metrics: `employee_count`, `location_count`
- Pricing: `promo_code`, `stripe_mrr`, `stripe_tier` (Unlimited / Starter / Unlimited Annual)
- Dates: `hiring_subscription_created_at`, `subscription_archived_at`
- Status: `subscription_status` (active if `archived_at IS NULL`, else churned)

**Deduplication**: Uses `ROW_NUMBER() OVER (PARTITION BY l.location_id ORDER BY bps.created_at DESC) = 1` — keeps the **most recent subscription per location**. Locations that churned and re-subscribed will only show their latest record.

**Pricing / MRR Logic**:
```sql
CASE
  WHEN partner_code_id = 'TRY'                                  THEN 0
  WHEN bps.product_id = 925 AND partner_code_id = 'MULTILOC1'  THEN 149
  WHEN bps.product_id = 925 AND partner_code_id = 'MULTILOC2'  THEN 100
  WHEN bps.product_id = 925 AND partner_code_id = 'MULTILOC3'  THEN 75
  WHEN bps.product_id = 925 AND partner_code_id IS NULL         THEN 199
  WHEN bps.product_id = 1058                                    THEN 30
  WHEN bps.product_id = 1057                                    THEN 99
  ELSE 199
END AS stripe_mrr
```

**Discount ID Filter**: `ad.discount_id IN (7535, 7663, 7664, 7665)`

**Data Sources**: `postgres.biller_product_subscriptions`, `public.locations`, `public.companies`, `postgres.applied_discounts`, `postgres.discounts`

### Pipeline Dependencies

**Dependency Chain**:
1. **Base tables** (run first):
   - `hb_company_profile` - Homebase engagement
   - `hiring_assistant_usage` - V2 usage stats
   - `company_last_12_months_hiring_stats` - Historical hiring
   - `job_post_history_by_day` - Daily job metrics
   - `job_post_level_details` - Simple job aggregations
   - `jobs_with_metadata` - Job-level details
   - `hiring_subscriptions` - Subscription status per location (most recent sub)

2. **ML-dependent** (requires company_last_12_months_hiring_stats):
   - `ml_hiring_intelligence` - Pattern classification and predictions

3. **Milestone-dependent** (requires hiring_assistant_usage, job_post_history_by_day):
   - `company_hiring_milestones` - Value milestone timestamps per company

4. **Master aggregation** (requires all above):
   - `aggregate_hiring_profile` - Combines all profiles with ICP logic + `is_target_segment`

## Looker/BI Setup

### Connection
**Redshift** - All Looker views connect to the Redshift data warehouse

### Key Explores

#### 1. `hiring_job_posts_v2`
**Location**: `Homebase.model.lkml`
**Label**: "Hiring Job Posts & Applications"
**Group**: "Hiring V2"
**Description**: Main explore for analyzing job posts with applications and interview scheduling funnel

**Base View**: `hiring_job_posts_v2` (derived table)
- Filters for `hiring_version = 2` only
- Pre-aggregates application metrics (counts for applications, top matches, screeners, interviews)
- Calculates `is_first_job_post` flag using window functions
- Joins to syndication settings and manual Craigslist boost data

**Connected Views**:
- `users` - Job creation user info (joined on created_by_id)
- `hiring_applications_v2` - Applications (one-to-many, filtered by owner_type = 'Hiring::JobRequest')
- `locations_v2` - Location current status (many-to-one)
- `companies_v2` - Company current status (via locations)
- `active_paying_history` - APH status on post date (joined on location_id + created_date)
- `hiring_trials` - Trial information (via company_uuid)
- `hiring_subscriptions` - Subscription status (on location_id)
- `hiring_company_syndication_settings` - Company syndication settings (via company_id)
- `hiring_job_status_by_day` - Daily job metrics (one-to-many on job_post_id)
- `mrr_score_model` - MRR predictions (via company_id)

#### 2. `hiring_assistant_sales_opportunities`
**Location**: `Homebase.model.lkml`
**Label**: "Hiring Assistant Sales Opportunities"
**Group**: "Hiring V2"
**Description**: Sales opportunities with call metrics and company context

**Base View**: `hiring_assistant_sales_opportunities` (derived table)
- Joins Salesforce opportunities to hiring data
- Tracks trial activation and first job posts
- Calculates sales call metrics (meaningful connects at 2min and 5min thresholds)
- Measures time from trial start to various milestones

**Connected Views**:
- `locations_v2` - Location data (via company_id)
- `companies_v2` - Company data (on company_id)
- `sales_team_mapping` - Sales rep info (on rep_email)
- `active_paying_history` - APH status on opportunity created date (joined on company_id + date)

### Important Looker Views

#### `hiring_job_posts_v2`
**Type**: Derived Table
**Source**: `postgres.hiring_job_requests`

**Key Logic**:
```sql
-- Filters for V2 only
WHERE hiring_version = 2 AND l.location_id IS NOT NULL

-- Application metrics subquery
LEFT JOIN (
  SELECT owner_id,
    COUNT(DISTINCT hja.id) AS application_count,
    COUNT(DISTINCT CASE WHEN hp.is_top_match = 'true' THEN hja.id END) AS top_match_count,
    COUNT(DISTINCT CASE WHEN hp.screener_opened_timestamp IS NOT NULL THEN hja.id END) AS screener_started_count,
    COUNT(DISTINCT CASE WHEN hp.screener_completed_timestamp IS NOT NULL THEN hja.id END) AS screener_completed_count,
    COUNT(DISTINCT CASE WHEN hi.id IS NOT NULL THEN hja.id END) AS scheduled_interview_count
  FROM postgres.hiring_job_applications hja
  LEFT JOIN playground.hiring_product hp ON hp.application_id = hja.id
  LEFT JOIN replica.hiring_interviews hi ON hi.application_id = hja.id
  WHERE hja.owner_type = 'Hiring::JobRequest'
  GROUP BY owner_id
) app_metrics ON app_metrics.owner_id = hjr.id
```

**Key Dimensions**:
- `job_post_id` - Primary key (hiring_job_requests.id)
- `title`, `description` - Job details
- `status` - Job status
- `billing_plan` - trial vs subscription
- Date dimensions: `created`, `updated`, `activated`, `expires`, `archived`, `rejected`, `flagged`, `effective_posted`
- Status flags: `is_posted`, `is_activated`, `is_flagged`, `is_rejected`, `is_archived`
- `is_first_job_post` - Whether first job for location
- `is_reposted` - Whether reposted from previous job
- Application metrics: `application_count`, `top_match_count`, `screener_started_count`, `screener_completed_count`
- Bucketed dimensions: `application_bucket`, `top_match_bucket`, `screener_started_bucket`, `screener_completed_bucket`
- Partner toggles: `partner_toggle_indeed`, `partner_toggle_zip_recruiter`, `partner_toggle_google_jobs`, `partner_toggle_walk_in`, `partner_toggle_your_network`
- `manually_boosted_to_craigslist` - Manual boost flag
- `job_health` - Healthy (20+ apps, 5+ matches), Medium (10+ apps), Not Healthy (<10 apps)

**Key Measures**:
- `count_job_posts` - Count distinct job posts
- `count_locations` - Count distinct locations

#### `hiring_applications_v2`
**Type**: Derived Table
**Source**: `postgres.hiring_job_applications`

**Key Logic**:
```sql
SELECT DISTINCT
  hja.id AS application_id,
  hja.owner_id AS job_post_id,
  hja.source AS application_source,
  hp.is_top_match,
  hp.screener_opened_timestamp,
  hp.screener_completed_timestamp,
  CASE WHEN COUNT(DISTINCT hi.id) > 0 THEN TRUE ELSE FALSE END AS has_scheduled_interview
FROM postgres.hiring_job_applications hja
LEFT JOIN playground.hiring_product hp ON hp.application_id = hja.id
LEFT JOIN replica.hiring_interviews hi ON hi.application_id = hja.id
GROUP BY ...
```

**Key Dimensions**:
- `application_id` - Primary key
- `job_post_id` - Foreign key to job post
- `application_source` - Source channel (Indeed, ZipRecruiter, Homebase Career Site, Craigslist)
- `application_state` - Application state
- Date dimensions: `application_created`, `screener_link_sent`, `screener_started`, `screener_completed`
- Flags: `screener_started`, `screener_completed`, `is_top_match`, `has_scheduled_interview`
- Time to action: `hours_to_screener_start`, `hours_to_screener_complete`, `days_job_activated_to_application`, `days_job_activated_to_top_match`

**Key Measures**:
- `count_applications` - Total applications
- `count_screeners_started`, `count_screeners_completed` - Screener funnel
- `count_top_matches` - Top match applications
- `count_scheduled_interviews` - Applications with interviews
- `count_top_match_interviews` - Top matches with interviews
- Conversion rates: `pct_screeners_started`, `pct_screeners_completed`, `pct_top_matches`, `top_match_rate_overall`, `top_match_schedule_interview_rate`, `applications_schedule_interview_rate`
- Time metrics: `median_hours_to_screener_start`, `median_hours_to_screener_complete`

#### `hiring_job_status_by_day`
**Type**: Derived Table
**Purpose**: Daily time series of job metrics with cumulative and daily values

**Key Logic**:
- Creates date spine from activation date to current date
- Calculates cumulative metrics using window functions
- Tracks both daily additions and cumulative totals
- Computes job health status at each point in time

**Key Dimensions**:
- `job_id`, `reporting_date` - Composite primary key
- `job_age_days` - Days since activation
- `is_expiration_date`, `is_first_job_post` - Flags
- `job_health_status` - Healthy/Medium/Unhealthy based on cumulative metrics
- `job_age_bucket` - Tiered buckets (1, 3, 7, 14, 30 days)
- Cumulative: `application_count`, `top_match_count`, `screener_started_count`, `screener_completed_count`, `scheduled_interview_count`
- Daily: `applications_added_today`, `top_matches_added_today`, `screeners_started_today`, `screeners_completed_today`, `interviews_scheduled_today`

**Key Measures**:
- `count_active_jobs` - Jobs live on reporting date
- Cumulative totals: `total_applications`, `total_top_matches`, `total_screeners_started`, `total_screeners_completed`, `total_interviews_scheduled`
- Cumulative averages: `avg_applications`, `avg_top_matches`
- Daily totals: `total_applications_added`, `total_top_matches_added`, `total_screeners_started_daily`
- Conversion rates: `screener_completion_rate`, `interview_rate`, `top_match_rate`
- Health counts: `count_healthy_jobs`, `count_medium_jobs`, `count_unhealthy_jobs`, `pct_healthy_jobs`

#### `hiring_subscriptions`
**Type**: Derived Table
**Source**: `postgres.biller_product_subscriptions`
**Filter**: `subscription_type = 'hiring_assistant'`

**Key Dimensions**:
- `subscription_id` - Primary key
- `location_id` - Foreign key
- Date dimensions: `subscription_created`, `subscription_archived`
- Flags: `has_subscription_ever`, `is_subscription_active` (archived_at IS NULL)

**Key Measures**:
- `count_subscriptions` - Total subscriptions
- `count_active_subscriptions` - Currently active
- `count_archived_subscriptions` - Churned subscriptions

#### `hiring_trials`
**Type**: Derived Table
**Source**: `postgres.hiring_company_free_trials`
**Logic**: Uses `ROW_NUMBER() OVER (PARTITION BY company_uuid ORDER BY expires_at DESC)` to get most recent trial per company

**Key Dimensions**:
- `trial_id` - Primary key
- `company_uuid` - Foreign key
- Date dimensions: `trial_started`, `trial_expires`
- `is_currently_in_trial` - Active trial flag (between start and expiration)
- `trial_days_remaining` - Days until expiration (negative if expired)

#### `hiring_assistant_sales_opportunities`
**Type**: Derived Table (Complex)
**Sources**: Joins Salesforce opportunities, hiring data, trial data, and call logs

**Key Dimensions**:
- `opportunity_id` - Primary key
- `company_id`, `uuid`, `rep_email`, `rep_name` - Identifiers
- `stage`, `source`, `amount` - Opportunity details
- Dates: `opportunity_created`, `close`, `closed_won`, `closed_lost`, `trial_start`, `trial_end`, `first_hiring_assistant_job_draft`, `first_hiring_assistant_job_post`
- Flags: `is_won`, `is_closed`, `had_meaningful_connect_2min`, `had_meaningful_connect_5min`
- Call metrics: `total_calls`, `meaningful_connects_2min`, `meaningful_connects_5min`, `days_to_first_connect_2min`, `days_to_first_connect_5min`
- Categorizations: `call_engagement_level`, `connect_outcome_2min`, `connect_outcome_5min`

**Key Measures**:
- Counts: `count`, `count_won`, `count_closed`, `count_with_calls`, `count_with_connect_2min`, `count_with_connect_5min`
- Amounts: `total_amount`, `total_amount_won`
- Rates: `win_rate`, `connect_rate_2min`, `connect_rate_5min`, `pct_opps_with_calls`
- Call averages: `avg_calls_per_opp`, `median_calls_per_opp`, `avg_days_to_first_connect_2min`, `median_days_to_first_connect_2min`

#### `hiring_company_syndication_settings`
**Type**: Direct Table
**Source**: `postgres.hiring_settings`

**Key Dimensions**:
- `company_id` - Primary key
- `syndicatable` - Overall syndication flag
- `indeed_syndication` - Indeed specific flag
- `zip_recruiter_syndication` - ZipRecruiter specific flag

### Looker vs Databricks Differences

**Looker (Redshift)**:
- Uses derived tables with pre-aggregated metrics for performance
- Leverages LookML for reusable dimensions and measures
- Focuses on business user self-service with curated explores
- Cleaner data model with denormalized metrics in base views
- Time series analysis via `hiring_job_status_by_day` derived table

**Databricks**:
- More flexible for ad-hoc analysis and data science
- Access to raw event-level data
- Better for complex SQL queries and data transformations
- Can join across multiple schemas (postgres, playground, ext_firehose, business_users)
- Used for dashboard definitions and complex analytics

**Shared Tables** (same across both):
- `postgres.hiring_job_requests`
- `postgres.hiring_job_applications`
- `postgres.biller_product_subscriptions`
- `postgres.hiring_company_free_trials`
- `public.locations`, `public.companies`, `public.users`

**Platform-Specific**:
- Looker-specific: Derived tables with pre-aggregated metrics
- Databricks-specific: `business_users.hiring.job_post_history_by_day` (pre-aggregated table), direct access to `playground.mm_hiring_product`

## Metrics & KPIs

### Core Metrics

**Volume Metrics**
- **New Job Postings**: `count(distinct hjr.id)` where status != 'draft' and (activated_at or flagged_at) is not null
- **Applications**: `count(distinct hja.id)` per job or time period
- **Screener Opens**: Applications with `screener_opened_timestamp` not null
- **Screener Completes**: Applications with `screener_completed_timestamp` not null
- **Top Matches**: Applications where `is_top_match = TRUE`
- **Scheduled Interviews**: Applications with at least one interview record
- **Job Posts Boosted**: Jobs with at least one boost record

**Funnel Metrics**
- **Screener Open Rate**: `screeners_opened / applications`
- **Screener Completion Rate**: `screeners_completed / screeners_opened`
- **Top Match Rate (from completions)**: `top_matches / screeners_completed`
- **Top Match Rate (overall)**: `top_matches / applications`
- **Interview Schedule Rate**: `scheduled_interviews / applications`
- **Top Match Interview Rate**: `scheduled_interviews / top_matches`

**Job Health Metrics**
- **Healthy Jobs**: 20+ applications AND 5+ top matches by Day 5
- **Medium Jobs**: 10+ applications but not Healthy by Day 5
- **Unhealthy Jobs**: <10 applications by Day 5
- **% Healthy Jobs**: `healthy_jobs / total_jobs`

**Time-based Alerts**
- **Jobs with <1 applicant in 24 hours**: Active jobs with 0 applications and >24 hours old
- **Jobs with <10 applicants in 72 hours**: Active jobs with <10 applications and >72 hours old

**Subscription Metrics**
- **Active Subscriptions**: Subscriptions where `archived_at is null`
- **MRR (Monthly Recurring Revenue)**: Sum of subscription values (see pricing logic)
- **ARR (Annual Recurring Revenue)**: `MRR * 12`
- **New Subscriptions**: Subscriptions created in period
- **Churned Subscriptions**: Subscriptions archived in period
- **Net MRR Change**: `new_mrr - churned_mrr`
- **Trial Conversion Rate**: `subscribed_companies / trial_started_companies`

**Hiring Attribution Metrics**
- **Hires Attributed**: Applicants matched to new team members added within 90 days
- **Hire Attribution Rate**: `hires / applications`

### Metric Definitions

**Application Count Variations**
- **All Applications**: No time filter on `hja.created_at`
- **Applications by Day 7**: Filter `hja.created_at between activated_at and dateadd(DAY, 7, created_at)`
- **Applications by Day 14**: Filter `hja.created_at between activated_at and dateadd(DAY, 14, created_at)`

**Time Windows**
- **24 hours**: `(unix_timestamp(current_timestamp()) - unix_timestamp(created_at)) / 3600.0 > 24`
- **72 hours**: `(unix_timestamp(current_timestamp()) - unix_timestamp(created_at)) / 3600.0 > 72`
- **Last 30 days**: `created_at >= date_add(day, -30, current_date)`

**Date Conversions**
- Microsecond timestamps: `timestamp_micros(created_at)::date`
- EST timezone conversion: `from_utc_timestamp(timestamp, 'America/New_York')`

### SLAs & Thresholds

**Job Health Thresholds**
- Healthy: 20+ applications AND 5+ top matches by Day 5
- Medium: 10+ applications by Day 5
- Unhealthy: <10 applications by Day 5

**Alert Thresholds**
- 0 applications in 24 hours (for active jobs)
- <10 applications in 72 hours (for active jobs)

## Data Models & Business Logic

### Domain Concepts

**Hiring Version**
- **V2 = Hiring Assistant** (current product, launched **2025-06-18**)
- **V1 = Old Hiring Product** (legacy, not relevant for current analysis)
- **CRITICAL: Always filter for `hiring_version = 2` unless explicitly stated otherwise**
- All queries should filter for dates `>= '2025-06-18'` (V2 launch date)
- When someone says "Hiring Assistant" they mean V2 - always include V2 filters by default

**Job Post Lifecycle**
1. Created (`created_at`)
2. Activated (`activated_at` not null) OR Flagged (`flagged_at` not null)
3. Status changes: draft → active → (potentially other states)
4. Exclude drafts: `status != 'draft'`
5. Only count valid jobs: `(activated_at is not null or flagged_at is not null)`

**Application Lifecycle**
1. Application created (`hja.created_at`)
2. Screener opened (`screener_opened_timestamp`)
3. Screener completed (`screener_completed_timestamp`)
4. Top match flagged (`is_top_match = true`)
5. Interview scheduled (`hiring_interviews` record exists)

**Subscription Lifecycle**
1. Trial started (in `hiring_company_free_trials`)
2. Subscription created (`bps.created_at`)
3. Active subscription (`archived_at is null`)
4. Churned subscription (`archived_at is not null`)

### Status Flows

**Job Request Status**
- **draft**: Job created but not published (EXCLUDED from most queries)
- **active**: Job is live and accepting applications (PRIMARY status for analysis)
- Other statuses exist but are not explicitly filtered in most queries

**Billing Plan Status**
- **trial**: Free trial period
- **subscription**: Paid subscription (various product IDs)

### Attribution Logic

**Hiring Attribution**
Uses fuzzy name matching (Levenshtein distance) to connect applicants to new team members:
```sql
levenshtein(lower(ha.first_name), lower(get_json_object(tce.profile_after, '$.first_name'))) <= 2
AND levenshtein(lower(ha.last_name), lower(get_json_object(tce.profile_after, '$.last_name'))) <= 2
AND substr(lower(ha.last_name), 1, 1) = substr(lower(get_json_object(tce.profile_after, '$.last_name')), 1, 1)
```

**Time Window**: Match team members added within 90 days of application:
```sql
tce.created_at between hja.created_at and DATEADD(DAY, 90, hja.created_at)
```

**Event Types**: Match on `type in ('job_created', 'user_created')`

**Deduplication**: Count distinct people by normalized name:
```sql
LOWER(TRIM(added_first_name)) || ' ' || LOWER(TRIM(added_last_name))
```

### Important Joins and Relationships

**Core Join Pattern**
```sql
FROM hiring_job_requests hjr
  LEFT JOIN public.locations l ON l.location_id = hjr.location_id
  LEFT JOIN public.companies c ON c.company_id = l.company_id
  LEFT JOIN hiring_job_applications hja
    ON hja.owner_id = hjr.id
    AND hja.owner_type = 'Hiring::JobRequest'
  LEFT JOIN mm_hiring_product hps
    ON hps.application_id = hja.id
  LEFT JOIN hiring_interviews hi
    ON hi.application_id = hja.id
  LEFT JOIN hiring_applicants ha
    ON ha.id = hja.hiring_applicant_id
```

**Subscription Join Pattern**
```sql
FROM biller_product_subscriptions bps
  LEFT JOIN public.locations l ON l.location_id = bps.owner_id
  LEFT JOIN public.companies c ON c.company_id = l.company_id
  LEFT JOIN applied_discounts ad
    ON ad.owner_id = l.location_id
    AND ad.owner_type = 'Location'
    AND ad.subscription_id = bps.subscription_id
    AND ad.discount_id in (7535, 7663, 7664, 7665)
  LEFT JOIN discounts d ON d.id = ad.discount_id
  LEFT JOIN pricing_products pp ON pp.id = bps.product_id
```

**Trial Conversion Join Pattern**
```sql
FROM public.companies c
  LEFT JOIN public.locations l ON l.company_id = c.company_id
  LEFT JOIN ext_homebase1.homebase1_public_hiring_company_free_trials hcft
    ON hcft.company_uuid = c.uuid
  LEFT JOIN postgres.biller_product_subscriptions bps
    ON bps.owner_id = l.location_id
    AND bps.owner_type = 'Location'
    AND bps.subscription_type = 'hiring_assistant'
```

**Boost Join**
```sql
LEFT JOIN postgres.hiring_job_request_boosts hjb
  ON hjb.hiring_job_request_id = hjr.id
```

**Settings Join**
```sql
LEFT JOIN postgres.hiring_settings hs
  ON hs.company_id = l.company_id
```

## MRR/ARR Pricing Logic

### Product IDs and Base Pricing
- **Product ID 1058**: Starter plan ($30/month)
- **Product ID 1057**: Unlimited Annual ($99/month)
- **Product ID 925**: Unlimited Monthly (variable based on promo code)

### Discount/Promo Code Pricing (Product 925)
- **'TRY'**: $0/month (trial)
- **'MULTILOC1'**: $149/month
- **'MULTILOC2'**: $100/month
- **'MULTILOC3'**: $75/month
- **No promo code**: $199/month (default)

### MRR Calculation Logic
```sql
CASE
  WHEN partner_code_id = 'TRY'                                  THEN 0
  WHEN bps.product_id = 925 AND partner_code_id = 'MULTILOC1'  THEN 149
  WHEN bps.product_id = 925 AND partner_code_id = 'MULTILOC2'  THEN 100
  WHEN bps.product_id = 925 AND partner_code_id = 'MULTILOC3'  THEN 75
  WHEN bps.product_id = 925 AND partner_code_id IS NULL         THEN 199
  WHEN bps.product_id = 1058                                    THEN 30
  WHEN bps.product_id = 1057                                    THEN 99
  ELSE 199
END AS stripe_mrr
```

### ARR Calculation
```sql
Stripe_MRR * 12 AS ARR
```

### MRR/ARR Time Series
Daily/weekly snapshots use date series with cross joins to calculate:
- Active subscriptions at each point in time
- New subscriptions (by `created_at`)
- Churned subscriptions (by `archived_at`)
- Net MRR change (`new_mrr - churned_mrr`)

Filter logic:
```sql
WHERE ds.date >= sd.hiring_subscription_created_at
  AND (sd.subscription_archived_at IS NULL OR ds.date < sd.subscription_archived_at)
```

### Discount IDs
Relevant discount IDs for promo codes: `7535, 7663, 7664, 7665`

## Key Filters and Date Ranges

### Standard Filters

**V2 Launch Filter** (CRITICAL - use in all queries)
```sql
WHERE hjr.created_at >= '2025-06-18'
  AND hjr.hiring_version = 2
```

**Valid Job Posts**
```sql
AND hjr.status != 'draft'
AND l.location_id IS NOT NULL
AND (hjr.activated_at IS NOT NULL OR hjr.flagged_at IS NOT NULL)
```

**Recent Data (Last 30 Days)**
```sql
AND created_at >= date_add(day, -30, current_date)
```

**Subscription Type Filter**
```sql
WHERE bps.subscription_type = 'hiring_assistant'
  AND l.location_id IS NOT NULL
  AND c.company_id IS NOT NULL
```

**Active vs Archived Subscriptions**
```sql
-- Active
AND bps.archived_at IS NULL

-- Archived
AND bps.archived_at IS NOT NULL
```

**Exclusions**
```sql
-- Remove test company
AND l.company_id != 1987234  -- St. Pete Athletic
```

### Time-based Windows

**Day 5 Lag** (for job health metrics)
```sql
WHERE hjr.activated_at::date <= CURRENT_DATE - 5
```

**Day 7 Window** (applications within first week)
```sql
WHERE timestamp_micros(hjr.created_at)::date <= dateadd(DAY, -8, current_date())
AND hja.created_at between timestamp_micros(activated_at)
  and dateadd(DAY, 7, timestamp_micros(hjr.created_at))
```

**Day 14 Window** (applications within first 2 weeks)
```sql
WHERE timestamp_micros(hjr.created_at)::date <= dateadd(DAY, -15, current_date())
AND hja.created_at between timestamp_micros(activated_at)
  and dateadd(DAY, 14, timestamp_micros(hjr.created_at))
```

**Trial to Subscription Timing Analysis**

The preferred cohort is companies that subscribed **after their trial expired** (not from trial start). This captures reactivation/delayed conversion behavior.

**Get most recent trial per company (safe dedup pattern):**
```sql
last_trial AS (
  SELECT
    company_uuid,
    TO_TIMESTAMP(created_at  / 1000000.0) AS trial_started_at,
    TO_TIMESTAMP(expires_at  / 1000000.0) AS trial_expires_at
  FROM ext_homebase1.homebase1_public_hiring_company_free_trials
  QUALIFY ROW_NUMBER() OVER (PARTITION BY company_uuid ORDER BY created_at DESC) = 1
)
```

**Days after expiry calculation:**
```sql
DATEDIFF(day, lt.trial_expires_at, sb.created_at) AS days_after_expiry
-- Only include post-expiry: AND DATEDIFF(day, lt.trial_expires_at, sb.created_at) >= 0
```

**Cohort buckets (days after trial expired):**
```sql
COUNT(DISTINCT CASE WHEN days_after_expiry < 15                             THEN sub_id END) AS expired_0_to_15d,
COUNT(DISTINCT CASE WHEN days_after_expiry >= 15 AND days_after_expiry < 30 THEN sub_id END) AS expired_15_to_30d,
COUNT(DISTINCT CASE WHEN days_after_expiry >= 30 AND days_after_expiry < 45 THEN sub_id END) AS expired_30_to_45d,
COUNT(DISTINCT CASE WHEN days_after_expiry >= 45 AND days_after_expiry < 60 THEN sub_id END) AS expired_45_to_60d,
COUNT(DISTINCT CASE WHEN days_after_expiry >= 60                            THEN sub_id END) AS expired_60_plus
```

**Channel assignment (Sales vs PLG):**

Rules:
- **Sales** = the **first** subscription at a location after a Closed Won SF opportunity with `hiring_connected_rep__c IS NOT NULL`
- **Opp window**: the opp's `closed_won_date_all` must be ≤ `sub created_at + 3 days` (3-day buffer for SF data lag)
- **Resets per opp**: `PARTITION BY (location_id, most_recent_sales_opp_date)` — each new Closed Won opp resets the clock, giving that location one more Sales-attributed subscription
- **Churn + PLG re-subscribe**: if a company churns and resubscribes without a new opp, `rank_after_opp > 1` → attributed as PLG

```sql
-- Step 1: find the most recent qualifying Sales opp per subscription
sub_with_prev_opp AS (
  SELECT
    sb.*,
    MAX(CASE
      WHEN so.current_stage = 'Closed Won'
        AND co.hiring_connected_rep__c IS NOT NULL
        AND so.closed_won_date_all::date <= DATEADD(DAY, 3, sb.hiring_subscription_created_at)
      THEN so.closed_won_date_all::date
    END) AS most_recent_sales_opp_date
  FROM subscription_base sb
  LEFT JOIN bizops.salesforce_opportunities so
    ON so.uuid = sb.company_uuid
    AND so.recordtypeid = '012Po00000FXm4lIAD'
  LEFT JOIN redshift_replica.bizops.crm_opportunity co ON co.id = so.id
  GROUP BY sb.subscription_id, sb.location_id, sb.company_uuid,
           sb.hiring_subscription_created_at, sb.product_id, sb.partner_code_id
),
-- Step 2: rank subs per (location, opp) — only rank=1 is Sales-attributed
sub_ranked AS (
  SELECT *,
    ROW_NUMBER() OVER (
      PARTITION BY location_id, most_recent_sales_opp_date
      ORDER BY hiring_subscription_created_at ASC
    ) AS rank_after_opp
  FROM sub_with_prev_opp
),
-- Step 3: assign channel
subscription_data AS (
  SELECT *,
    CASE
      WHEN most_recent_sales_opp_date IS NOT NULL AND rank_after_opp = 1 THEN 'Sales'
      ELSE 'PLG'
    END AS channel
  FROM sub_ranked
)
```

Notes:
- `subscription_base` uses `SELECT DISTINCT` + `LEFT JOIN applied_discounts` to avoid row fan-out from multiple discount records per subscription
- `bizops.salesforce_opportunities` record type filter: `recordtypeid = '012Po00000FXm4lIAD'` (Hiring only)
- Databricks: `DATEADD` units must be unquoted — `DATEADD(DAY, 3, ...)` not `DATEADD('day', 3, ...)`

**Discount/promo dedup pattern** (avoids row fan-out from multiple discount records):
```sql
discount_info AS (
  SELECT ad.subscription_id, MAX(d.partner_code_id) AS promo_code
  FROM postgres.applied_discounts ad
    JOIN postgres.discounts d ON d.id = ad.discount_id
  WHERE ad.owner_type = 'Location'
    AND ad.discount_id IN (7535, 7663, 7664, 7665)
  GROUP BY ad.subscription_id
)
```

### Weekly Aggregations
```sql
date_trunc('week', timestamp_micros(created_at)) AS week
-- OR for end-of-week snapshots
WHERE dayofweek(ds.date) = 1  -- Sunday
```

### Ranking/Sequencing

**First vs Subsequent Job Posts**
```sql
ROW_NUMBER() OVER (PARTITION BY hjr.location_id ORDER BY hjr.created_at) as job_rank
-- Where job_rank = 1 is first job, >1 is subsequent
```

## Data Quality & Gotcas

### Known Issues

**Test Data**
- Company ID 1987234 (St. Pete Athletic) should be excluded from production metrics

**Fake/Demo Companies & Locations**
- **Fake Companies**: If a `company_id` doesn't exist in `public.companies`, it's a fake demo company and should be excluded
- **Fake Locations**: If a `location_id` doesn't exist in `public.locations`, it's a fake location and should be excluded
- **Always use INNER JOIN** (or check for NOT NULL) when joining to `public.companies` or `public.locations` to filter out fake data
- Example exclusion pattern:
  ```sql
  INNER JOIN public.companies c ON c.company_id = l.company_id
  INNER JOIN public.locations l ON l.location_id = hjr.location_id
  -- OR check for nulls after LEFT JOIN:
  WHERE c.company_id IS NOT NULL AND l.location_id IS NOT NULL
  ```

**Timestamp Formats**
- Some timestamps are in microseconds (require `timestamp_micros()` conversion)
- Some are standard Unix timestamps (require `TO_TIMESTAMP(x / 1000000.0)`)
- Timezone conversions needed for EST reporting

### Edge Cases

**Owner Type Validation**
- Always include `owner_type = 'Hiring::JobRequest'` when joining applications to jobs
- Owner type must match subscription owner: `owner_type = 'Location'` for subscriptions

**Null Handling**
- Jobs can have `activated_at` OR `flagged_at` - use OR condition
- Active subscriptions have `archived_at IS NULL`
- Promo codes can be NULL (use COALESCE or handle in CASE)

**Distinct Counting**
- Use `count(distinct case when condition then id else null end)` pattern for conditional counts
- Don't count on nulls

**Date Comparisons**
- Use consistent casting: `::date` for date comparisons
- Be explicit about `>= vs >` and `< vs <=` for time windows

### Things to Watch For

**V2 Launch Date**: Always filter for dates >= 2025-06-18 for V2 metrics

**Draft Jobs**: Always exclude `status = 'draft'` or use `status != 'draft'`

**Location Validation**: Always include `l.location_id IS NOT NULL` to avoid orphaned records

**Activation Requirement**: Include `(activated_at IS NOT NULL OR flagged_at IS NOT NULL)` for valid job counts

**Microsecond Timestamps**: Remember to use `timestamp_micros()` for job request timestamps

**Subscription Owner**: Subscriptions are at location level, not company level

**MRR Calculations**: Partner codes affect pricing - always join to discounts table

**Time Windows**: Be clear about whether using application created date or job created date

**Fuzzy Matching**: Hiring attribution uses Levenshtein distance - not exact matches

**Aggregation Order**: When using CTEs, be mindful of GROUP BY before JOIN vs JOIN before GROUP BY

## Common Queries & Patterns

### Job Posting Queries

**Basic Job Listing**
```sql
SELECT
  timestamp_micros(hjr.created_at)::date as job_post_created_at,
  hjr.id as job_post_id,
  hjr.title,
  hjr.status,
  l.location_id,
  l.company_id,
  COUNT(DISTINCT hja.id) as applications
FROM playground.hiring_job_requests hjr
  LEFT JOIN public.locations l ON l.location_id = hjr.location_id
  LEFT JOIN postgres.hiring_job_applications hja
    ON hja.owner_id = hjr.id
    AND hja.owner_type = 'Hiring::JobRequest'
WHERE timestamp_micros(hjr.created_at)::date >= '2025-06-18'
  AND hjr.hiring_version = 2
  AND hjr.status != 'draft'
  AND l.location_id IS NOT NULL
  AND (hjr.activated_at IS NOT NULL OR hjr.flagged_at IS NOT NULL)
GROUP BY 1,2,3,4,5,6
```

**Job Volume Over Time**
```sql
SELECT
  date_trunc('DAY', timestamp_micros(hjr.created_at))::date as date,
  COUNT(DISTINCT hjr.id) as new_job_postings
FROM playground.hiring_job_requests hjr
  LEFT JOIN public.locations l ON l.location_id = hjr.location_id
WHERE timestamp_micros(hjr.created_at)::date >= '2025-06-18'
  AND hjr.hiring_version = 2
  AND hjr.status != 'draft'
  AND l.location_id IS NOT NULL
  AND (hjr.activated_at IS NOT NULL OR hjr.flagged_at IS NOT NULL)
GROUP BY 1
ORDER BY 1
```

### Application & Screener Queries

**Application Volume by Source**
```sql
SELECT
  date_trunc('DAY', hja.created_at)::date as date,
  hja.source,
  COUNT(DISTINCT hja.id) as applications
FROM postgres.hiring_job_requests hjr
  LEFT JOIN public.locations l ON l.location_id = hjr.location_id
  LEFT JOIN postgres.hiring_job_applications hja
    ON hja.owner_id = hjr.id
    AND hja.owner_type = 'Hiring::JobRequest'
WHERE hja.created_at >= '2025-06-18'
  AND hjr.hiring_version = 2
  AND hjr.status != 'draft'
  AND l.location_id IS NOT NULL
GROUP BY 1, 2
ORDER BY 1, 2
```

**Screener Funnel Metrics**
```sql
SELECT
  COUNT(DISTINCT application_id) as applications,
  COUNT(DISTINCT CASE WHEN screener_opened_at_est IS NOT NULL
    THEN application_id END) as screeners_opened,
  COUNT(DISTINCT CASE WHEN screener_completed_at_est IS NOT NULL
    THEN application_id END) as screeners_completed,
  COUNT(DISTINCT CASE WHEN is_top_match = TRUE
    THEN application_id END) as top_matches,
  screeners_opened / applications as pct_screeners_opened,
  screeners_completed / screeners_opened as pct_screeners_completed,
  top_matches / screeners_completed as pct_top_matches
FROM playground.mm_hiring_product
```

### Subscription & Revenue Queries

**Active Subscriptions**
```sql
SELECT
  l.location_id,
  c.company_id,
  bps.subscription_id,
  pp.name as product,
  d.partner_code_id as promo_code,
  bps.created_at::date as subscription_created_at,
  CASE
    WHEN d.partner_code_id = 'TRY' THEN 0
    WHEN bps.product_id = 1058 THEN 30
    WHEN bps.product_id = 1057 THEN 99
    WHEN bps.product_id = 925 AND d.partner_code_id = 'MULTILOC1' THEN 149
    WHEN bps.product_id = 925 AND d.partner_code_id = 'MULTILOC2' THEN 100
    WHEN bps.product_id = 925 AND d.partner_code_id = 'MULTILOC3' THEN 75
    WHEN bps.product_id = 925 THEN 199
    ELSE 199
  END AS MRR
FROM postgres.biller_product_subscriptions bps
  LEFT JOIN public.locations l ON l.location_id = bps.owner_id
  LEFT JOIN public.companies c ON c.company_id = l.company_id
  LEFT JOIN postgres.applied_discounts ad
    ON ad.owner_id = l.location_id
    AND ad.subscription_id = bps.subscription_id
  LEFT JOIN postgres.discounts d ON d.id = ad.discount_id
  LEFT JOIN postgres.pricing_products pp ON pp.id = bps.product_id
WHERE bps.subscription_type = 'hiring_assistant'
  AND bps.archived_at IS NULL
  AND l.location_id IS NOT NULL
```

### CTEs and Advanced Patterns

**Job Health Analysis**
```sql
WITH job_day_5_metrics AS (
  SELECT
    hjr.id AS job_id,
    h.application_count AS day_5_applications,
    h.top_match_count AS day_5_top_matches,
    CASE
      WHEN h.application_count >= 20 AND h.top_match_count >= 5 THEN 'Healthy'
      WHEN h.application_count >= 10 THEN 'Medium'
      ELSE 'Unhealthy'
    END AS health_tier
  FROM postgres.hiring_job_requests hjr
  INNER JOIN business_users.hiring.job_post_history_by_day h
    ON h.id = hjr.id
    AND h.job_age_days = 5
  WHERE hjr.hiring_version = 2
    AND hjr.activated_at::date <= CURRENT_DATE - 5
)
SELECT
  health_tier,
  COUNT(job_id) as job_count
FROM job_day_5_metrics
GROUP BY 1
```

## Resources

- **Looker Repo**: `/Users/ntang/Documents/looker`
- **Looker Model**: `Homebase.model.lkml`
- **Key Looker Explores**:
  - `hiring_job_posts_v2` - Main explore for job posts and applications
  - `hiring_assistant_sales_opportunities` - Sales opportunities and call metrics
- **Key Looker Views**:
  - `hiring_job_posts_v2.view.lkml` (hiring_job_request_v2.view.lkml)
  - `hiring_applications_v2.view.lkml`
  - `hiring_job_status_by_day.view.lkml`
  - `hiring_subscriptions.view.lkml`
  - `hiring_trials.view.lkml`
  - `hiring_assistant_sales_opportunities.view.lkml` (hiring_assistant_opportunities.view.lkml)
  - `hiring_company_syndication_settings.view.lkml`
- **Databricks Dashboard**: https://homebase-staging.cloud.databricks.com/dashboardsv3/01f04cb02743127cbfe153cf42c4e1e4/published
- **Databricks Pipelines**: `/Shared/Hiring Assistant Pipelines/Hiring Profile`
  - **README**: `/Shared/Hiring Assistant Pipelines/Hiring Profile/README` ([Confluence](https://joinhomebase.atlassian.net/wiki/spaces/Hiring/pages/4720689172/Hiring+Profile+Data+Tables))
  - **Pipeline Notebooks**: `/Shared/Hiring Assistant Pipelines/Hiring Profile/Table Creation Pipeline`
- **Aggregated Tables** (business_users.hiring schema):
  - `aggregate_hiring_profile` - Master ICP profile
  - `job_post_history_by_day` - Daily job metrics time series
  - `job_post_level_details` - Simple job aggregations
  - `ml_hiring_intelligence` - ML pattern classification & role predictions
  - `hb_company_profile` - Homebase engagement metrics
  - `company_last_12_months_hiring_stats` - Historical hiring activity (L12M)
  - `hiring_assistant_usage` - V2 usage stats
  - `jobs_with_metadata` - Job-level details with health flag
- **SQL Queries**: `/Users/ntang/Documents/team-docs/hiring_dashboard_queries.sql`
- **V2 Launch Date**: 2025-06-18
- **Product IDs**:
  - 925 = Unlimited Monthly
  - 1057 = Unlimited Annual
  - 1058 = Starter
- **Discount IDs**: 7535, 7663, 7664, 7665
- **Promo Codes**: TRY, MULTILOC1, MULTILOC2, MULTILOC3

---

*Last updated: 2026-02-26 (Looker context and Databricks aggregated tables added)*
