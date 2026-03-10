-- title: First-Time vs. Repeat Cashout Enrollments
-- description: Returns all cashout enrollment eligibility checks with a flag indicating whether each is the user's first enrollment or a repeat. Can be aggregated by day, week, or month.
-- category: ee-experience
-- tags: [cashout, enrollment, eligibility, first-time, repeat]
-- author: KPMcDonough49
-- notes: triggered_by = 'enrollment' means the user just enrolled (vs. a background re-check). source = 'plaid' filters to cashout enrollments only (vs. banking). The first row per user in shift_pay_eligibilities = first enrollment.

WITH first_enrollments AS (
  SELECT user_id, MIN(created_at) AS first_enrollment
  FROM postgres.shift_pay_eligibilities
  WHERE source = 'plaid'
  GROUP BY 1
)

SELECT
  spe.created_at,
  spe.user_id,
  spe.eligible,
  spe.triggered_by,
  spe.plaid_item_id,
  CASE WHEN fe.first_enrollment = spe.created_at THEN 'first time' ELSE 'repeat' END AS enrollment_bucket
FROM postgres.shift_pay_eligibilities spe
LEFT JOIN first_enrollments fe ON fe.user_id = spe.user_id
WHERE spe.triggered_by = 'enrollment'
  AND spe.source = 'plaid'
