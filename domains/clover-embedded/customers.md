---
owner: ntang
last_updated: 2026-05-08
review_cadence: quarterly
next_review: 2026-08-01
source: manual
---
# Clover Embedded — Customers

Load when answering questions about who Clover Embedded merchants are, how they're segmented, or what kind of business uses Clover Embedded.

## Merchant Segments

### Frontbook
Merchants whose Clover account was created on or after July 1, 2025. These are the merchants Homebase actively grows and invoices Clover for at tiered buy rate pricing. Frontbook is the primary growth metric for the Clover Embedded business.

### Backbook
Merchants who were on Clover's platform before July 1, 2025 and were already subscribed to a Homebase plan via Clover Marketplace. Fixed-rate pricing applies. The backbook pool is largely static — it doesn't grow with new activations.

### Excluded Backbook
A subset of backbook merchants who were already paying through Clover Marketplace before the deal. These are excluded from the monthly Buy Rate invoice because Clover bills them directly.

## Eligibility

A merchant is **eligible** for Clover Embedded when their Clover SaaS plan maps to a Homebase embedded tier. For column definitions, see `data/product-areas/clover-embedded/clover-embedded.md`.

Eligible plans are Essentials, Growth-tier plans (Restaurant Growth, Retail Growth, Services Growth, Counter Service Restaurant), Healthcare, Payments, and Register. Plans without a tier mapping (Table Service Restaurant, Starter, bundle/enterprise plans) are not eligible.

The eligible universe is defined by the Clover SaaS plan catalog — Homebase does not control which merchants are eligible. Eligible pool growth depends on Clover's merchant acquisition.

## Merchant Archetypes

**Restaurant / Food Service** — the largest segment. Typically on Restaurant Growth or Counter Service Restaurant plans. High day-to-day staff turnover makes time tracking and scheduling the most relevant Homebase features.

**Retail** — second-largest segment. Typically on Retail Growth. Shift-based scheduling is the primary value driver.

**Services / Healthcare** — smaller, typically on Services Growth or Healthcare plans. Lower turnover, more predictable schedules.

**Payments-only / Register** — Essentials and Payments plan merchants. Lower engagement with time tracking. Likely smaller businesses with fewer employees.

## Active Merchant Profile

An active Clover Embedded merchant (on the Buy Rate invoice) is:
- On a paid Clover SaaS plan with a Homebase tier mapping
- Has accessed the embedded Homebase experience at least once
- Has shown user-driven activity within the prior 90 days
- Is not already billed by Clover Marketplace (no transactions in the prior month)

As of April 2026, approximately 4,300–4,400 frontbook merchants meet all criteria and appear on the monthly invoice. The pool has been growing ~150–600/month since launch.

For exact segmentation criteria and SQL, see `data/product-areas/clover-embedded/clover-embedded.md`.
