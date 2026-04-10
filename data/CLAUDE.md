# Data Context

Metric definitions, schema reference, and product-area data guides.

## File Index

| File | When to load |
|---|---|
| `glossary.md` | Any metric question — this is the canonical source for all metric definitions. Always check here first. |
| `schema-reference.md` | Core tables, join patterns, key identifiers, locations schema, pricing tier data columns |
| `engagement/engagement-metrics.md` | Detailed engagement boolean definitions — thresholds, lookback windows, column names |

## Product Areas

| Folder/File | When to load |
|---|---|
| `product-areas/time-tracking/` | Time tracking data gotchas, join caveats, disambiguation |
| `product-areas/scheduling.md` | Scheduling-specific data context |
| `product-areas/cash-out/` | Cash Out data — eligibility, financials, funnel, experiments |
| `product-areas/hiring-assistant.md` | Hiring-specific data context |
| `product-areas/hrm/` | HRM data — NHP funnel gotchas, onboarding metrics, HR Docs engagement caveats |
| `product-areas/payroll/` | Payroll data — key tables, MRR components, cohort definitions, join gotchas, churn groupings |

## Navigation Rules

- Always load `glossary.md` first for any metric question. It contains brief definitions and links to detailed files when more context is needed.
- Only load `schema-reference.md` if the question requires knowing which tables to query, how to join them, or what columns exist.
- Only load a product-area file if the question is specifically about that domain’s data nuances.

## Behavioral Rules

- `glossary.md` is the single source of truth for metric definitions. Never define metrics elsewhere.
- If a metric, table, or column is not documented in these files, say so. Do not guess or invent.
- Product-area files contain data gotchas and schema context, not product descriptions. For how the product works, load from `domains/` instead.
