---
owner: ntang
last_updated: 2026-04-22
review_cadence: quarterly
next_review: 2026-07-01
source: manual
refs:
  - data/glossary.md
  - data/product-areas/hiring-assistant/hiring-assistant.md
---
# Hiring Assistant — OKRs and Metrics

Load when answering "what does [metric] mean for Hiring Assistant?" or questions about domain priorities.

> Metric definitions (what they mean, how computed) live in `data/glossary.md`.
> This file covers domain interpretation: what we care about and why.

## What the Domain Tracks

Success is measured across three layers:

**Volume** — Are companies using the product? Are jobs being posted, receiving applications, and progressing through the funnel?

**Quality** — Are the matches good? Screener completion rate and top match rate signal whether the product surfaces the right candidates.

**Revenue** — Are companies converting and staying? Trial conversion rate and net MRR growth measure commercial success.

## Key Metrics and Why They Matter

| Metric | Why It Matters |
|--------|---------------|
| New Job Posts | Leading indicator of adoption; drops can signal UX or trust issues |
| Applications per Job | Job market health; sudden drops may indicate syndication problems |
| Screener Completion Rate | Applicant engagement quality — higher means stronger candidate intent signal |
| Top Match Rate | Product quality signal — are the ML rankings working for managers? |
| % Healthy Jobs | End-to-end funnel health; measures whether job posts are generating enough volume and quality to be useful to employers |
| Trial Conversion Rate | Core monetization signal; measures how well the trial experience converts |
| MRR (net of discounts) | Revenue health |
| Gross MRR (list price) | Revenue capacity — what we'd earn without discounts |

## Funnel Health

Job health is the primary product quality signal — it measures whether the full funnel (application volume + candidate quality) is working end-to-end. CS monitors job health for proactive outreach to employers with underperforming posts.

For specific thresholds, time windows, and computation details, see `data/product-areas/hiring-assistant/hiring-assistant.md`.

## Hiring Attribution

When a company hires someone via Hiring Assistant, the hire is attributed by matching applicants to new team members added within a defined time window. Attribution measures hiring throughput — it is an estimate, not an exact count. For computation details, see `data/product-areas/hiring-assistant/hiring-assistant.md`.
