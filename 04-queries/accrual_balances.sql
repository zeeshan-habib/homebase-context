-- title: Cashout User Accrual Balances with Work Activity
-- description: Retrieves accrual balances for cashout users with aggregated hours worked and accrual events per pay period. Can be used to identify actively working users.
-- category: ee-experience
-- tags: [cashout, accrual, earnings, pay-period, shift-pay]
-- author: KPMcDonough49
-- notes: The sum of all accrual events for a pay period equals the balance in shift_pay_accrual_balances. Add a WHERE clause on user_id or date range to scope results.

SELECT
  ab.id,
  ab.user_id,
  ab.amount_in_dollars        AS amount_accrued,
  ab.start_date               AS pay_period_start,
  ab.end_date                 AS pay_period_end,
  SUM(ae.hours)               AS hours_worked,
  COUNT(DISTINCT ae.created_at) AS unique_accrual_events
FROM postgres.shift_pay_accrual_balances ab
LEFT JOIN postgres.shift_pay_accrual_events ae
  ON ae.accrual_balance_id = ab.id
GROUP BY 1, 2, 3, 4, 5
