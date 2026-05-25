# Product Domains

Domain-specific product context. Each subfolder covers one product area — how it works, who uses it, and what to know.

## Domain Directory

| Domain | Folder | When to load |
|---|---|---|
| HRM (Team Management) | `hrm/` | Employee onboarding, documents, job history, team management |
| Time Tracking | `time-tracking/` | Timecards, clock-in/out, breaks, payroll assistants (ACO/ACI) |
| Payroll | `payroll/` | Payroll processing, funnel (opp → ran payroll), Check integration, pay frequency, promos |
| Hiring Assistant | `hiring-assistant/` | Job posting, application funnel, trial conversion, subscriptions, ICP |
| Clover Embedded | `clover-embedded/` | Clover partnership, buy rate, rev share list, frontbook/backbook, active merchant |
| MSHR (Main Street Health Report) | `mshr/` | Aggregated small business economy report — employment, wages, hiring, turnover |

## Navigation Rules

- Each domain folder has its own CLAUDE.md — read that first to find the right file within the domain.
- If the question spans multiple domains, load only the relevant files from each — not the entire folder.
- If a domain doesn't have a folder here yet, say so. Do not infer product context from other sources.

## Behavioral Rules

- Domain files describe how the product works and who uses it. They never define metrics — metric definitions live only in `data/glossary.md`.
- If a domain file references a metric (e.g., "TT Engaged"), always validate the definition against `data/glossary.md` before using it.
- For data-specific context (gotchas, schemas, join patterns) within a product area, load from `data/product-areas/` instead.