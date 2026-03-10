-- title: Payback Return Codes by Bank and Month
-- description: Monthly count of failed cashout payback attempts grouped by bank bucket, return code, and active/inactive bank status. Used to monitor NACHA return thresholds.
-- category: ee-experience
-- tags: [cashout, paybacks, returns, nacha, bank-bucket, risk]
-- author: KPMcDonough49
-- notes: Filtered to debit delivery_method and source = 'checkout' only — change for ACH or same-day ACH. NACHA threshold for debit returns is 15%. response_code parsed from the note field.

WITH banks_sequenced AS (
  SELECT
    user_id, bank_name, error_code, created_at, archived_at,
    ROW_NUMBER() OVER (PARTITION BY user_id, created_at::date ORDER BY created_at DESC) AS inter_day_changes_desc,
    COALESCE(LEAD(created_at, 1) OVER (PARTITION BY user_id ORDER BY created_at ASC), archived_at, CURRENT_TIMESTAMP()) AS valid_until
  FROM postgres.shift_pay_plaid_items
),

bank_changes AS (
  SELECT
    user_id, created_at::date AS change_date,
    MAX(CASE WHEN inter_day_changes_desc = 1 THEN bank_name  END) AS bank_name_eod,
    MAX(CASE WHEN inter_day_changes_desc = 1 THEN error_code END) AS error_code_eod,
    MAX(CASE WHEN inter_day_changes_desc = 1 THEN valid_until END) AS valid_until
  FROM banks_sequenced
  GROUP BY 1, 2
),

banks_aph AS (
  SELECT d.date, b.user_id, b.bank_name_eod AS bank, error_code_eod AS error_code
  FROM (SELECT EXPLODE(SEQUENCE(DATE '2023-01-01', CURRENT_DATE, INTERVAL 1 DAY)) AS date) d
  JOIN bank_changes b ON d.date >= b.change_date AND d.date < b.valid_until::date
)

SELECT
  DATE_TRUNC('month', spp.created_at)::date AS month,
  CASE WHEN aph.bank = 'Chase'           THEN 'Chase'
       WHEN aph.bank = 'Wells Fargo'     THEN 'Wells Fargo'
       WHEN aph.bank = 'Bank of America' THEN 'Bank of America'
       WHEN aph.bank = 'Capital One'     THEN 'Capital One'
       WHEN aph.bank = 'Chime'           THEN 'Chime'
       WHEN aph.bank IN (
         'Varo Bank','GO2Bank','Current','Dave','Walmart MoneyCard by Green Dot',
         'Netspend All-Access Account by MetaBank','Albert','SoFi',
         'Green Dot Prepaid Debit Card','Lili','Discover','MoneyLion','Oxygen',
         'ACE Flare Account by Metabank','Netspend','Netspend - SkylightOne','Sable',
         'One','T-Mobile Money','Yotta','GO2bank','Varo Money','Varo',
         'MoneyLion - RoarMoney','SoFi Money','T-Mobile MONEY'
       ) THEN 'Neobank'
       ELSE 'Non-Neo' END AS bank_bucket,
  CASE WHEN COALESCE(spp.current_balance, spp.available_balance) = 0
            AND spp.delivery_method = 'debit'
       THEN 'inactive_bank' ELSE 'active_bank' END AS active_bank,
  REGEXP_EXTRACT(SPLIT(note, ':')[1], '[0-9.]+', 0) AS response_code,
  COUNT(DISTINCT spp.id)                                                                        AS paybacks,
  COUNT(DISTINCT CASE WHEN sp2.delivery_method = 'debit' AND sp2.status = 'FULLY_VERIFIED'
                      THEN sp2.id END)                                                          AS successful_debit_attempts_within_7,
  COUNT(DISTINCT CASE WHEN sp2.delivery_method IN ('ach','same_day_ach') AND sp2.status = 'FULLY_VERIFIED'
                      THEN sp2.id END)                                                          AS successful_ach_attempts_within_7,
  COUNT(DISTINCT CASE WHEN sp2.status = 'FULLY_VERIFIED' AND sp2.triggered_by = 'user_repayment'
                      THEN sp2.id END)                                                          AS user_repayments_within_7,
  SUM(spp.amount_in_dollars)                                                                    AS payback_dollars
FROM postgres.shift_pay_paybacks spp
LEFT JOIN banks_aph aph ON aph.user_id = spp.user_id AND spp.created_at::date = aph.date
LEFT JOIN postgres.shift_pay_paybacks sp2
  ON sp2.user_id = spp.user_id
  AND DATEDIFF(sp2.created_at, spp.created_at) BETWEEN 1 AND 10
WHERE spp.created_at::date > '2023-01-01'
  AND spp.status = 'RETURNED'
  AND spp.delivery_method = 'debit'
  AND spp.source = 'checkout'
GROUP BY 1, 2, 3, 4
ORDER BY 1 DESC
