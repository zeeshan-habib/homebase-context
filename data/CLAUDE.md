# Data Context

The precision layer. Always load `glossary.md` first for any metric or term question - it is the canonical index of all analytics-approved metric definitions.

## Always Load

| File | Why |
|---|---|
| `glossary.md` | Canonical metric definitions, disambiguation rules, pointers to deeper files |
| `date-conventions.md` | Date filtering, period grouping, cohort windows (D1, D14, D30, etc.) |

## Load When Relevant

| File | When to load |
|---|---|
| `business-data-reference.md` | Entity relationships, key tables, join patterns, diagnostic patterns for metric movements |
| `engagement-metrics.md` | Engagement metric questions related to product usage |
| `activation-metrics.md` | Activation or onboarding metric questions |
| `locations.md` | Location-level questions |

## Product Areas

| File | When to load |
|---|---|
| `product-areas/timetracking.md` | Timecards, clock-in/out, breaks, manager edits, ACO/ACI |
| `product-areas/scheduling.md` | Shifts, schedules, open shifts, publishing, shift edits, shift trades |
| `product-areas/cash-out/` | Cash Out advances, eligibility, financials, funnel, experiments |
| `product-areas/hiring-assistant.md` | Hiring-related data |

## Rules

- Never define metrics outside of `glossary.md`. If a metric is missing, add it there.
- If a question involves a metric not in the glossary, say so. Do not guess a definition.
