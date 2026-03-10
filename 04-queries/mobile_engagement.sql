-- title: Employee Mobile Engagement vs. Shift Activity
-- description: Weekly view of shift-active employees and how many engage with the mobile app, broken out by product area (timeclock, scheduling, messaging, money tab, etc.).
-- category: ee-experience
-- tags: [mobile, engagement, employees, shifts, weekly, product-area]
-- author: KPMcDonough49
-- notes: Mobile engagement rate = days_using_the_app / shifts. Uses dbt.fin_ux_events_agg and playground.ux_mapping for product area bucketing. Filters employees only (level = 'Employee'). Data starts 2023-01-01.

WITH shift_info AS (
  SELECT
    DATE_TRUNC('week', s.start_at)                                       AS week,
    j.user_id,
    COUNT(DISTINCT s.id)                                                   AS shifts,
    COUNT(DISTINCT j.location_id)                                          AS locations,
    SUM((unix_timestamp(end_at) - unix_timestamp(start_at)) / 3600)       AS hours_worked
  FROM postgres.shifts s
  LEFT JOIN postgres.jobs j ON j.id = s.owner_id AND s.owner_type = 'Job'
  WHERE start_at >= '2023-01-01'
    AND j.level = 'Employee'
    AND start_at < CURRENT_DATE
  GROUP BY 1, 2
),

mapped_events AS (
  SELECT ux.*, COALESCE(um.product_bucket, 'Other') AS product_bucket
  FROM dbt.fin_ux_events_agg ux
  LEFT JOIN playground.ux_mapping um
    ON um.product_area = ux.product_area
    AND um.event_category = ux.event_category
  WHERE ux.created_at_date >= '2023-01-01'
),

first_mobile_events AS (
  SELECT user_id, MIN(created_at_date) AS first_mobile_event
  FROM dbt.fin_ux_events_agg
  GROUP BY 1
),

user_days AS (
  SELECT
    DATE_TRUNC('week', created_at_date)::date                                                      AS week,
    user_id,
    COUNT(DISTINCT created_at_date)                                                                 AS days_using_the_app,
    COUNT(DISTINCT CASE WHEN product_bucket = 'Dashboard / Nav'  THEN created_at_date END)         AS days_with_dash_view,
    COUNT(DISTINCT CASE WHEN product_bucket = 'Scheduling'       THEN created_at_date END)         AS days_with_scheduling_view,
    COUNT(DISTINCT CASE WHEN product_bucket = 'Time Clock'       THEN created_at_date END)         AS days_with_timeclock_view,
    COUNT(DISTINCT CASE WHEN product_bucket = 'Money Tab'        THEN created_at_date END)         AS days_with_money_tab_view,
    COUNT(DISTINCT CASE WHEN product_bucket = 'Store Location'   THEN created_at_date END)         AS days_with_store_location_view,
    COUNT(DISTINCT CASE WHEN product_bucket = 'Team'             THEN created_at_date END)         AS days_with_team_view,
    COUNT(DISTINCT CASE WHEN product_bucket = 'Shift Feedback'   THEN created_at_date END)         AS days_with_shift_feed_back_view,
    COUNT(DISTINCT CASE WHEN product_bucket = 'Messaging'        THEN created_at_date END)         AS days_with_messaging_view
  FROM mapped_events
  GROUP BY 1, 2
),

shifts_and_mobile AS (
  SELECT
    COALESCE(ud.week, si.week)::date AS week,
    COALESCE(ud.user_id, si.user_id) AS user_id,
    si.shifts, si.hours_worked, si.locations,
    ud.days_using_the_app, ud.days_with_dash_view, ud.days_with_messaging_view,
    ud.days_with_money_tab_view, ud.days_with_scheduling_view,
    ud.days_with_team_view, ud.days_with_timeclock_view
  FROM user_days ud
  FULL OUTER JOIN shift_info si ON si.user_id = ud.user_id AND si.week = ud.week
)

SELECT
  sm.*,
  sm.week + INTERVAL 6 DAYS AS end_of_week,
  u.created_at               AS user_created,
  u.highest_level_location,
  a.date_of_birth,
  l.company_id,
  crd.turn_off_time,
  fme.first_mobile_event
FROM shifts_and_mobile sm
LEFT JOIN public.users u ON u.user_id = sm.user_id
LEFT JOIN postgres.accounts a ON a.type = 'User' AND a.id = u.user_id
LEFT JOIN public.locations l ON l.location_id = u.highest_level_location
LEFT JOIN public.cashout_rollout_dates crd ON crd.company_id = l.company_id
LEFT JOIN first_mobile_events fme ON fme.user_id = sm.user_id
