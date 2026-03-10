-- title: Cashout Eligibility and Activation by Enrollment Week
-- description: Weekly cohort view of new cashout enrollees showing how many passed KYC, verified a debit card, reached eligible user state (B/B2), hit D6, and took a first advance within 7 days.
-- category: ee-experience
-- tags: [cashout, eligibility, activation, kyc, debit-card, d6, enrollment, cohort]
-- author: KPMcDonough49
-- notes: D6 state = user failed KYC or lacks a valid debit card. B and B2 states = eligible to cash out. All lookbacks are within 7 days of first enrollment. Source = 'plaid' for cashout enrollments.

WITH new_enrolls AS (
  SELECT user_id, MIN(created_at) AS first_enrollment
  FROM postgres.shift_pay_eligibilities
  WHERE source = 'plaid'
  GROUP BY 1
)

SELECT
  DATE_TRUNC('week', ne.first_enrollment)::date                                              AS enrollment_week,
  COUNT(DISTINCT ne.user_id)                                                                  AS enrollments,
  COUNT(DISTINCT CASE WHEN kyc.risk_status = 'success' THEN ne.user_id END)                  AS passed_kyc,
  COUNT(DISTINCT CASE WHEN spdc.auth_status = 'verified' THEN ne.user_id END)                AS debit_card_verified,
  COUNT(DISTINCT CASE WHEN us.user_state IN ('B', 'B2') THEN ne.user_id END)                 AS eligible_users,
  COUNT(DISTINCT CASE WHEN us.user_state = 'D6' THEN ne.user_id END)                         AS users_in_d6,
  COUNT(DISTINCT ca.user_id)                                                                  AS cashout_users
FROM new_enrolls ne
LEFT JOIN postgres.kyc_identity_verifications kyc
  ON kyc.user_id = ne.user_id
  AND DATEDIFF(kyc.created_at::date, ne.first_enrollment::date) BETWEEN 0 AND 7
LEFT JOIN postgres.shift_pay_checkout_debit_cards spdc
  ON spdc.user_id = ne.user_id
  AND DATEDIFF(spdc.created_at::date, ne.first_enrollment::date) BETWEEN 0 AND 7
LEFT JOIN ext_firehose.shift_pay_user_state_events us
  ON us.user_id = ne.user_id
  AND DATEDIFF(us.created_at::date, ne.first_enrollment::date) BETWEEN 0 AND 7
LEFT JOIN public.cashout_advances ca
  ON us.user_id = ca.user_id
  AND DATEDIFF(ca.advance_date, ne.first_enrollment::date) BETWEEN 0 AND 7
GROUP BY 1
ORDER BY 1 DESC
