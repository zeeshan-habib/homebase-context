# homebase/
Curated AI context for Zee's Homebase consulting engagement. Three-layer architecture: global business context → domain knowledge → data definitions.

| File/Folder | When to load |
|---|---|
| `homebase-context-structure.md` | Load when: onboarding to the homebase context repo, understanding folder conventions, or setting up a new domain |
| `global/` | Load when: asked about Homebase the company, product suite, entity model, or OKRs |
| `domains/mshr/` | Load when: working on Main Street Health Report — metrics, data model, customers, workflows |
| `data/` | Load when: looking up metric definitions, table schemas, or SQL patterns |
| `apps/mshr-dash/` | Load when: working on the MSHR Databricks App — architecture, deploy commands, design system |

## Three-Layer Architecture

| Layer | Folder | Purpose |
|---|---|---|
| Business context | `global/` | What Homebase is, product suite, customer segments, entity model |
| Product knowledge | `domains/[product]/` | How each product works, workflows, data model, OKRs |
| Data knowledge | `data/` | Canonical metric definitions, table schemas, SQL examples |
| Apps | `apps/[app]/` | Databricks App source + deploy instructions |

**Critical rule:** `data/` is the ONE source of truth for all metric definitions. Domain files reference metrics but never define them.

## Consulting Context

- **Client:** Homebase (former employer)
- **Rate:** $100/hr, T4A personal income (route through CAEDUNIT once T2s filed)
- **Scope:** Build MSHR context repo for Claude Code — CMO Katie + CRO Ray engagement
- **Target repo:** `pioneerworks/homebase-context` (staging here, transfer when done)
- **PR #69** open in `zeeshan-habib/claude` with current homebase/ context work

---

## Apps: mshr-dash (Databricks App)

**How to start a session for mshr-dash:**

1. Clone this repo (if not already cloned):
   ```bash
   git clone https://github.com/zeeshan-habib/homebase-context.git
   cd homebase-context/apps/mshr-dash
   ```
2. Open Claude Code from that folder:
   ```bash
   claude
   ```
   Claude will auto-load `apps/mshr-dash/CLAUDE.md` with full architecture, deploy commands, and design system context.

**Or on your personal machine, if already cloned locally:**
```bash
cd /path/to/homebase-context/apps/mshr-dash && claude
```

| Detail | Value |
|--------|-------|
| Live URL | https://mshr-dash-373323366197249.aws.databricksapps.com |
| Databricks workspace | homebase-staging.cloud.databricks.com |
| Deploy email | zhabib@joinhomebase.com |
| Workspace path | /Workspace/Users/zhabib@joinhomebase.com/mshr-dash |
| App name | mshr-dash |
| Default warehouse | 16984dfe9a2c3705 |
