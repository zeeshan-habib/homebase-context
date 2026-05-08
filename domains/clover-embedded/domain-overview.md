---
owner: ntang
last_updated: 2026-05-08
review_cadence: quarterly
next_review: 2026-08-01
source: manual
---
# Clover Embedded — Domain Overview

Load when answering questions about what Clover Embedded is, how the partnership works, or the lifecycle of a Clover merchant on Homebase.

## What Clover Embedded Is

Clover Embedded is a B2B2C distribution partnership between Homebase and Clover (Fiserv). Homebase embeds its timesheets and Time Clock app natively inside the Clover SaaS experience. Clover merchants get Homebase features as part of their Clover plan — they do not need to sign up for Homebase directly.

**Deal term:** July 1, 2025 – June 30, 2028.

## Deal Structure

**Revenue Model:** Clover pays Homebase a monthly "Buy Rate" per active embedded merchant (MID). The Buy Rate is a per-MID price that varies by Clover SaaS plan tier and total MID volume. Separately, Homebase pays Clover a 20% revenue share on any direct-billed Homebase subscriptions, Task Manager, and Tip Manager purchases made by Clover Embedded merchants (Exhibit E).

**Invoicing:** Homebase invoices Clover monthly within 5 business days of receiving Clover's data file. The invoice is based on the active MID count at month end.

**Modules in scope:**
- **Timesheets & Time Clock** — included in embedded bundle as of July 2025
- **Scheduling** — development began September 2025
- **Tip Manager** — included if both parties agree
- **Task Manager** — treated as an add-on; rev share applies

## Product Journey

A typical Clover merchant's journey into the Homebase embedded experience:

1. **Merchant connects to Clover** — gets a Clover merchant ID (MID) and subscribes to a Clover SaaS plan
2. **Becomes eligible** — their Clover SaaS plan maps to a Homebase embedded tier
3. **Activates Clover Embedded** — merchant accesses the Homebase embedded experience via Clover
4. **Remains active** — shows user-driven activity on Homebase or Clover embedded within prior 90 days
5. **Counted on Buy Rate invoice** — if frontbook, eligible, embedded, active L90, and no Clover Marketplace transactions in the prior month

## Lifecycle Concepts

### Active Merchant (Contract Definition)
Per Exhibit D §2.4.1, a merchant is **Active** if:
1. On a paid Clover SaaS plan
2. Has accessed the Clover.com embedded Homebase experience at least once
3. Shows user-driven activity on Homebase platform or Clover embedded experience
4. Activity occurred within prior 90 days

For column definitions, see `data/product-areas/clover-embedded/clover-embedded.md`.

### Frontbook vs Backbook (Contract Definition)
Per Exhibit D §2.4.2–2.4.3, the split date is **July 1, 2025**:
- **Frontbook** — Clover merchant created on or after July 1, 2025. Subject to tiered buy rate pricing.
- **Backbook** — Clover merchant created before July 1, 2025. Fixed rate pricing.
- **Excluded Backbook** — Backbook merchants already billing through Clover Marketplace; excluded from the Buy Rate invoice entirely (Clover is already billing them directly).

For table definitions, see `data/product-areas/clover-embedded/clover-embedded.md`.

### Rev Share List (Exhibit D)
The monthly list Homebase invoices Clover for. Includes locations that are:
- Frontbook
- Eligible (Clover SaaS plan maps to a Homebase tier)
- Embedded activated
- Active L90
- No Clover Marketplace transactions in the prior month

### Exhibit E — Upsell Rev Share
When a Clover Embedded merchant purchases an additional Homebase subscription (Tip Manager, Task Manager, or a Homebase tier upgrade) on or after September 23, 2025, Homebase reports it to Clover and pays a 20% rev share.

## Clover SaaS Plan → Homebase Tier Mapping

| Clover SaaS Plan | Homebase Tier | Clover Eligible SaaS Tier |
|---|---|---|
| Essentials, Healthcare, Payments, Register | Basic (Tier 1) | 1 |
| Restaurant Growth, Retail Growth, Services Growth, Counter Service Restaurant | Essentials (Tier 2) | 2 |
| Clover Pro (launching 2026) | Plus (Tier 3) | — |

Plans with NULL tier (Table Service Restaurant, Starter, Bundle plans, Enterprise plans) have a Clover plan name but are not mapped to a Homebase tier.

## Non-Solicitation Obligation

Per Exhibit F §3.1, Homebase **must not** target Clover Payroll customers (including ADP-referred merchants) with any mention of Homebase Payroll or payroll promotions. A prohibited merchant list is maintained via Clover API and monthly flat file. This restriction applies across Sales, Marketing, Support, AI/automation, and product surfaces.

## Domain Boundaries

| Clover Embedded Owns | Does NOT Own |
|---|---|
| Buy Rate invoice and rev share reporting | Core Homebase subscription billing (Payroll) |
| Active merchant classification | Employee-level time tracking data |
| Frontbook/backbook segmentation | Homebase product development roadmap |
| Exhibit D/E monthly reporting | Clover Payroll (prohibited — non-solicit obligation) |
