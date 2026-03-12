-- title: Active Payroll Companies on ACH Payment Method
-- description: Pulls active payroll companies (payroll_state = 7) whose current Stripe subscription payment method is ACH (us_bank_account). One row per company with owner contact info.
-- category: revenue
-- tags: [payroll, ach, stripe, billing, payment-method, companies, owners]
-- author: KPMcDonough49
-- notes: Active payroll = payroll_state = 7 in payroll_setup_infos. ACH identified via stripe.payment_method where type = 'us_bank_account'. Deduped to one row per company_id. Only includes companies with at least one non-archived location.

WITH active_payroll_companies AS (
    SELECT DISTINCT
        company_id,
        payroll_state AS payroll_status
    FROM prod_redshift_replica.postgres.payroll_setup_infos
    WHERE payroll_state = 7
),

ach_subscriptions AS (
    -- Companies whose current subscription payment method is ACH
    SELECT DISTINCT
        bc.company_id
    FROM prod_redshift_replica.postgres.biller_customers bc
    JOIN prod_redshift_replica.stripe.customer_subscription ss
        ON ss.customer = bc.customer_id
        AND ss.status IN ('active', 'trialing')
        AND ss.row_deleted_at IS NULL
    JOIN prod_redshift_replica.stripe.payment_method spm
        ON spm.id = ss.default_payment_method
        AND spm.type = 'us_bank_account'                 -- ACH bank account in Stripe
        AND spm.row_deleted_at IS NULL
)

SELECT DISTINCT
    c.company_id,
    c.name                              AS company_name,
    c.owner_id,
    u.first_name                        AS owner_first_name,
    u.email                             AS owner_email
FROM active_payroll_companies apc
JOIN prod_redshift_replica.public.companies c
    ON c.company_id = apc.company_id
JOIN ach_subscriptions ach
    ON ach.company_id = apc.company_id
LEFT JOIN prod_redshift_replica.public.users u
    ON u.user_id = c.owner_id
WHERE EXISTS (
    SELECT 1
    FROM prod_redshift_replica.public.locations l
    WHERE l.company_id = c.company_id
      AND l.archived_at IS NULL
)
ORDER BY
    c.company_id;
