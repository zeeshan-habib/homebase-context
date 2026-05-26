# Homebase Context Repo — Structure Reference

Reference for working inside `pioneerworks/homebase-context`. Load this at the start of any session involving that repo.

---

## Repo Purpose

Curated AI context for Homebase — plain English definitions, domain knowledge, data schemas, and metric definitions. Skills and interaction logic live in a separate repo. This repo is pure context.

## Three-Layer Architecture

| Layer | Folder | What lives here | What does NOT live here |
|---|---|---|---|
| Business context | `global/` | What Homebase is, product suite, OKRs, customer segments, product terms | SQL, table names, metric calculations |
| Product knowledge | `domains/[product]/` | How the product works, workflows, data model, OKRs | Metric definitions (always point to `data/glossary.md`) |
| Data knowledge | `data/` | Canonical metric definitions, table schemas, SQL examples, data gotchas | Product descriptions (always point to `domains/`) |

**Critical rule:** `data/glossary.md` is the ONE source of truth for all metric definitions. Domain files reference metrics but never define them.

---

## Folder Map

```
homebase-context/
├── CLAUDE.md                          ← AI navigation rules + folder directory
├── context-file-style-guide.md        ← Authoring rules
├── global/
│   ├── CLAUDE.md
│   ├── business-overview.md           ← Entity model, funnel, revenue lines
│   ├── product-suite.md               ← All products, tier gating
│   ├── glossary.md                    ← Product terms (OAM, NHP, AiO, etc.)
│   ├── metrics.md                     ← Metric descriptions (no SQL)
│   ├── okrs.md                        ← Company + domain OKRs
│   ├── feature-experiment-registry.md
│   └── customers/
├── domains/
│   ├── CLAUDE.md                      ← Domain directory
│   ├── hrm/                           ← Fully built reference domain
│   ├── time-tracking/
│   ├── payroll/
│   ├── hiring-assistant/
│   ├── clover-embedded/
│   ├── cash-out/
│   └── mshr/                          ← Main Street Health Report (new)
└── data/
    ├── CLAUDE.md
    ├── glossary.md                    ← Canonical metric definitions (ALL metrics)
    ├── schema-reference.md            ← Core tables, join patterns, identifiers
    ├── engagement/
    │   └── engagement-metrics.md
    └── product-areas/
        ├── hrm/hrm.md
        ├── payroll/
        ├── time-tracking/
        ├── scheduling.md
        ├── hiring-assistant/
        ├── clover-embedded/
        ├── cash-out/
        └── mshr/mshr.md               ← MSHR data context (new)
```

---

## Domain Folder Template (every domain uses this structure)

```
domains/[product]/
├── CLAUDE.md                 ← Index: file table + DRI + Slack channel
├── domain-overview.md        ← What the domain is, lifecycle/stages, key workflows table, domain boundaries
├── customers.md              ← OAM + EE archetypes specific to this domain
├── data-model.md             ← Key entities, relationships, common confusion points
├── okrs-and-metrics.md       ← Domain OKRs + how they map to company metrics
└── workflows/
    ├── CLAUDE.md
    └── [workflow].md         ← Steps, failure modes, impact per major workflow
```

---

## File Anatomy

Every non-CLAUDE.md file starts with YAML front matter:
```yaml
---
owner: [name]
last_updated: YYYY-MM-DD
review_cadence: quarterly
next_review: YYYY-MM-DD
source: manual | stub | vault
refs:
  - path/to/related-file.md
---
```
First line after front matter: one-line scope + when to load.

---

## CLAUDE.md Convention (every folder)

```markdown
# Folder Name
One-line description.

| File | When to load |
|---|---|
| `file.md` | Trigger: what question makes you load this file |
```

File not listed in a CLAUDE.md = invisible to AI.

---

## Style Rules (from context-file-style-guide.md)

- Only proprietary info — never write what the model can infer from training data
- Tables > prose. IF/THEN > narrative.
- Imperative verbs: "Ask which definition" not "It's helpful to clarify"
- One idea per bullet. No nested bullets.
- Stub placeholders: `<!-- STUB: description of what goes here -->`
- File size targets: behavioral 1K–2K chars | domain/metrics 2K–5K chars | schema as needed
- IF file exceeds target → audit: "Would the model get this wrong without this line?"

---

## Active Domains

| Domain | Folder | Build status |
|---|---|---|
| HRM (Team Management) | `domains/hrm/` | ~70% complete (customers + okrs are stubs) |
| Time Tracking | `domains/time-tracking/` | Unknown |
| Payroll | `domains/payroll/` | Unknown |
| Hiring Assistant | `domains/hiring-assistant/` | Unknown |
| Clover Embedded | `domains/clover-embedded/` | Unknown |
| Cash Out | `domains/cash-out/` | Unknown |
| Main Street Health Report | `domains/mshr/` | Scaffolded — needs content |

---

## Key Business Facts (quick reference)

- **Entity model:** Company → Location → User/Job. Most metrics are location-level.
- **Tiers:** 1=Basic (free), 2=Essentials ($30), 3=Plus ($70), 4=All-in-One ($120)
- **OAM** = Owner, Admin, or Manager. **EE** = Employee.
- **Engaged** = TT or scheduling engaged (7d) AND OAM activity (30d). Source: `bizops.product_location_engagement_metrics.engagement_boolean`
- **NHP** = New Hire Packet — digital onboarding docs (W-4, I-9, direct deposit)
- **Payroll** is separate product, billed per company + per employee
- **Clover Embedded** = Homebase timesheets inside Clover POS; Front Book = new merchants, Back Book = existing

---

## Repo Ownership

| Folder | DRI | Reviews/merges |
|---|---|---|
| `global/` | Analytics | Analytics |
| `data/` | Analytics | Analytics |
| `domains/[area]/` | Domain Owner | Domain Owner + Analytics |

*Repo: `pioneerworks/homebase-context`*
*Style guide: `context-file-style-guide.md` in root*
