-- title: Cashout Non-Repayment Rates by Bank Bucket and User Type
-- description: Weekly non-repayment dollar rates at D1 through D91 cohort windows, segmented by bank bucket (Chime, Neobank, Non-Neo) and new vs. returning user.
-- category: ee-experience
-- tags: [cashout, non-repayment, risk, bank-bucket, cohort, weekly]
-- author: KPMcDonough49
-- notes: Requires columns now_vs_payback_date, paid_back_dollars_d1/d7/etc. to exist in public.cashout_advances. Non-repayment rate = 1 - (dollars paid back / dollars owed). NACHA debit return threshold is 15%.

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

base AS (
  SELECT
    DATE_TRUNC('week', advance_date)::date AS week,
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
         ELSE 'Returning User' END AS user_bucket,
    COUNT(DISTINCT advance_id)                              AS advances,
    SUM(amount_in_dollars + fee_in_dollars)                 AS dollars_owed,
    SUM((amount_in_dollars + fee_in_dollars) * paid_back_pr) AS dollars_paid_back,
    SUM(CASE WHEN now_vs_payback_date > 1  THEN amount_in_dollars + fee_in_dollars END) AS D1_dollars,
    SUM(CASE WHEN now_vs_payback_date > 1  THEN paid_back_dollars_d1  END)              AS paid_back_d1,
    SUM(CASE WHEN now_vs_payback_date > 7  THEN amount_in_dollars + fee_in_dollars END) AS D7_dollars,
    SUM(CASE WHEN now_vs_payback_date > 7  THEN paid_back_dollars_d7  END)              AS paid_back_d7,
    SUM(CASE WHEN now_vs_payback_date > 14 THEN amount_in_dollars + fee_in_dollars END) AS D14_dollars,
    SUM(CASE WHEN now_vs_payback_date > 14 THEN paid_back_dollars_d14 END)              AS paid_back_d14,
    SUM(CASE WHEN now_vs_payback_date > 28 THEN amount_in_dollars + fee_in_dollars END) AS D28_dollars,
    SUM(CASE WHEN now_vs_payback_date > 28 THEN paid_back_dollars_d28 END)              AS paid_back_d28,
    SUM(CASE WHEN now_vs_payback_date > 56 THEN amount_in_dollars + fee_in_dollars END) AS D56_dollars,
    SUM(CASE WHEN now_vs_payback_date > 56 THEN paid_back_dollars_d56 END)              AS paid_back_d56,
    SUM(CASE WHEN now_vs_payback_date > 91 THEN amount_in_dollars + fee_in_dollars END) AS D91_dollars,
    SUM(CASE WHEN now_vs_payback_date > 91 THEN paid_back_dollars_d91 END)              AS paid_back_d91
  FROM advances_with_paybacks ca
  WHERE source IN ('synapse', 'plaid', 'checkout')
    AND status = 'SETTLED'
    AND ca.advance_date > '2023-01-01'
  GROUP BY 1, 2, 3
)

SELECT
  week, bank_bucket, user_bucket, advances, dollars_owed, dollars_paid_back,
  D1_dollars,  CASE WHEN D1_dollars  > 0 THEN 1 - paid_back_d1  / D1_dollars  ELSE 0 END AS D1_dollar_rate,
  D7_dollars,  CASE WHEN D7_dollars  > 0 THEN 1 - paid_back_d7  / D7_dollars  ELSE 0 END AS D7_dollar_rate,
  D14_dollars, CASE WHEN D14_dollars > 0 THEN 1 - paid_back_d14 / D14_dollars ELSE 0 END AS D14_dollar_rate,
  D28_dollars, CASE WHEN D28_dollars > 0 THEN 1 - paid_back_d28 / D28_dollars ELSE 0 END AS D28_dollar_rate,
  D56_dollars, CASE WHEN D56_dollars > 0 THEN 1 - paid_back_d56 / D56_dollars ELSE 0 END AS D56_dollar_rate,
  D91_dollars, CASE WHEN D91_dollars > 0 THEN 1 - paid_back_d91 / D91_dollars ELSE 0 END AS D91_dollar_rate
FROM base
ORDER BY 1 DESC
