# homebase-context

## What is this?

This repository contains markdown files that provide business context, metric definitions, and domain knowledge across all Homebase functions. These files enable AI tools (like Claude with GitHub MCP) to generate accurate, relevant insights for product teams without requiring deep institutional knowledge.

## How to use this repo

Load the README first to understand what's available, then load the relevant files for your task:

| File | When to load |
|---|---|
| `01-behavioural-analytics-instructions/analyst-instructions.md` | Any analytics request — behavioral rules for how to respond |
| `01-behavioural-analytics-instructions/analytics-environment.md` | Any SQL or data query — environment setup and layer guidance |
| `context_files/homebase_glossary_table.md` | When metric definitions or terminology are needed |
| `context_files/core_engagement_metrics_context.md` | Engagement or activity metric questions |
| `context_files/locations_context.md` | Location or company status questions |

## What's included

- **Gold standard metric definitions** for key business areas
- **Business context and instructions** for understanding ambiguous queries
- **Domain-specific knowledge** covering every company function
- **SQL reference files** with technical details (joins, filters, etc.)
- **Prioritization guidance** to help AI identify the most relevant metrics
