# Product Context

Load files selectively based on the task. Read the subfolder's CLAUDE.md before loading individual files.

## Folder Directory

| Folder | What's in it | When to load |
|---|---|---|
| `01-company/` | Business overview, product suite, glossary, OKRs, company metrics, and customer segments | Any question about Homebase as a business, pricing, products, company-wide metrics, or customer types |
| `02-domains/` | Domain-specific product context (one subfolder per product area) | Questions about a specific product domain's workflows, customers, or metrics |
| `seed-product-context/` | Skill definition + interview protocol for seeding a new domain | When a PM wants to populate their domain's product-context folder |

## Metric Routing

| Question type | Load |
|---|---|
| "What does this metric mean?" | `01-company/metrics.md` |
| "What does this metric mean for [domain]?" | `02-domains/[domain]/okrs-and-metrics.md` |
| "How do I query this metric?" | `homebase-context/03-data/` (not this repo) |

## Rules

- No SQL, table names, or column names in any file — those belong in `homebase-context/03-data/`
- Files with `source: stub` in front matter are incomplete — flag this to the user
- See `homebase-context/context-file-style-guide.md` for authoring standards
