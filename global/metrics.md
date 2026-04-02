---
owner: sammy
last_updated: 2026-03-30
review_cadence: quarterly
next_review: 2026-07-01
source: vault
refs:
  - data/engagement-metrics.md
  - data/glossary.md
---
# Company-Wide Metrics

Load when answering "what does [metric] mean?" at the company level. For SQL/column definitions, see `data/`. For domain-specific metric context, see `domains/*/okrs-and-metrics.md`.

## Top-Line Revenue Metrics

| Metric | What it measures | Why it matters |
|---|---|---|
| ARR (Annualized Run Rate) | MRR × 12 across all products | Primary top-line revenue metric |
| MRR | Monthly recurring revenue by product line | Tracks revenue trajectory and product mix |
| Unique Paying Companies | Distinct companies paying for any product | Primary customer count metric (deduplicated across products) |
| ASP (Avg Selling Price) | Revenue per paying company or location | Measures monetization efficiency and pricing health |
| NRR (Net Revenue Retention) | Revenue from existing customers vs. same cohort one year ago | Measures expansion vs. contraction within the base |

## Acquisition & Activation Metrics

| Metric | What it measures | Why it matters |
|---|---|---|
| Signups | New companies created on Homebase | Top of acquisition funnel |
| 1D1 (1-Day 1-Action) | Company completes a meaningful action within 24 hours of signup | Core activation signal; used for ad conversion tracking |
| 2D7 | Two employee logins within first 7 days | Early engagement signal predicting monetization |
| D30 Paying % | Percentage of 1D1s that become paying by day 30 | Monetization efficiency of the acquisition funnel |

## Engagement Metrics

| Metric | What it measures | Why it matters | Domains it touches |
|---|---|---|---|
| Engaged Location | Location with core product usage (TT or scheduling, 7d) AND OAM activity (30d) | Core product health signal — measures active, managed usage | All |
| Engaged 30d Retention | % of 30-day engaged locations that remain engaged next period | Stickiness of the product experience | All |
| % Paying Locs Engaged | % of paying locations that are also 30-day active | Revenue-at-risk indicator — paying but not using | All |

## Product-Specific Metrics

| Metric | Product | What it measures |
|---|---|---|
| Payroll Win Rate | Payroll | % of opportunities that convert to Transfer Start |
| NHP Completion Rate | HRM | % of new hires who complete onboarding documents |
| CO Instant Advance Rate | Cash Out | % of advances taken as instant (paid) vs. free |
| Non-Repayment Rate | Cash Out | % of advances not repaid by due date (risk metric) |
| Trial:Pay % (D14) | Hiring | % of Hiring trials converting to paid by day 14 |
| Sierra Containment Rate | Support | % of AI bot tickets resolved without human transfer |

## Customer Health Metrics

| Metric | What it measures | Why it matters |
|---|---|---|
| NPS | Net Promoter Score (rolling 30d) | Customer satisfaction and loyalty signal |
| iCSAT | Interaction satisfaction for support contacts | Quality of support experience |
| % Escalated to Human | Support interactions requiring a human agent | AI support effectiveness |
