# homebase-context

## What is this?

This repository contains markdown files that provide business context, metric definitions, and domain knowledge across all Homebase functions. These files enable AI tools (like Claude with GitHub MCP) to generate accurate, relevant insights for product teams without requiring deep institutional knowledge.

## File Index

Load the relevant files for your task:

| File | When to load |
|---|---|
| `instructions/analyst-instructions.md` | Any analytics request — behavioral rules for how to respond |
| `instructions/analytics-environment.md` | Any SQL or data query — environment setup and layer guidance |
| `data/glossary.md` | When metric definitions or terminology are needed |
| `data/engagement-metrics.md` | Engagement or activity metric questions |
| `data/locations.md` | Location or company status questions |
| `data/date-conventions.md` | Any query with date filtering, grouping by period, period-over-period comparisons, or cohort day windows (D1, D14, D30, etc.) |
| `data/product-domains/timetracking.md` | Timecards, clock-in/out, breaks, manager edits, ACO/ACI |

## Contributing

See [`context-file-style-guide.md`](context-file-style-guide.md) for authoring guidelines.
