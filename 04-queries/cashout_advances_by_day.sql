-- title: Cashout Advances by Day
-- description: Daily count of settled cashout advances, unique users, and fee revenue. Core metric for tracking cashout volume trends.
-- category: ee-experience
-- tags: [cashout, advances, daily, revenue, volume]
-- author: KPMcDonough49
-- notes: Always filter source IN ('plaid','synapse','checkout') for cashout — 'banking' is the banking product. status = 'SETTLED' excludes pending and failed advances.

SELECT
  advance_date::date          AS date,
  COUNT(DISTINCT advance_id)  AS advances,
  COUNT(DISTINCT user_id)     AS users,
  SUM(fee_in_dollars)         AS revenue
FROM public.cashout_advances
WHERE source IN ('plaid', 'synapse', 'checkout')
  AND status = 'SETTLED'
GROUP BY 1
ORDER BY 1 DESC
