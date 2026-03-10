-- title: PAD / Banking Product Penetration Among Payroll Payees
-- description: Measures what % of HB payroll payees are transacting with the PAD/banking product by joining payroll runs, banking transactions, and Unit customer data on a rolling daily basis.
-- category: ee-experience
-- tags: [banking, pad, payroll, penetration, unit, transactions, daily]
-- author: KPMcDonough49
-- notes: PAD = Payroll Advance / banking product (source = 'banking'). Uses banking.unit_* tables. Date spine generated via SEQUENCE. Looks back 32 days for payroll runs and transactions per day.

WITH pad_info AS (
  SELECT ca.advance_id AS transaction_id, ca.advance_date::timestamp AS created_at,
    uc.hb_user_id, uc.created_at AS customer_created, uc.customer_id, 0 AS interchange,
    'pad_in' AS type, 'inflow' AS inflow_outflow,
    ROUND(SUM(ca.amount_in_dollars), 2) AS dollar_amount
  FROM banking.unit_customers uc
  JOIN public.cashout_advances ca
    ON ca.user_id = uc.hb_user_id AND ca.status = 'SETTLED' AND ca.source = 'banking'
  WHERE uc.created_at > '2022-01-19'
  GROUP BY 1, 2, 3, 4, 5, 6, 7, 8
),

pad_paybacks AS (
  SELECT ubt.transaction_id::integer, ubt.created_at, uc.hb_user_id,
    uc.created_at AS customer_created, uc.customer_id, 0 AS interchange,
    'pad_payback' AS type, 'outflow' AS inflow_outflow,
    ROUND(SUM(-ubt.amount / 100), 2) AS dollar_amount
  FROM banking.unit_customers uc
  JOIN banking.unit_book_transactions ubt ON ubt.customer_id = uc.customer_id
  WHERE uc.created_at > '2022-01-19' AND account_id <> 2844868
  GROUP BY 1, 2, 3, 4, 5, 6, 7, 8
),

ach_inflow AS (
  SELECT rec.transaction_id::integer, rec.created_at::timestamp, uc.hb_user_id,
    uc.created_at::timestamp AS customer_created, uc.customer_id, 0 AS interchange,
    'ach_in' AS type, 'inflow' AS inflow_outflow,
    ROUND(SUM(CAST(rec.amount AS DOUBLE) / 100), 2) AS dollar_amount
  FROM banking.unit_customers uc
  JOIN banking.unit_received_ach_transactions rec ON rec.customer_id = uc.customer_id
  WHERE uc.created_at > '2022-01-19'
  GROUP BY 1, 2, 3, 4, 5, 6, 7, 8
),

ach_outflow AS (
  SELECT uo.transaction_id::integer, uo.created_at::timestamp, uc.hb_user_id,
    uc.created_at AS customer_created, uc.customer_id, 0 AS interchange,
    'ach_out' AS type, 'outflow' AS inflow_outflow,
    ROUND(SUM(-uo.amount / 100), 2) AS dollar_amount
  FROM banking.unit_customers uc
  JOIN banking.unit_originated_ach_transactions uo ON uo.customer_id = uc.customer_id
  WHERE uc.created_at > '2022-01-19'
  GROUP BY 1, 2, 3, 4, 5, 6, 7, 8
),

purchase_transactions AS (
  SELECT ut.transaction_id::integer, ut.created_at, uc.hb_user_id,
    uc.created_at AS customer_created, uc.customer_id,
    COALESCE(ROUND(interchange / 100, 2), 0) AS interchange,
    CASE WHEN direction = 'Debit' THEN 'purchase_out' ELSE 'purchase_in' END AS type,
    CASE WHEN direction = 'Debit' THEN 'outflow' ELSE 'inflow' END AS inflow_outflow,
    SUM(CASE WHEN direction = 'Debit' THEN -ut.amount / 100 ELSE ut.amount / 100 END) AS dollar_amount
  FROM banking.unit_customers uc
  JOIN banking.unit_purchase_transactions ut ON ut.customer_id = uc.customer_id
  WHERE uc.created_at > '2022-01-19'
  GROUP BY 1, 2, 3, 4, 5, 6, 7, 8
),

card_transactions AS (
  SELECT uct.transaction_id::integer, uct.created_at, uc.hb_user_id,
    uc.created_at AS customer_created, uc.customer_id,
    COALESCE(ROUND(interchange / 100, 2), 0) AS interchange,
    CASE WHEN direction = 'Debit' AND merchant_category <> 'Financial Institutions – Merchandise and Services' THEN 'monetized_card_out'
         WHEN LOWER(merchant_name) LIKE '%chime%'       THEN 'monetized_card_out'
         WHEN LOWER(merchant_name) LIKE '%albert%'      THEN 'monetized_card_out'
         WHEN LOWER(merchant_name) LIKE '%dave%'        THEN 'monetized_card_out'
         WHEN LOWER(merchant_name) LIKE '%one finance%' THEN 'monetized_card_out'
         WHEN LOWER(merchant_name) LIKE '%current%'     THEN 'monetized_card_out'
         WHEN LOWER(merchant_name) LIKE '%varo%'        THEN 'monetized_card_out'
         WHEN direction = 'Debit'  THEN 'not_monetized_card_out'
         ELSE 'card_in' END AS type,
    CASE WHEN direction = 'Debit' THEN 'outflow' ELSE 'inflow' END AS inflow_outflow,
    SUM(CASE WHEN direction = 'Debit' THEN -uct.amount / 100 ELSE uct.amount / 100 END) AS dollar_amount
  FROM banking.unit_customers uc
  JOIN banking.unit_card_transactions uct ON uc.customer_id = uct.customer_id
  WHERE uc.created_at > '2022-01-19'
  GROUP BY 1, 2, 3, 4, 5, 6, 7, 8
),

atm_transactions AS (
  SELECT atm.transaction_id::integer, atm.created_at, uc.hb_user_id,
    uc.created_at AS customer_created, uc.customer_id,
    COALESCE(ROUND(interchange / 100, 2), 0) AS interchange,
    'atm_out' AS type, 'outflow' AS inflow_outflow,
    ROUND(SUM(-atm.amount / 100), 2) AS dollar_amount
  FROM banking.unit_customers uc
  JOIN banking.unit_atm_transactions atm ON uc.customer_id = atm.customer_id
  WHERE uc.created_at > '2022-01-19'
  GROUP BY 1, 2, 3, 4, 5, 6, 7, 8
),

joined AS (
  SELECT * FROM pad_info
  UNION ALL SELECT * FROM pad_paybacks
  UNION ALL SELECT * FROM ach_inflow
  UNION ALL SELECT * FROM ach_outflow
  UNION ALL SELECT * FROM purchase_transactions
  UNION ALL SELECT * FROM card_transactions
  UNION ALL SELECT * FROM atm_transactions
),

paid_wages AS (
  SELECT a.created_at, a.id, a.item_id, a.pay AS amount, b.job_id, c.location_id
  FROM postgres.payroll_item_net_pays a
  LEFT JOIN postgres.payroll_items b ON a.item_id = b.id
  LEFT JOIN postgres.payroll_payroll_runs c ON b.run_id = c.id
  WHERE c.status = 3
  UNION ALL
  SELECT a.created_at, a.id, a.job_id, a.amount, a.job_id, b.location_id
  FROM postgres.payroll_contractor_payments a
  LEFT JOIN postgres.payroll_payroll_runs b ON a.run_id = b.id
  WHERE b.status = 3
),

payroll_users AS (
  SELECT a.*, c.user_id
  FROM paid_wages a
  LEFT JOIN postgres.jobs b ON a.job_id = b.id
  LEFT JOIN public.users c ON b.user_id = c.user_id
  WHERE a.created_at >= '2022-01-01'
    AND b.wage_type = 0
    AND tax_classification = 'w2'
),

dates AS (
  SELECT EXPLODE(SEQUENCE(DATE '2023-01-01', CURRENT_DATE, INTERVAL 1 DAY)) AS date
),

all_users AS (
  SELECT
    d.date,
    pu.user_id,
    MAX(pu.created_at)::date        AS last_payroll_run,
    COUNT(DISTINCT job_id)           AS jobs_paid,
    SUM(amount)                      AS amount_paid_last_45,
    COUNT(DISTINCT uc.hb_user_id)    AS enrolled_in_pad,
    COUNT(DISTINCT j.transaction_id) AS transactions_last_30
  FROM dates d
  LEFT JOIN payroll_users pu ON DATEDIFF(d.date, pu.created_at) BETWEEN 0 AND 32
  LEFT JOIN joined j ON j.hb_user_id = pu.user_id AND DATEDIFF(d.date, j.created_at) BETWEEN 0 AND 32
  LEFT JOIN banking.unit_customers uc ON uc.hb_user_id = pu.user_id AND uc.created_at::date <= d.date
  GROUP BY 1, 2
)

SELECT * FROM all_users
ORDER BY 1 DESC
