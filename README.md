# homebase-context

## What is this?

A collection of curated markdown files that give AI tools the business context they need to work effectively at Homebase. These files contain proprietary definitions, domain knowledge, and gotchas that models can't infer from training data alone.

This repo is **pure context** - plain English definitions, domain knowledge, data pointers, and gotchas. Skills and interaction logic live in a separate repo and are exposed through plugins.

## What's in it

- **Business context** - org context (e.g. what Homebase is, product suite, OKRs, customer segments, product glossary)
- **Domain-specific knowledge** - domain area / functional area context (e.g. Scheduling, HRM, Growth, Marketing, and more)
- **Gold standard metric definitions** - exact logic, disambiguation rules
- **Data environment guidance** - date conventions, table references, product/functional area schemas

## Who is this for?

Any Homebase team member using AI tools (primarily built for Claude to start) for self-serve analytics, product questions, or data exploration. The repo started with the Core Product Team and is expanding to other teams.

## Repo Structure

- `CLAUDE.md` - Top-level AI-facing instructions and folder directory (each subfolder also has its own `CLAUDE.md` with file-level guidance)
- `global/` - Business overview, product suite, OKRs, customer segments, product glossary
- `domains/` - Domain-specific context (one subfolder per function/product area)
- `data/` - Metric definitions, analytics glossary, date conventions, product-area data schemas
- `context-file-style-guide.md` - Authoring guidelines for new context files

## Ownership

Analytics is the DRI for foundational truths about the business and its metrics. This covers both `global/` (cross-domain business context) and `data/` (metric definitions, data schemas). Anyone can open a PR to contribute - Analytics reviews and manages merges.

Domain teams own their `domains/` subfolders. They control their domain context (e.g. domain truths, workflows, customer archetypes, data models). Analytics can help, advise on best practices, and hold people accountable if context goes stale or drifts from the source of truth.

| Folder | DRI | Who can PR | Who reviews/merges |
|---|---|---|---|
| `global/` | Analytics | Anyone | Analytics |
| `data/` | Analytics | Anyone | Analytics |
| `domains/[area]/` | Domain Owner | Anyone | Domain Owner + Analytics |

## Contributing

Each folder has a `CLAUDE.md` that serves as the file index for AI tools - if you add a new file, update the relevant `CLAUDE.md` to include it. See [`context-file-style-guide.md`](context-file-style-guide.md) for authoring guidelines.

For project background and roadmap, see the [Structure & Plan](https://docs.google.com/document/d/1UM4C-UrP9I7CqhjR829C-B3Se_l_V-TJfcegKkcb2K0/edit) doc.
