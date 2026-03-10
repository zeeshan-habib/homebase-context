-- title: Cashout Segmentation by Month
-- description: Monthly revenue and user counts broken out by cashout user segment (new, returning, continued access, dormant) and bank bucket (Chime, Neobank, Non-Neo).
-- category: ee-experience
-- tags: [cashout, segmentation, monthly, revenue, bank-bucket, user-type]
-- author: KPMcDonough49
-- notes: former_employee = user terminated from HB job (continued access). dormant_employee = temporarily not working. New user = first payback. Bank bucket is derived from bank_name at time of advance.

WITH first_payperiods AS (
  SELECT user_id, MIN(payback_date) AS first_payback
  FROM public.cashout_advances
  WHERE source IN ('plaid', 'synapse', 'checkout')
    AND status = 'SETTLED'
  GROUP BY 1
),

last_advance AS (
  SELECT
    user_id,
    DATE_TRUNC('month', advance_date)::date AS month,
    MAX(advance_id)                          AS last_advance
  FROM public.cashout_advances
  WHERE source IN ('plaid', 'synapse', 'checkout')
    AND status = 'SETTLED'
  GROUP BY 1, 2
),

advance_info AS (
  SELECT
    DATE_TRUNC('month', ca.advance_date)::date                                            AS month,
    ca.user_id,
    MAX(CASE WHEN la.last_advance IS NOT NULL THEN ca.bank_name END)                      AS bank,
    COUNT(DISTINCT advance_id)                                                             AS advances,
    COUNT(DISTINCT CASE WHEN ca.payback_date = fp.first_payback THEN advance_id END)      AS first_time_advances,
    COUNT(DISTINCT CASE WHEN ca.accrual_mode = 'former_employee' THEN advance_id END)     AS continued_access_advances,
    COUNT(DISTINCT CASE WHEN ca.accrual_mode = 'dormant_employee' THEN advance_id END)    AS dormant_advances
  FROM public.cashout_advances ca
  LEFT JOIN first_payperiods fp ON fp.user_id = ca.user_id
  LEFT JOIN last_advance la ON la.last_advance = ca.advance_id
  WHERE source IN ('plaid', 'synapse', 'checkout')
    AND status = 'SETTLED'
  GROUP BY 1, 2
),

classification AS (
  SELECT
    month, user_id,
    CASE WHEN bank IN (
           'Varo Bank','GO2Bank','Current','Dave','Walmart MoneyCard by Green Dot',
           'Netspend All-Access Account by MetaBank','Albert','SoFi',
           'Green Dot Prepaid Debit Card','Lili','Discover','MoneyLion','Oxygen',
           'ACE Flare Account by Metabank','Netspend','Netspend - SkylightOne','Sable',
           'One','T-Mobile Money','Yotta','GO2bank','Varo Money','Varo',
           'MoneyLion - RoarMoney','SoFi Money','T-Mobile MONEY'
         ) THEN 'Neobank'
         WHEN bank = 'Chime' THEN 'Chime'
         ELSE 'Non-Neo' END AS bank,
    CASE WHEN first_time_advances > 1       THEN 'new user'
         WHEN continued_access_advances > 1 THEN 'continued access'
         WHEN advances = dormant_advances    THEN 'dormant_user'
         ELSE 'returning user' END AS cashout_bucket
  FROM advance_info
)

SELECT
  c.month, c.bank, c.cashout_bucket,
  COUNT(DISTINCT ca.user_id)    AS users,
  COUNT(DISTINCT ca.advance_id) AS advances,
  SUM(ca.fee_in_dollars)        AS revenue,
  SUM(ca.amount_in_dollars)     AS amount_advanced
FROM public.cashout_advances ca
LEFT JOIN classification c
  ON c.user_id = ca.user_id
  AND c.month = DATE_TRUNC('month', ca.advance_date)::date
WHERE ca.source IN ('plaid', 'synapse', 'checkout')
  AND ca.status = 'SETTLED'
GROUP BY 1, 2, 3
ORDER BY 1 DESC
