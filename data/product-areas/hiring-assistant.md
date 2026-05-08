# Hiring Assistant — Data Field Guide

> For product context (what HA is, lifecycle, customers, OKRs), see `domains/hiring-assistant/`.
> For metric definitions, see `data/glossary.md`.

## When to Use This File

Use when querying: job posting volume, application funnel, screener and top-match metrics,
trial conversion, subscription/MRR reporting, or hiring attribution.

**Always apply:**
- `hiring_version = 2` — V2 = Hiring Assistant, launched 2025-06-18. V1 = legacy, ignore.
- `status != 'draft'` — for valid job counts
- INNER JOIN `public.locations` and `public.companies` — excludes fake/demo data

## Key Metrics

| Metric | Computation | Notes |
|--------|-------------|-------|
| New Job Posts | `COUNT(DISTINCT hjr.id)` | WHERE status != 'draft' AND (activated_at OR flagged_at) IS NOT NULL |
| Applications | `COUNT(DISTINCT hja.id)` | Per job or time period |
| Screener Open Rate | `screener_opens / NULLIF(applications, 0)` | % applicants who opened screener |
| Screener Completion Rate | `screener_completes / NULLIF(screener_opens, 0)` | % openers who finished |
| Top Match Rate (overall) | `top_matches / NULLIF(applications, 0)` | % apps flagged as top match |
| Top Match Rate (from completes) | `top_matches / NULLIF(screener_completes, 0)` | % completions → top match |
| Interview Schedule Rate | `scheduled_interviews / NULLIF(applications, 0)` | % apps that got an interview |
| % Healthy Jobs | `healthy_jobs / NULLIF(total_jobs, 0)` | Jobs meeting health threshold by Day 5 |
| Trial Conversion Rate | `subscribed_companies / NULLIF(trial_started_companies, 0)` | % trials that converted |
| Active Subscriptions | COUNT WHERE `archived_at IS NULL` | Current paying, per location |
| MRR (net) | SUM of `stripe_mrr` per active location | Actual revenue net of discounts |
| Gross MRR | SUM of `gross_mrr` per active location | List price revenue, ignoring discounts |

## Feature Engagement Definitions

### Healthy Job
- **Measures**: A job with sufficient applicant volume and quality
- **⚠️ Two different thresholds — do not conflate:**
  - **`healthy_job` column** in `business_users.hiring.jobs_with_metadata`: precomputed flag using `>= 15 applicants AND >= 3 top matches` (lifetime counts, no time window). Use `WHERE healthy_job = 1` to filter.
  - **`% Jobs Healthy by Day 5` metric** (tracked in WBR): computed directly as `>= 20 applications AND >= 5 top matches by Day 5`. Use `business_users.hiring.job_post_history_by_day WHERE job_age_days = 5` — do NOT use the `healthy_job` column for this metric.

### Top Match
- **Measures**: Applicants who passed the screener and meet job criteria per ML scoring
- **Column**: `is_top_match = TRUE` in `prod_reporting.hiring.hiring_product`
- **Join**: `application_id = hja.id`

### Screener Completion
- **Measures**: Applicants who opened and finished the screener questionnaire
- **Columns**: `screener_opened_timestamp` (start) and `screener_completed_timestamp` (complete) in `prod_reporting.hiring.hiring_product`
- **Note**: IS NOT NULL = engaged at that step

### Company Lifecycle Milestones
Ordered funnel: ZSP visit → first draft → first job posted → first application → 10th application
→ first top match → first healthy job → first interview → first subscription
- **Source**: `business_users.hiring.company_hiring_milestones` — one row per company, one timestamp per milestone

## Key Tables

| Table | Purpose | Key Notes |
|-------|---------|-----------|
| `postgres.hiring_job_requests` | All V2 job posts | Filter: `hiring_version = 2`, `status != 'draft'`. Also in `playground.hiring_job_requests` (same schema) — use postgres as default. |
| `postgres.hiring_job_applications` | All applications | Join: `owner_id = hjr.id AND owner_type = 'Hiring::JobRequest'` |
| `prod_reporting.hiring.hiring_product` | Screener + top match data | Join: `application_id = hja.id` |
| `prod_reporting.hiring.hiring_interviews` | Interview scheduling | Join: `application_id = hja.id` |
| `postgres.hiring_applicants` | Applicant profiles | Join: `id = hja.hiring_applicant_id` |
| `postgres.biller_product_subscriptions` | Subscription records | Filter: `subscription_type = 'hiring_assistant'`; grain: location |
| `hive_metastore.ext_homebase1_public.hiring_company_free_trials` | Trial start/end per company | Dedup: `QUALIFY ROW_NUMBER() OVER (PARTITION BY company_uuid ORDER BY created_at DESC) = 1` |
| `postgres.hiring_settings` | Company syndication flags | Join: `company_id = l.company_id` |
| `postgres.hiring_job_request_boosts` | Job promotion records | Join: `hiring_job_request_id = hjr.id` |
| `prod_raw.homebase1.hiring_job_applications` | Near-real-time applications (~2hr refresh) | Use instead of `postgres.hiring_job_applications` when recency matters |
| `prod_raw.homebase1.hiring_job_requests` | Near-real-time job posts (~2hr refresh) | Use instead of `postgres.hiring_job_requests` when recency matters |
| `business_users.hiring.aggregate_hiring_profile` | Master company profile (ICP, ML, engagement) | One row per company |
| `business_users.hiring.jobs_with_metadata` | Job-level metrics + health flag | Contains V1 + V2 — always filter `hiring_version = 2` |
| `business_users.hiring.job_post_history_by_day` | Daily time series per job | Date spine from activation to expiration |
| `business_users.hiring.company_hiring_milestones` | Lifecycle milestone timestamps | One row per company |
| `business_users.hiring.hiring_subscriptions` | Most recent subscription per location | Pre-deduped by most recent sub |
| `business_users.hiring.company_last_12_months_hiring_stats` | Historical hiring volume L12M | Aggregated from postgres.jobs |

**Always INNER JOIN dimension tables to filter fake/demo data:**
- `public.locations` — if `location_id` doesn't exist here, it's fake
- `public.companies` — if `company_id` doesn't exist here, it's fake

## Key Business Logic & Caveats

**Applications join requires owner_type**
`hiring_job_applications` uses `owner_id` + `owner_type` — no direct FK. Always join with `AND owner_type = 'Hiring::JobRequest'`.

**Trial timestamps are native — no microsecond conversion**
`hiring_company_free_trials.created_at` and `expires_at` are regular timestamps. Use `::date` directly.

**Trial data quality cutoff (pre-2025-08-27)**
Trial periods before 2025-08-27 were not reliably recorded. When joining jobs to trial windows:
```sql
(jm.activated_at >= trial_started_at OR jm.activated_at <= '2025-08-27')
AND jm.activated_at <= trial_expires_at
```

**Trial starts when first job is posted**
Companies cannot have a trial record without posting at least one V2 job. Exclude fraud-blocked anomalies with `WHERE jobs_posted > 0`.

**MRR pricing logic**
Subscriptions are per location. Net MRR depends on `product_id` + promo code from `applied_discounts → discounts.partner_code_id`. Gross MRR uses list price only (ignores discounts).

| Product ID | Name | Promo Code | Stripe MRR (net) | Gross MRR (list) |
|------------|------|-----------|-----------------|-----------------|
| 925 | Unlimited Monthly | TRY | $0 | $199 |
| 925 | Unlimited Monthly | MULTILOC1 | $149 | $199 |
| 925 | Unlimited Monthly | MULTILOC2 | $100 | $199 |
| 925 | Unlimited Monthly | MULTILOC3 | $75 | $199 |
| 925 | Unlimited Monthly | (none) | $199 | $199 |
| 1057 | Unlimited Annual | — | $99 | $199 |
| 1058 | Starter | — | $30 | $30 |

Promo code discount IDs: `IN (7535, 7663, 7664, 7665)`. Dedup to avoid fan-out: `GROUP BY subscription_id, MAX(partner_code_id)`.

**Channel attribution (Sales vs PLG)**
Sales = first subscription at a location after a Closed Won SF opp with `hiring_connected_rep__c IS NOT NULL` (3-day buffer for SF lag). SF record type: `recordtypeid = '012Po00000FXm4lIAD'` (Hiring only). Churn + re-subscribe without new opp → PLG.

**Hiring attribution**
Fuzzy Levenshtein name match (`<= 2`) between `hiring_applicants` and new team members in `ext_firehose.team_change_events` (event types: `job_created`, `user_created`) added within 90 days of application.

**Exclude test company**
Company ID `1987234` (St. Pete Athletic) — always exclude from production metrics.

## Example SQL Queries

**Job posts with full application funnel**
```sql
SELECT
  hjr.id AS job_post_id,
  hjr.title,
  hjr.activated_at::date AS activated_date,
  l.company_id,
  COUNT(DISTINCT hja.id) AS applications,
  COUNT(DISTINCT CASE WHEN hp.screener_opened_timestamp IS NOT NULL THEN hja.id END) AS screener_opens,
  COUNT(DISTINCT CASE WHEN hp.screener_completed_timestamp IS NOT NULL THEN hja.id END) AS screener_completes,
  COUNT(DISTINCT CASE WHEN hp.is_top_match = TRUE THEN hja.id END) AS top_matches
FROM postgres.hiring_job_requests hjr
  INNER JOIN public.locations l ON l.location_id = hjr.location_id
  INNER JOIN public.companies c ON c.company_id = l.company_id
  LEFT JOIN postgres.hiring_job_applications hja
    ON hja.owner_id = hjr.id AND hja.owner_type = 'Hiring::JobRequest'
  LEFT JOIN prod_reporting.hiring.hiring_product hp ON hp.application_id = hja.id
WHERE hjr.hiring_version = 2
  AND hjr.status != 'draft'
  AND hjr.activated_at IS NOT NULL
GROUP BY 1, 2, 3, 4
```

**Job health distribution at Day 5**
```sql
SELECT
  CASE
    WHEN application_count >= 20 AND top_match_count >= 5 THEN 'Healthy'
    WHEN application_count >= 10 THEN 'Medium'
    ELSE 'Unhealthy'
  END AS health_tier,
  COUNT(*) AS jobs
FROM business_users.hiring.job_post_history_by_day
WHERE job_age_days = 5
GROUP BY 1
```

**Active subscriptions with net and gross MRR**
```sql
WITH discount_info AS (
  SELECT ad.subscription_id, MAX(d.partner_code_id) AS promo_code
  FROM postgres.applied_discounts ad
    JOIN postgres.discounts d ON d.id = ad.discount_id
  WHERE ad.owner_type = 'Location'
    AND ad.discount_id IN (7535, 7663, 7664, 7665)
  GROUP BY ad.subscription_id
)
SELECT
  l.location_id,
  c.company_id,
  bps.product_id,
  di.promo_code,
  CASE
    WHEN di.promo_code = 'TRY'                                  THEN 0
    WHEN bps.product_id = 925 AND di.promo_code = 'MULTILOC1'  THEN 149
    WHEN bps.product_id = 925 AND di.promo_code = 'MULTILOC2'  THEN 100
    WHEN bps.product_id = 925 AND di.promo_code = 'MULTILOC3'  THEN 75
    WHEN bps.product_id = 925                                   THEN 199
    WHEN bps.product_id = 1058                                  THEN 30
    WHEN bps.product_id = 1057                                  THEN 99
    ELSE 199
  END AS stripe_mrr,
  CASE
    WHEN bps.product_id = 1058 THEN 30
    ELSE 199
  END AS gross_mrr
FROM postgres.biller_product_subscriptions bps
  INNER JOIN public.locations l ON l.location_id = bps.owner_id
  INNER JOIN public.companies c ON c.company_id = l.company_id
  LEFT JOIN discount_info di ON di.subscription_id = bps.subscription_id
WHERE bps.subscription_type = 'hiring_assistant'
  AND bps.archived_at IS NULL
```

**Trial conversion rate by week**
```sql
WITH last_trial AS (
  SELECT
    company_uuid,
    created_at AS trial_started_at,
    expires_at AS trial_expires_at
  FROM hive_metastore.ext_homebase1_public.hiring_company_free_trials
  QUALIFY ROW_NUMBER() OVER (PARTITION BY company_uuid ORDER BY created_at DESC) = 1
)
SELECT
  DATE_TRUNC('week', lt.trial_started_at) AS trial_week,
  COUNT(DISTINCT lt.company_uuid) AS trials_started,
  COUNT(DISTINCT CASE WHEN bps.id IS NOT NULL THEN lt.company_uuid END) AS converted,
  ROUND(COUNT(DISTINCT CASE WHEN bps.id IS NOT NULL THEN lt.company_uuid END)
    * 1.0 / NULLIF(COUNT(DISTINCT lt.company_uuid), 0), 2) AS conversion_rate
FROM last_trial lt
  INNER JOIN public.companies c ON c.uuid = lt.company_uuid
  INNER JOIN public.locations loc ON loc.company_id = c.company_id
  LEFT JOIN postgres.biller_product_subscriptions bps
    ON bps.owner_id = loc.location_id
    AND bps.subscription_type = 'hiring_assistant'
    AND bps.created_at >= lt.trial_started_at
GROUP BY 1
ORDER BY 1
```

**ICP company list**
```sql
SELECT
  company_id, company_name, company_uuid,
  is_icp, is_target_segment,
  months_with_hires_L12, ee_add_per_location_per_month_L12M, location_count,
  pattern_type, predicted_role
FROM business_users.hiring.aggregate_hiring_profile
WHERE is_icp = TRUE
ORDER BY ee_add_per_location_per_month_L12M DESC
```

## Resources

- **Databricks Dashboard**: https://homebase-staging.cloud.databricks.com/dashboardsv3/01f04cb02743127cbfe153cf42c4e1e4/published
- **Databricks Pipelines**: `/Shared/Hiring Assistant Pipelines/Hiring Profile/Table Creation Pipeline`
- **Aggregated tables** (`business_users.hiring`): `aggregate_hiring_profile`, `jobs_with_metadata`, `job_post_history_by_day`, `company_hiring_milestones`, `hiring_subscriptions`, `company_last_12_months_hiring_stats`, `ml_hiring_intelligence`, `hb_company_profile`, `hiring_assistant_usage`, `job_post_level_details`
- **Looker explores**: `hiring_job_posts_v2` (job posts + applications), `hiring_assistant_sales_opportunities` (sales metrics)
- **Confluence**: [Hiring Data Guide](https://joinhomebase.atlassian.net/wiki/spaces/Hiring/pages/4951343175)
- **V2 launch date**: 2025-06-18
- **Product IDs**: 925 = Unlimited Monthly, 1057 = Unlimited Annual, 1058 = Starter
- **Discount IDs**: 7535, 7663, 7664, 7665 — Promo codes: TRY, MULTILOC1, MULTILOC2, MULTILOC3
