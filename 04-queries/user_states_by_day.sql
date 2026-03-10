-- title: Cashout User States by Day
-- description: Daily snapshot of cashout user state (eligibility, bank, user_state) for all enrolled users over the trailing 180 days. Used to measure eligibility and activation rates.
-- category: ee-experience
-- tags: [cashout, user-state, eligibility, activation, daily, bank]
-- author: KPMcDonough49
-- notes: B and B2 states = eligible to cash out. D6 = failed KYC or no valid debit card. Uses SCD-style logic to carry forward state changes. Joins fact_users_by_day for MAU and cashout activity flags.

WITH deduped_events AS (
  SELECT * FROM ext_firehose.shift_pay_user_state_events
  GROUP BY 1, 2, 3
),

events_sequenced AS (
  SELECT
    user_id, user_state, created_at,
    ROW_NUMBER() OVER (PARTITION BY user_id, created_at::date ORDER BY created_at DESC) AS inter_day_changes_desc,
    COALESCE(LEAD(created_at, 1) OVER (PARTITION BY user_id ORDER BY created_at ASC), CURRENT_TIMESTAMP()) AS valid_until
  FROM deduped_events
  WHERE created_at::date > CURRENT_DATE - INTERVAL 180 DAYS
),

user_state_changes AS (
  SELECT
    user_id, created_at::date AS change_date,
    MAX(CASE WHEN inter_day_changes_desc = 1 THEN user_state  END) AS user_state_eod,
    MAX(CASE WHEN inter_day_changes_desc = 1 THEN valid_until END) AS valid_until
  FROM events_sequenced
  GROUP BY 1, 2
),

user_state_aph AS (
  SELECT d.date, b.user_id, b.user_state_eod AS user_state
  FROM (SELECT EXPLODE(SEQUENCE(CURRENT_DATE - INTERVAL 180 DAYS, CURRENT_DATE, INTERVAL 1 DAY)) AS date) d
  JOIN user_state_changes b ON d.date >= b.change_date AND d.date < b.valid_until::date
),

banks_sequenced AS (
  SELECT
    user_id, bank_name, created_at, archived_at,
    ROW_NUMBER() OVER (PARTITION BY user_id, created_at::date ORDER BY created_at DESC) AS inter_day_changes_desc,
    COALESCE(LEAD(created_at, 1) OVER (PARTITION BY user_id ORDER BY created_at ASC), archived_at, CURRENT_TIMESTAMP()) AS valid_until
  FROM postgres.shift_pay_plaid_items
),

bank_changes AS (
  SELECT
    user_id, created_at::date AS change_date,
    MAX(CASE WHEN inter_day_changes_desc = 1 THEN bank_name  END) AS bank_name_eod,
    MAX(CASE WHEN inter_day_changes_desc = 1 THEN valid_until END) AS valid_until
  FROM banks_sequenced
  GROUP BY 1, 2
),

banks_aph AS (
  SELECT d.date, b.user_id, b.bank_name_eod AS bank
  FROM (SELECT EXPLODE(SEQUENCE(CURRENT_DATE - INTERVAL 180 DAYS, CURRENT_DATE, INTERVAL 1 DAY)) AS date) d
  JOIN bank_changes b ON d.date >= b.change_date AND d.date < b.valid_until::date
),

eligibility_sequenced AS (
  SELECT
    user_id, created_at,
    CASE WHEN eligible = TRUE THEN 'eligible' ELSE 'ineligible' END AS eligible,
    rule_results,
    ROW_NUMBER() OVER (PARTITION BY user_id, created_at::date ORDER BY created_at DESC) AS inter_day_changes_desc,
    COALESCE(LEAD(created_at, 1) OVER (PARTITION BY user_id ORDER BY created_at ASC), CURRENT_TIMESTAMP()) AS valid_until,
    MIN(created_at) OVER (PARTITION BY user_id) AS first_enrollment
  FROM postgres.shift_pay_eligibilities
),

eligibility_changes AS (
  SELECT
    user_id, created_at::date AS change_date, first_enrollment,
    MAX(CASE WHEN inter_day_changes_desc = 1 THEN eligible     END) AS eligibility_eod,
    MAX(CASE WHEN inter_day_changes_desc = 1 THEN rule_results END) AS rule_results_eod,
    MAX(CASE WHEN inter_day_changes_desc = 1 THEN valid_until  END) AS valid_until
  FROM eligibility_sequenced
  GROUP BY 1, 2, 3
),

eligibility_aph AS (
  SELECT d.date, b.user_id, eligibility_eod AS eligibility, rule_results_eod AS rule_results, first_enrollment
  FROM (SELECT EXPLODE(SEQUENCE(CURRENT_DATE - INTERVAL 180 DAYS, CURRENT_DATE, INTERVAL 1 DAY)) AS date) d
  JOIN eligibility_changes b ON d.date >= b.change_date AND d.date < b.valid_until::date
)

SELECT
  fu.date, fu.user_id, aph.user_state, ba.bank, e.eligibility, e.first_enrollment,
  fu.is_mau,
  DATEDIFF(fu.date, e.first_enrollment) AS user_age,
  fu.cashed_out_before, fu.cashed_out_this_month, fu.cashed_out_last_month,
  fu.cashed_out_last_30, fu.cashed_out_last_7, fu.first_cash_out_date,
  u.created_at               AS user_created,
  u.highest_level_location
FROM public.fact_users_by_day fu
LEFT JOIN user_state_aph aph ON fu.user_id = aph.user_id AND fu.date = aph.date
LEFT JOIN banks_aph ba ON ba.user_id = fu.user_id AND ba.date = fu.date
LEFT JOIN eligibility_aph e ON e.user_id = fu.user_id AND e.date = fu.date
LEFT JOIN public.users u ON u.user_id = fu.user_id
WHERE e.first_enrollment IS NOT NULL
  AND fu.date > CURRENT_DATE - INTERVAL 180 DAYS
