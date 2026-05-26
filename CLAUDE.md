# homebase/
Curated AI context for Zee's Homebase consulting engagement. Three-layer architecture: global business context → domain knowledge → data definitions.

| File/Folder | When to load |
|---|---|
| `homebase-context-structure.md` | Load when: onboarding to the homebase context repo, understanding folder conventions, or setting up a new domain |
| `global/` | Load when: asked about Homebase the company, product suite, entity model, or OKRs |
| `domains/mshr/` | Load when: working on Main Street Health Report — metrics, data model, customers, workflows |
| `data/` | Load when: looking up metric definitions, table schemas, or SQL patterns |

## Three-Layer Architecture

| Layer | Folder | Purpose |
|---|---|---|
| Business context | `global/` | What Homebase is, product suite, customer segments, entity model |
| Product knowledge | `domains/[product]/` | How each product works, workflows, data model, OKRs |
| Data knowledge | `data/` | Canonical metric definitions, table schemas, SQL examples |

**Critical rule:** `data/` is the ONE source of truth for all metric definitions. Domain files reference metrics but never define them.

## Consulting Context

- **Client:** Homebase (former employer)
- **Rate:** $100/hr, T4A personal income (route through CAEDUNIT once T2s filed)
- **Scope:** Build MSHR context repo for Claude Code — CMO Katie + CRO Ray engagement
- **Target repo:** `pioneerworks/homebase-context` (staging here, transfer when done)
- **PR #69** open in `zeeshan-habib/claude` with current homebase/ context work
