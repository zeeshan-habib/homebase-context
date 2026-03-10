-- title: Cashout Penetration by Location
-- description: For every active location, shows total active users, mobile-signed-in users, and enrolled cashout users — used to calculate cashout penetration rate by location.
-- category: ee-experience
-- tags: [cashout, penetration, locations, active-users, enrollment]
-- author: KPMcDonough49
-- notes: active_last_30 uses basic_employee_usage_days_last_30 >= 2 from fact_locations_by_day. Cashout revenue lookback is trailing 30 days. Filters to active_last_30 = 1 only.

WITH cashout_enrollment AS (
  SELECT
    l.location_id, l.company_id, l.channel, l.business_type_new, l.project_or_shift,
    CASE WHEN flbd.basic_employee_usage_days_last_30 >= 2 THEN 1 ELSE 0 END AS active_last_30,
    COUNT(DISTINCT CASE WHEN u.is_mau = TRUE THEN u.user_id END)                        AS active_users,
    COUNT(DISTINCT CASE WHEN u.is_mau = TRUE AND u.mobile_last_used_info IS NOT NULL
                        THEN u.user_id END)                                             AS active_users_with_mobile_signin,
    COUNT(DISTINCT CASE WHEN u.is_mau = TRUE THEN sp.user_id END)                      AS active_users_enrolled
  FROM public.locations l
  LEFT JOIN public.users u ON u.highest_level_location = l.location_id
  LEFT JOIN postgres.shift_pay_eligibilities sp ON sp.user_id = u.user_id
  LEFT JOIN public.fact_locations_by_day flbd
    ON flbd.location_id = l.location_id
    AND flbd.date = CURRENT_DATE - INTERVAL 1 DAY
  GROUP BY 1, 2, 3, 4, 5, 6
),

cashout_revenue AS (
  SELECT
    l.location_id,
    SUM(ca.fee_in_dollars)        AS cashout_revenue_last_30,
    COUNT(DISTINCT ca.advance_id) AS advances_last_30
  FROM public.cashout_advances ca
  LEFT JOIN public.users u ON u.user_id = ca.user_id
  LEFT JOIN public.locations l ON u.highest_level_location = l.location_id
  WHERE DATEDIFF(CURRENT_DATE, ca.advance_date) <= 30
  GROUP BY 1
)

SELECT
  CASE WHEN crd.turn_off_time IS NULL THEN 'Cashout Enabled' ELSE 'Cashout Disabled' END AS cashout_status,
  ce.*,
  CASE WHEN ce.active_users BETWEEN 0  AND 5  THEN '1 - xs'
       WHEN ce.active_users BETWEEN 6  AND 10 THEN '2 - sm'
       WHEN ce.active_users BETWEEN 11 AND 20 THEN '3 - med'
       WHEN ce.active_users BETWEEN 21 AND 30 THEN '4 - lg'
       WHEN ce.active_users BETWEEN 31 AND 50 THEN '5 - xl'
       WHEN ce.active_users > 50             THEN '5 - xl' END AS location_employee_count_bucket,
  cr.cashout_revenue_last_30,
  cr.advances_last_30
FROM cashout_enrollment ce
LEFT JOIN cashout_revenue cr ON cr.location_id = ce.location_id
LEFT JOIN public.cashout_rollout_dates crd ON crd.company_id = ce.company_id
WHERE active_last_30 = 1
