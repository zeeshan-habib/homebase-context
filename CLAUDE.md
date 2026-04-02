# Homebase Context Repository

Curated business and analytics context for Homebase. This repo is context that doesn't live anywhere else - plain English definitions, domain knowledge, data pointers, and gotchas that models can't infer from training data.

Skills and interaction logic live in a separate repo. This repo is pure context.

## Folder Directory

| Folder | What's in it | When to load |
|---|---|---|
| `global/` | What Homebase is, how the business works, product suite, OKRs, customer segments, product glossary | When you need organizational or product context beyond specific metrics |
| `domains/` | Domain-specific product context - workflows, customer archetypes, data models, domain OKRs | When the question is about a specific product domain (e.g., HRM, scheduling) |
| `data/` | Metric definitions, analytics glossary, date conventions, product-area data schemas | When the question involves a specific metric, term, table, or product area |

## Rules

- Never load all files at once. Read the folder's CLAUDE.md first to decide which files to load.
- If a question involves a metric, always check `data/glossary.md` first - it is the canonical source for all metric definitions.
- If a metric, table, or term is not covered in these files, say so. Do not guess.
- Domain folders reference metrics but never define them. Definitions live only in `data/glossary.md`.
- See `context-file-style-guide.md` for authoring guidelines when adding new files.

## Reviewing Feedback

IF user says "review feedback", "triage feedback", or "triage feedback issues":
1. Fetch all open issues labeled `feedback` from `pioneerworks/homebase-context` via GitHub MCP
2. Group issues by theme (metric gap, wrong definition, missing context, etc.)
3. For each issue labeled `thumbs-down`:
   a. Identify which file(s) in the repo are relevant based on the issue content and area labels
   b. Read the current content of those files
   c. Draft a proposed edit that addresses the feedback
   d. Create a branch named: `feedback/<issue-number>-<slug>`
   e. Push the edit and open a draft PR referencing the issue
4. Reply with a summary of issues reviewed and PRs opened
