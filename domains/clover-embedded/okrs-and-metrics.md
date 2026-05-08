---
owner: ntang
last_updated: 2026-05-08
review_cadence: quarterly
next_review: 2026-08-01
source: manual
---
# Clover Embedded — OKRs and Metrics

Load when answering questions about what success looks like for Clover Embedded, what metrics the domain tracks, and why each metric matters.

## What the Domain Optimizes For

Clover Embedded is a distribution partnership — Homebase's revenue from it is a function of how many Clover merchants become and stay active embedded users. The domain optimizes for:

1. **Growing the frontbook rev share list** — more active frontbook MIDs = higher monthly invoice to Clover
2. **Activating eligible merchants** — converting eligible merchants who haven't yet turned on Clover Embedded
3. **Retaining active merchants** — keeping activated merchants active within the 90-day window
4. **Exhibit E upsell** — frontbook merchants who additionally purchase Homebase Tip Manager, Task Manager, or a tier upgrade (20% rev share to Clover)

## Core Metrics

**Buy Rate (Rev Share List Size)**
Monthly count of frontbook merchants who are eligible, embedded, active L90, and have no Clover Marketplace transactions in the prior month. This is the primary invoice metric — Homebase invoices Clover for each of these merchants at the applicable buy rate price. For exact computation, see `data/glossary.md`.

**Embedded Activation Rate**
Percentage of eligible frontbook merchants who have activated Clover Embedded (`is_clover_embedded = true`). Measures how effectively the embedded channel converts eligible merchants. As of April 2026, ~48% of eligible frontbook merchants have activated.

**Embedded Retention (Active L90 Rate)**
Percentage of activated frontbook merchants who are active within the prior 90 days. Measures whether activated merchants stay engaged. As of April 2026, ~93% retention rate.

**Eligible Universe (Frontbook)**
Total count of frontbook merchants with a qualifying Clover SaaS plan. The addressable market for the Buy Rate invoice. Growth is driven by Clover's merchant acquisition and plan catalog changes, not by Homebase directly. Has been growing ~200/month since launch.

## Funnel

The correct funnel order (top to bottom):

```
Eligible (has qualifying Clover SaaS plan)
    ↓  Activation Rate
Embedded Activated (has accessed Homebase embedded)
    ↓  Retention Rate (L90)
Active L90
    ↓  Transaction Exclusion
On Rev Share List (invoiced to Clover)
```

## Why Each Metric Matters

| Metric | Why it matters |
|---|---|
| Rev Share List Size | Direct revenue driver — each MID on the list generates buy rate revenue |
| Eligible Universe | Upper bound on the opportunity; growth here is external (Clover-driven) |
| Activation Rate | Homebase-controllable lever — higher activation = more invoiced MIDs |
| Active L90 Rate | Retention signal — merchants falling out of L90 window reduce invoice count |
| Exhibit E upsells | Additional rev share income from high-value merchants upgrading |

## Growth Context (As of April 2026)

Monthly net new frontbook merchants on the rev share list has been decelerating:
- Jan 2026: +599
- Feb 2026: +300
- Mar 2026: +154
- Apr 2026: +160

Root causes identified: (1) eligible universe growing slowly (~+200/month); (2) pool of existing eligible-but-not-activated merchants is gradually being exhausted; (3) new merchant signups now represent ~60% of new activations, up from near-zero in January. Retention and active L90 quality remain strong (93%+). The primary growth lever is increasing new Clover merchant sign-ups flowing into the eligible pool.
