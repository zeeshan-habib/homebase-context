# Homebase Context Repository

Curated business and analytics context for Homebase. Plain English definitions, domain knowledge, data pointers, and gotchas that models can't infer from training data.

Skills and interaction logic live in a separate repo. This repo is pure context.

## Folder Directory

| Folder | What's in it | When to load |
|---|---|---|
| `global/` | What Homebase is, how the business works, product suite, OKRs, customer segments, product glossary | When you need organizational or product context beyond specific metrics |
| `domains/` | Domain-specific product context — workflows, customer archetypes, domain OKRs | When the question is about a specific product domain (e.g., HRM, Time Tracking) |
| `data/` | Metric definitions, schema reference, product-area data guides | When the question involves a specific metric, table, or product area |

## Navigation Rules

- Never load all files at once. Always read a folder's CLAUDE.md first — it tells you which file to load next.
- Start with the most specific folder that matches the question. If the question is about a product domain, go to `domains/` first. If it's about a metric, go to `data/` first.
- If you don't find what you need in the first folder, check the others — but never guess. If the information isn't in any file, say so.

## Behavioral Rules

- Never invent metric definitions, table names, column names, or field values. If it's not in a context file, it doesn't exist as far as this repo is concerned.
- Never define metrics outside of `data/glossary.md`. That is the single source of truth for all metric definitions.
- Domain folders reference metrics but never define them. If a domain file mentions a metric, the definition lives in `data/glossary.md`.
- If a term could mean multiple things at Homebase, surface the ambiguity — don't silently pick one interpretation.
- See `context-file-style-guide.md` for authoring guidelines when adding new files.
