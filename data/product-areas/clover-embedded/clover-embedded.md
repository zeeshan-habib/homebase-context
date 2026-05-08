# Clover Embedded — Data Field Guide

> For product context (what Clover Embedded is, deal structure, merchant archetypes, OKRs), see `domains/clover-embedded/`.
> For metric definitions, see `data/glossary.md`.

## When to Use This File

Use when querying: Buy Rate invoice counts, rev share list composition, frontbook/backbook segmentation, embedded activation funnel, active L90 analysis, Exhibit D/E reporting, or validating plan data between the snapshot and postgres tables.

## Key Metrics

| Metric | Computation | Notes |
|---|---|---|
| Rev Share List (Buy Rate) | `COUNT(DISTINCT location_id)` where frontbook + eligible + embedded + active L90 + no marketplace transactions | Grain: location or merchant_id; see frontbook join pattern below |
| Eligible Universe | `COUNT(DISTINCT location_id)` where `is_clover_embedded_eligible = true` AND frontbook | Top of funnel; driven by Clover SaaS plan assignment |
| Embedded Activation Rate | `activated / NULLIF(eligible, 0)` | `activated` = `is_clover_embedded = true` |
| Active L90 Rate | `active_l90 / NULLIF(activated, 0)` | `active_l90` = rolling 90-day active window |
| Excluded (Marketplace txns) | `COUNT(DISTINCT location_id)` where active L90 + has Clover Marketplace transactions | These are subtracted from the invoice list |

## Frontbook / Backbook Classification

Frontbook = not in either backbook table. Always join both:

```sql
LEFT JOIN ext_gs_billing.clover_homebase_snapshot_20250702 fb ON fb.clover_id = f.merchant_id
LEFT JOIN ext_gs_billing.backbook_clover_marketplace_users eb ON eb.clover_id = f.merchant_id
-- Frontbook: fb.clover_id IS NULL AND eb.clover_id IS NULL
-- Backbook: fb.clover_id IS NOT NULL AND eb.clover_id IS NULL
-- Excluded Backbook: eb.clover_id IS NOT NULL
```

## Active L90 Definition

The contract definition of "active" is a 90-day rolling window. Compute via window function — do NOT use the point-in-time `is_active` column alone:

```sql
MAX(CASE WHEN is_active THEN 1 ELSE 0 END)
  OVER (
    PARTITION BY location_id
    ORDER BY date
    RANGE BETWEEN INTERVAL 90 DAYS PRECEDING AND CURRENT ROW
  ) = 1 AS active_P90
```

When filtering to a snapshot date, pull data from 90 days before the earliest date in your window to ensure accurate lookback.

## Buy Rate Pricing

### Frontbook (July 1, 2025 or later)

| Clover SaaS Plan | Homebase Tier | MID Range | Price/MID |
|---|---|---|---|
| Essentials (HB Basic) | Tier 1 | 0–15,000 | $3.41 |
| | | 15,001–30,000 | $2.71 |
| | | 30,001–40,000 | $1.84 |
| | | 40,000+ | $1.49 |
| Growth plans (HB Essentials) | Tier 2 | 0–11,500 | $12.54 |
| | | 11,501–18,500 | $11.69 |
| | | 18,501–30,000 | $10.41 |
| | | 30,000+ | $9.56 |
| Pro (HB Plus, launching 2026) | Tier 3 | 0–5,000 | $22.19 |
| | | 5,001–8,000 | $20.94 |
| | | 8,001–11,000 | $19.06 |
| | | 11,000+ | $16.88 |

### Backbook (Fixed)
- Essentials (HB Basic): $3.41/MID
- Growth (HB Essentials): $12.54/MID

## Key Tables

| Table | Purpose | Key Notes |
|---|---|---|
| `prod_datamarts.locations_datamart.fact_locations_clover_daysnapshot` | Daily snapshot of all Clover-connected locations | Grain: location_id × date. Contains ~3.9B rows (all history). Filter `merchant_id IS NOT NULL` for Clover locations only. |
| `postgres.point_of_sale_clover_customer_features` | Live Clover merchant feature data, updated via Clover API | More current than daysnapshot for plan data. Dedup: `ROW_NUMBER() OVER (PARTITION BY merchant_id ORDER BY updated_at DESC) = 1` |
| `ext_gs_billing.clover_homebase_snapshot_20250702` | Backbook merchants — Clover Marketplace subscribers as of July 2025 | Static snapshot. Join on `clover_id = merchant_id`. |
| `ext_gs_billing.backbook_clover_marketplace_users` | Excluded backbook — merchants already paying Clover directly | Static. Join on `clover_id = merchant_id`. Excluded from all Buy Rate invoices. |
| `ext_billing.clover_transactions` | Clover Marketplace transaction records | Used to identify merchants already paying through Clover Marketplace. Filter: `status NOT IN ('REFUNDED', 'CANCELED')`. Join: `merchant_id`. |
| `public.locations` | Homebase location master | Required: INNER JOIN to exclude fake/demo locations. Contains `first_clover_embedded_activated_date` and `clover_merchant_id`. |

### Key Columns in `fact_locations_clover_daysnapshot`

| Column | Type | Notes |
|---|---|---|
| `location_id` | int | Homebase location ID |
| `date` | date | Snapshot date |
| `merchant_id` | string | Clover MID. NULL = non-Clover location |
| `is_clover_embedded` | boolean | True = merchant has activated Clover Embedded |
| `is_clover_embedded_eligible` | boolean | True = merchant's Clover plan maps to a Homebase tier |
| `clover_saas_plan` | string | Clover SaaS plan name (e.g., "Restaurant Growth"). NULL if not eligible |
| `clover_eligible_saas_tier` | int | 1 = Basic, 2 = Essentials. NULL for unmapped plans |
| `clover_eligible_market_tier` | int | Clover Marketplace tier (1 = basic/free) |
| `homebase_tier_id` | int | Current Homebase subscription tier |
| `billing_source` | string | How the location is billed (Homebase, Clover, Square, etc.) |
| `is_active` | boolean | Point-in-time active flag. Use rolling window for L90. |

## Key Business Logic & Caveats

**`is_clover_embedded_eligible` ≈ `clover_saas_plan IS NOT NULL`**
These two columns are functionally equivalent in the fact table. All locations with `eligible = true` have a non-null plan name, and virtually all with `eligible = false` have a null plan. The 52 edge cases (eligible=false but plan not null) are unmapped plan types.

**NULL `clover_eligible_saas_tier` ≠ ineligible**
Some plans (Table Service Restaurant, Starter, Register Bundle, enterprise plans) have a `clover_saas_plan` name but `clover_eligible_saas_tier = NULL`. These are not mapped to a Homebase tier. Don't conflate NULL tier with NULL plan.

**`first_clover_embedded_activated_date` in `public.locations` is the canonical activation timestamp**
The daysnapshot shows `is_clover_embedded = true` from the day it first appears, but `public.locations.first_clover_embedded_activated_date` is more reliable for point-in-time activation analysis. Use it for activation cohorts. Both tables should agree on whether a merchant is activated (validated May 2026: 0 discrepancy).

**Plan data can lag in the daysnapshot**
`postgres.point_of_sale_clover_customer_features` is refreshed via Clover API more frequently than the daysnapshot. A lag of ~14k merchants with plans in postgres but null plans in the snapshot was identified in May 2026 and resolved within the same week. If plan coverage looks low in the snapshot, cross-check against postgres.

**Transaction exclusion window**
In the rev share list query, the Clover Marketplace transaction lookback is: `charge_date BETWEEN DATEADD(MONTH, -1, DATE_TRUNC('month', snapshot_date)) AND snapshot_date`. This covers the prior calendar month up to the snapshot date.

**Fake/demo location exclusion**
Always INNER JOIN `public.locations` to exclude demo companies. Do NOT rely solely on `merchant_id IS NOT NULL`.

**`billing_source` is informational only**
Do not use `billing_source` to classify frontbook/backbook. Use the dedicated backbook snapshot tables instead. `billing_source = 'Clover'` does not mean the merchant is backbook — many frontbook merchants are billed through Clover's platform.

**Tiers can exceed the Clover provisioned floor**
Merchants can purchase Homebase at a higher tier than what Clover Embedded provisions. A tier 4 Homebase subscriber on a tier 2 Clover plan is normal — they upgraded voluntarily. Merchants cannot go below their Clover-provisioned floor.

## Example SQL Queries

### Rev Share List at Month End

```sql
WITH active_with_p90 AS (
  SELECT
    f.location_id,
    f.date,
    f.merchant_id,
    f.clover_saas_plan,
    f.clover_eligible_saas_tier,
    MAX(CASE WHEN f.is_active THEN 1 ELSE 0 END)
      OVER (
        PARTITION BY f.location_id
        ORDER BY f.date
        RANGE BETWEEN INTERVAL 90 DAYS PRECEDING AND CURRENT ROW
      ) = 1 AS active_P90
  FROM prod_datamarts.locations_datamart.fact_locations_clover_daysnapshot f
  -- Pull 90 days before snapshot date to ensure accurate lookback
  WHERE f.date BETWEEN DATE('2026-02-01') AND DATE('2026-04-30')
    AND f.is_clover_embedded = true
    AND f.is_clover_embedded_eligible = true
),
eligible_frontbook AS (
  SELECT a.date, a.location_id, a.merchant_id, a.clover_saas_plan, a.clover_eligible_saas_tier
  FROM active_with_p90 a
  INNER JOIN public.locations l ON l.location_id = a.location_id
  LEFT JOIN ext_gs_billing.clover_homebase_snapshot_20250702 fb ON fb.clover_id = a.merchant_id
  LEFT JOIN ext_gs_billing.backbook_clover_marketplace_users eb ON eb.clover_id = a.merchant_id
  WHERE a.date = DATE('2026-04-30')
    AND a.active_P90 = true
    AND fb.clover_id IS NULL  -- not backbook
    AND eb.clover_id IS NULL  -- not excluded backbook
),
with_transactions AS (
  SELECT
    ef.*,
    COUNT(DISTINCT ct.charge_id) AS marketplace_transaction_count
  FROM eligible_frontbook ef
  LEFT JOIN ext_billing.clover_transactions ct
    ON ct.merchant_id = ef.merchant_id
    AND ct.charge_date BETWEEN DATEADD(MONTH, -1, DATE_TRUNC('month', ef.date)) AND ef.date
    AND ct.status NOT IN ('REFUNDED', 'CANCELED')
  GROUP BY ef.date, ef.location_id, ef.merchant_id, ef.clover_saas_plan, ef.clover_eligible_saas_tier
)
SELECT
  COUNT(DISTINCT CASE WHEN marketplace_transaction_count = 0 THEN location_id END) AS rev_share_list,
  COUNT(DISTINCT CASE WHEN marketplace_transaction_count > 0 THEN location_id END) AS excluded_marketplace
FROM with_transactions
```

### Activation Funnel (Frontbook) Over Time

```sql
WITH date_spine AS (
  SELECT snapshot_date
  FROM (VALUES
    (DATE('2026-01-31')), (DATE('2026-02-28')),
    (DATE('2026-03-31')), (DATE('2026-04-30'))
  ) t(snapshot_date)
),
base AS (
  SELECT
    f.location_id, f.date, f.merchant_id,
    f.is_clover_embedded, f.is_clover_embedded_eligible,
    MAX(CASE WHEN f.is_active THEN 1 ELSE 0 END)
      OVER (PARTITION BY f.location_id ORDER BY f.date
            RANGE BETWEEN INTERVAL 90 DAYS PRECEDING AND CURRENT ROW) = 1 AS active_P90
  FROM prod_datamarts.locations_datamart.fact_locations_clover_daysnapshot f
  WHERE f.date BETWEEN DATE('2025-10-01') AND DATE('2026-04-30')
)
SELECT
  b.date AS snapshot_date,
  COUNT(DISTINCT CASE WHEN b.is_clover_embedded_eligible = true THEN b.location_id END)                              AS eligible,
  COUNT(DISTINCT CASE WHEN b.is_clover_embedded_eligible = true AND b.is_clover_embedded = true THEN b.location_id END) AS activated,
  COUNT(DISTINCT CASE WHEN b.is_clover_embedded_eligible = true AND b.is_clover_embedded = true AND b.active_P90 THEN b.location_id END) AS active_l90
FROM base b
INNER JOIN date_spine d ON b.date = d.snapshot_date
INNER JOIN public.locations l ON l.location_id = b.location_id
LEFT JOIN ext_gs_billing.clover_homebase_snapshot_20250702 fb ON fb.clover_id = b.merchant_id
LEFT JOIN ext_gs_billing.backbook_clover_marketplace_users eb ON eb.clover_id = b.merchant_id
WHERE fb.clover_id IS NULL AND eb.clover_id IS NULL  -- frontbook only
GROUP BY 1
ORDER BY 1
```

### New Activations by Source (New Signup vs Existing Company)

```sql
-- Uses public.locations as activation source of truth
WITH first_seen_in_table AS (
  SELECT location_id, MIN(date) AS first_seen_date
  FROM prod_datamarts.locations_datamart.fact_locations_clover_daysnapshot
  GROUP BY location_id
)
SELECT
  DATE_TRUNC('month', l.first_clover_embedded_activated_date) AS activation_month,
  COUNT(DISTINCT l.location_id)                                 AS total_activations,
  COUNT(DISTINCT CASE WHEN DATE_TRUNC('month', ft.first_seen_date) = DATE_TRUNC('month', l.first_clover_embedded_activated_date)
                      THEN l.location_id END)                   AS from_new_signups,
  COUNT(DISTINCT CASE WHEN DATE_TRUNC('month', ft.first_seen_date) < DATE_TRUNC('month', l.first_clover_embedded_activated_date)
                      THEN l.location_id END)                   AS from_existing_companies
FROM public.locations l
LEFT JOIN ext_gs_billing.clover_homebase_snapshot_20250702 fb ON fb.clover_id = l.clover_merchant_id
LEFT JOIN ext_gs_billing.backbook_clover_marketplace_users eb ON eb.clover_id = l.clover_merchant_id
LEFT JOIN first_seen_in_table ft ON ft.location_id = l.location_id
WHERE l.first_clover_embedded_activated_date IS NOT NULL
  AND fb.clover_id IS NULL AND eb.clover_id IS NULL
  AND DATE_TRUNC('month', l.first_clover_embedded_activated_date) >= DATE('2026-01-01')
GROUP BY 1
ORDER BY 1
```

### Validate Plan Data: Snapshot vs Postgres

```sql
-- Identifies merchants with null plan in snapshot but valid plan in postgres
-- Use to detect daysnapshot pipeline lag
WITH snapshot AS (
  SELECT merchant_id, clover_saas_plan, clover_eligible_saas_tier
  FROM prod_datamarts.locations_datamart.fact_locations_clover_daysnapshot
  WHERE date = DATE('2026-05-06') AND merchant_id IS NOT NULL
),
postgres_latest AS (
  SELECT merchant_id, clover_saas_plan_name, eligible_saas_tier
  FROM (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY merchant_id ORDER BY updated_at DESC) AS rn
    FROM postgres.point_of_sale_clover_customer_features
  ) WHERE rn = 1
)
SELECT
  COUNT(DISTINCT CASE WHEN s.clover_saas_plan IS NULL AND p.clover_saas_plan_name IS NOT NULL
                      THEN s.merchant_id END) AS null_in_snapshot_has_plan_in_postgres
FROM snapshot s
INNER JOIN postgres_latest p ON p.merchant_id = s.merchant_id
```

## Resources

- **Notebook (Month End Reporting)**: `homebase-staging / Users/ntang@joinhomebase.com/Clover Embedded/Month End Clover Embedded Reporting` (ID: 175504305246886)
- **Exhibit D**: Active merchant definition, frontbook/backbook split, buy rate pricing, invoice process
- **Exhibit E**: Upsell rev share (Tip Manager, Task Manager, tier upgrades)
- **Exhibit F §3.1**: Non-solicitation obligation for Clover Payroll merchants
