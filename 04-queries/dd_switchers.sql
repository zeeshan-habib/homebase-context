-- title: Direct Deposit Switchers — Banking to Cashout
-- description: Identifies banking users who disconnected their direct deposit within the first 5 days and tracks how many switched to cashout within 3 days of disconnecting.
-- category: ee-experience
-- tags: [cashout, banking, direct-deposit, churn, switching]
-- author: KPMcDonough49
-- notes: Banking = HB bank account product. Cashout = EWA advance product. is_homebase_money = 'true' filters to HB-issued accounts. Only looks at users with >10 days since DD connection.

WITH dd_switchers AS (
  SELECT
    owner_id,
    MIN(created_at)                                 AS dd_connected,
    MAX(COALESCE(archived_at, CURRENT_TIMESTAMP())) AS dd_archived
  FROM postgres.payroll_bank_accounts
  WHERE is_homebase_money = 'true'
    AND owner_type = 'Account'
  GROUP BY 1
),

joined AS (
  SELECT
    dd.*,
    DATEDIFF(dd_archived, dd_connected)                                              AS days_between_creation_and_archive,
    CASE WHEN dd_archived = CURRENT_TIMESTAMP() THEN 'dd_active' ELSE 'churned' END AS dd_status,
    MIN(ca.advance_date)                                                              AS first_advance
  FROM dd_switchers dd
  LEFT JOIN public.cashout_advances ca
    ON ca.user_id = dd.owner_id
    AND ca.advance_date::date >= dd.dd_archived
    AND ca.source IN ('plaid', 'synapse', 'checkout')
  GROUP BY 1, 2, 3, 4, 5
)

SELECT
  CASE WHEN DATEDIFF(first_advance::date, dd_archived::date) BETWEEN 0 AND 3
       THEN 'advance_within_3'
       ELSE 'no_advance' END AS user_status,
  COUNT(DISTINCT owner_id)   AS users
FROM joined
WHERE DATEDIFF(CURRENT_DATE, dd_connected) > 10
  AND days_between_creation_and_archive < 5
GROUP BY 1
