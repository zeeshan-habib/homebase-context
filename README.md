# homebase-context

## What is this?

This repository contains markdown files that provide business context, metric definitions, and domain knowledge across all Homebase functions. These files enable AI tools (like Claude with GitHub MCP) to generate accurate, relevant insights for product teams without requiring deep institutional knowledge.

## File Index

Load the relevant files for your task:

| File | When to load |
|---|---|
| `01-behavioural-analytics-instructions/analyst-instructions.md` | Any analytics request — behavioral rules for how to respond |
| `01-behavioural-analytics-instructions/analytics-environment.md` | Any SQL or data query — environment setup and layer guidance |
| `context_files/homebase_glossary_table.md` | When metric definitions or terminology are needed |
| `context_files/core_engagement_metrics_context.md` | Engagement or activity metric questions |
| `context_files/locations_context.md` | Location or company status questions |
| `context_files/date_conventions_context.md` | Any query with date filtering, grouping by period, period-over-period comparisons, or cohort day windows (D1, D14, D30, etc.) |

## Contributing

See [`context-file-style-guide.md`](context-file-style-guide.md) for authoring guidelines.
