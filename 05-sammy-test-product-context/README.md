# Product Context Repository

Product domain knowledge for Homebase, optimized for AI consumption. This is a companion to `homebase-context` (analytics context) — it covers **what products do and why**, not how to query the data.

## How It's Organized

| Folder | What's in it |
|---|---|
| `01-company/` | Cross-cutting business context — overview, product suite, glossary, OKRs, metrics, and customer segments |
| `02-domains/` | Domain-specific product context, one subfolder per product area (each with `workflows/` and `data-model.md`) |

## Three-Layer Metrics Architecture

Metric knowledge lives across three layers:

| Layer | Location | Contains | Owner |
|---|---|---|---|
| Product definitions | `01-company/metrics.md` | What each metric IS and why it matters | Product leadership |
| Domain-specific | `02-domains/*/okrs-and-metrics.md` | How a domain relates to company metrics | Domain PM |
| Query layer | `homebase-context/03-data/` | SQL, tables, columns, computation logic | Analytics team |

## How to Contribute

1. **New domain?** Start with `seed-product-context/` — it contains the skill definition and a 24-question interview protocol. Use `02-domains/hrm/` as a reference template (not a rigid schema), create your domain folder with `workflows/` subfolder
2. **Updating content?** Edit in place, update `last_updated` in front matter
3. **Interview-based?** Use the `/seed-product-context` skill to process a Granola transcript
4. **Validation:** Run `bash validate.sh` before committing

## Front Matter Convention

Every file requires YAML front matter:

```yaml
---
owner: github-handle
last_updated: 2026-03-30
review_cadence: quarterly
next_review: 2026-07-01
source: vault | interview | jira | stub | manual
refs:
  - path/to/related-file.md
---
```

## Rules

- No SQL, table names, or column names — those belong in `homebase-context/03-data/`
- Every file starts with a one-line "Load when..." header after the title
- Keep domain definition files under 5,000 characters
- Reference `homebase-context` via `refs` front matter — never duplicate content
- See `homebase-context/context-file-style-guide.md` for authoring standards

## RFC

This repository was proposed in the Product Context Repository RFC. Sammy is seeding HRM as the first domain; other domain owners will replicate the process.
