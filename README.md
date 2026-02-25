# homebase-context

## What is this?

This repository contains markdown files that provide business context, metric definitions, and domain knowledge across all Homebase functions. These files enable AI tools (like Claude with GitHub MCP) to generate accurate, relevant insights for product teams without requiring deep institutional knowledge.

## File Index

Load the relevant files for your task:

| File | When to load |
|---|---|
| `01-instructions/analyst-instructions.md` | Any analytics request — behavioral rules for how to respond |
| `01-instructions/analytics-environment.md` | Any SQL or data query — environment setup and layer guidance |
| `03-data/glossary.md` | When metric definitions or terminology are needed |
| `03-data/engagement-metrics.md` | Engagement or activity metric questions |
| `03-data/locations.md` | Location or company status questions |
| `03-data/date-conventions.md` | Any query with date filtering, grouping by period, period-over-period comparisons, or cohort day windows (D1, D14, D30, etc.) |
| `03-data/product-domains/timetracking.md` | Timecards, clock-in/out, breaks, manager edits, ACO/ACI |

## Contributing

See [`context-file-style-guide.md`](context-file-style-guide.md) for authoring guidelines.
