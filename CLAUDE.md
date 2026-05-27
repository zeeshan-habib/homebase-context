# homebase-context — AI Navigation Guide

Curated context for Zee's Homebase consulting engagement. Three-layer architecture: global business context → domain knowledge → data definitions.

---

## Direct Question Routing

**Start here.** Match your question to a row and go directly to that file — do not navigate subfolders first.

| If you're asked... | Go directly to |
|---|---|
| What is MSHR? What does it measure? What's in the report? | `domains/mshr/domain-overview.md` |
| Who reads MSHR? Who is the audience? What do they use it for? | `domains/mshr/customers.md` |
| What are the six MSHR metrics? How are they defined? | `domains/mshr/okrs-and-metrics.md` |
| How do I produce the monthly MSHR report? | `data/product-areas/mshr/workflows/monthly-report.md` |
| How do I run a scoped, ad hoc, or event-driven MSHR report? | `data/product-areas/mshr/workflows/adhoc-report.md` |
| How do I analyze an event's impact on small businesses? | `data/product-areas/mshr/workflows/adhoc-report.md` → Event Impact Analysis |
| SQL for wages, hiring, or turnover | `data/product-areas/mshr/mshr.md` |
| Which table do I use? What columns are available? What does each field mean? | `data/product-areas/mshr/data-model.md` |
| Qualification flags, normalization rules, known SQL pitfalls, code generation rules | `data/product-areas/mshr/workflows/CLAUDE.md` |
| Data freshness, refreshing source tables, recreating the January benchmark table | `data/product-areas/mshr/workflows/data-sourcing.md` |
| Building, deploying, debugging, or extending the MSHR dashboard app | `apps/mshr-dash/CLAUDE.md` |
| What is Homebase? Product suite, business model, customer segments | `global/business-overview.md` |

---

## Folder Map

Use this if your question doesn't match the routing table above.

| Folder / File | What it contains |
|---|---|
| `global/` | Homebase the company — product suite, entity model, customer segments, company-wide OKRs |
| `domains/mshr/` | MSHR domain knowledge — what it is, who uses it, what the metrics mean at a business level |
| `data/product-areas/mshr/` | All technical content — SQL, table schemas, qualification rules, suppression rules, index methodology |
| `data/product-areas/mshr/workflows/` | Production workflows — monthly report, ad hoc, data sourcing, event impact template, code generation rules |
| `apps/mshr-dash/` | Databricks App source — architecture, deploy commands, design tokens, troubleshooting |
| `data/glossary.md` | Cross-domain term definitions |

**Critical rule:** `data/` is the single source of truth for all metric definitions. Domain files in `domains/` describe what metrics mean to the business — they do not define how they are computed.

---

## Consulting Context

- **Client:** Homebase (former employer)
- **Rate:** $100/hr, T4A personal income (route through CAEDUNIT once T2s filed)
- **Scope:** Build MSHR context repo for Claude Code — CMO Katie + CRO Ray engagement
- **Target repo:** `pioneerworks/homebase-context` (staging here, transfer when done)

---

## Apps

### mshr-dash

Live MSHR dashboard on Databricks Apps.

| Detail | Value |
|---|---|
| Live URL | https://mshr-dash-373323366197249.aws.databricksapps.com |
| Databricks workspace | homebase-staging.cloud.databricks.com |
| Deploy email | zhabib@joinhomebase.com |
| App name | mshr-dash |
| Default warehouse | 16984dfe9a2c3705 |

Start a session: `cd apps/mshr-dash && claude`
