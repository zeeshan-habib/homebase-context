-- title: Cashout Advances with User Risk Scores
-- description: Joins settled cashout advances to their data science risk scores at time of advance, segmented by bank bucket and new vs. returning user.
-- category: ee-experience
-- tags: [cashout, risk, advances, bank-bucket, new-user, returning-user]
-- author: KPMcDonough49
-- notes: Hardcoded to a single advance_date — update the WHERE clause for the desired date range. V2 risk scores apply to new users, V3 to returning users.

WITH cleaned_advances AS (
  SELECT *,
    CASE WHEN accrual_mode = 'former_employee' THEN 'former_employee'
         ELSE 'regular_user' END AS accrual_bucket
  FROM public.cashout_advances
  WHERE source IN ('synapse', 'plaid', 'checkout')
    AND status = 'SETTLED'
),

advances_with_paybacks AS (
  SELECT *,
    MIN(payback_date) OVER (PARTITION BY user_id, accrual_bucket) AS first_payback
  FROM cleaned_advances
),

bucketed_users AS (
  SELECT
    advance_id, advance_date, user_id, amount_in_dollars, payback_date, paid_back_pr,
    CASE WHEN accrual_mode = 'former_employee' THEN 'continued access'
         WHEN bank_name IN (
           'Varo Bank','GO2Bank','Current','Dave','Walmart MoneyCard by Green Dot',
           'Netspend All-Access Account by MetaBank','Albert','SoFi',
           'Green Dot Prepaid Debit Card','Lili','Discover','MoneyLion','Oxygen',
           'ACE Flare Account by Metabank','Netspend','Netspend - SkylightOne','Sable',
           'One','T-Mobile Money','Yotta','GO2bank','Varo Money','Varo',
           'MoneyLion - RoarMoney','SoFi Money','T-Mobile MONEY'
         ) THEN 'Neobank'
         WHEN bank_name = 'Chime' THEN 'Chime'
         ELSE 'Non-Neo' END AS bank_bucket,
    CASE WHEN ca.payback_date = ca.first_payback THEN 'New User'
         ELSE 'Returning User' END AS user_bucket
  FROM advances_with_paybacks ca
)

SELECT
  bu.*,
  CASE WHEN user_bucket = 'New User' AND first_cashout_risk_score_model_version = 2
         THEN first_cashout_risk_score
       WHEN user_bucket = 'Returning User' THEN v3_risk_score
       ELSE NULL END AS risk_score
FROM bucketed_users bu
LEFT JOIN ext_firehose.shift_pay_advance_events spae
  ON spae.advance_id = bu.advance_id
WHERE advance_date::date = '2025-09-15'
GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9
