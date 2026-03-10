-- title: Owner Research List with Cashout Context
-- description: Pulls owner emails, names, and location metadata for user research interviews. Filter on business_type_new, tier_id, channel, or cashout_enabled to target specific segments.
-- category: ee-experience
-- tags: [research, owners, locations, cashout, interviews]
-- author: KPMcDonough49
-- notes: Every location belongs to a company — multiple locations can share a company. active_now = 'true' filters to active locations. Cashout users counted over trailing 60 days of settled advances.

WITH shift_info AS (
  SELECT j.location_id, COUNT(DISTINCT j.user_id) AS users
  FROM postgres.shifts s
  LEFT JOIN postgres.jobs j ON j.id = s.owner_id AND s.owner_type = 'Job'
  WHERE DATEDIFF(CURRENT_DATE, start_at) BETWEEN 0 AND 30
  GROUP BY 1
),

cashout_info AS (
  SELECT
    COALESCE(spae.location_id, u.highest_level_location) AS location_id,
    COUNT(DISTINCT ca.user_id)                            AS cashout_users
  FROM public.cashout_advances ca
  LEFT JOIN ext_firehose.shift_pay_advance_events spae ON spae.advance_id = ca.advance_id
  LEFT JOIN public.users u ON u.user_id = ca.user_id
  WHERE ca.source IN ('plaid', 'synapse', 'checkout')
    AND DATEDIFF(CURRENT_DATE, ca.advance_date) BETWEEN 0 AND 60
    AND ca.status = 'SETTLED'
  GROUP BY 1
)

SELECT
  si.*,
  CASE WHEN si.users <= 5  THEN '0-5'
       WHEN si.users <= 10 THEN '6-10'
       WHEN si.users <= 30 THEN '11-30'
       WHEN si.users <= 50 THEN '31-50'
       ELSE '50+' END AS location_count_bucket,
  c.channel, c.location_count,
  l.created_at        AS location_created,
  l.business_type_new,
  l.tier_id,
  u.first_name        AS owner_first_name,
  u.last_name         AS owner_last_name,
  u.email             AS owner_email,
  COALESCE(ci.cashout_users, 0)                             AS cashout_users_at_location,
  CASE WHEN crd.turn_off_time IS NOT NULL THEN 0 ELSE 1 END AS cashout_enabled
FROM shift_info si
LEFT JOIN cashout_info ci ON ci.location_id = si.location_id
LEFT JOIN public.locations l
  ON l.location_id = si.location_id
  AND l.state_cleaned NOT IN ('Not USA', 'Unclassified')
  AND l.active_now = 'true'
LEFT JOIN public.companies c ON c.company_id = l.company_id
LEFT JOIN public.cashout_rollout_dates crd ON crd.company_id = l.company_id
LEFT JOIN public.users u ON u.user_id = c.owner_id
