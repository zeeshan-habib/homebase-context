# Company Context

Cross-cutting business context for Homebase — the company, its products, and customers.

## File Index

| File | When to load |
|---|---|
| `business-overview.md` | Questions about what Homebase is, entity model, pricing, growth funnel, revenue lines |
| `product-suite.md` | Questions about product areas, how they connect, tier gating |
| `glossary.md` | Unfamiliar product term — check here first, then `data/glossary.md` for metric definitions |
| `feature-experiment-registry.md` | Feature flags, experiments, and rollout status |
| `okrs.md` | Company or domain OKRs, strategic priorities |
| `metrics.md` | Product-level metric descriptions (not SQL, not data sources — for that, use `data/glossary.md`) |

| Subfolder | When to load |
|---|---|
| `customers/` | Customer types, business verticals, SMB archetypes, tier distribution |

## Navigation Rules

- Start with `glossary.md` if the question involves a product term you don't recognize.
- Start with `business-overview.md` if you need to understand how Homebase works before answering.
- Never load all files — pick the one that matches the question.

## Behavioral Rules

- This folder contains business context only. Do not look here for metric calculations, SQL, table schemas, or data sources — that lives in `data/`.
- If a file here mentions a metric by name, the authoritative definition is in `data/glossary.md`, not here.
