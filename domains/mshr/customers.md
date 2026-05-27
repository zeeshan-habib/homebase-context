---
owner: ray-sanza, vlad
last_updated: 2026-05-14
review_cadence: monthly
next_review: 2026-06-14
source: internal
refs: []
---

<!-- Load when: understanding who uses MSHR, their roles, and what they need from the report -->

# MSHR Customers & Stakeholders

## Audience Architecture

MSHR has a two-tier audience model. The internal tier consumes raw data and analysis; the external tier consumes polished reports derived from that analysis.

```
Homebase platform data
        ↓
  [MSHR production]
        ↓
  Internal audience  →  Public-facing reports  →  External audience
```

## Internal Audience

These are the people who use this domain repo directly — they direct what gets built and consume the analytical output.

| Stakeholder | Role | What they need from MSHR |
|---|---|---|
| Ray Sanza | Chief Strategy Officer (DRI) | Economy-level employment trends to frame Homebase's market narrative and GTM strategy |
| Katie Dare | Chief Marketing Officer | PR narrative, press releases, and public-facing data points — needs the same economy-level signals as Ray, framed for media and external audiences |
| Vlad Akimenko | Data / Analytics Lead | Metric definitions, table locations, production logic to run and QA the report |
| GTM Team | Marketing / Revenue | Data points and narratives for press releases, sales collateral, and research publications |

## External Audience (Public Reports)

The internal audience transforms MSHR data into public-facing content. Claude and this domain do not directly serve the external audience — but understanding them shapes which metrics matter and how they are framed.

| Audience segment | What they care about |
|---|---|
| Media / press | Simple, quotable numbers: "small business hiring up X% month-over-month" |
| Policymakers / researchers | Methodology, sample size, geographic and sector breakdowns |
| Small business owners (Homebase customers) | How their own situation compares to national trends |
| Investors / analysts | Macro employment signals; Homebase as a data provider with unique coverage |

## What "Internal Use" Means for This Repo

- All files in this domain are internal only — do not include anything that cannot be shared internally (no PII, no customer-identifiable data)
- Metric definitions and table names are internal; the public reports will present derived outputs only

