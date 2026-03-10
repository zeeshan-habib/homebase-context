# Homebase Context Repository

This repo contains business context files for Homebase analytics, not code.
Load files selectively based on the task — do not load everything at once.

## File Index

See README.md for the full file index and "when to load" guidance.

## Folder Structure

- `01-instructions/` — Behavioral rules and environment setup. Load for any analytics request.
- `02-business/` — Business overview and product timeline. Load when domain context is needed.
- `03-data/` — Metric definitions, schema references, and SQL patterns. Load based on the specific data domain.
- `03-data/product-domains/` — Product-area-specific schemas and logic (timetracking, payroll, etc.).
- `04-queries/` — Curated SQL queries organized by category. Load relevant files when building a similar query.

## Saving Queries to the Library

IF user says "save this query" or "add this to the query library":
1. Extract the final SQL from the conversation
2. Derive: title, description, category, tags, notes/caveats — summarize from conversation context; ask for author name if not known
3. Create a branch: `query/<title-slug>`
4. Write file to `04-queries/<title-slug>.sql` using the frontmatter format in `04-queries/README.md`
5. Open a draft PR on `pioneerworks/homebase-context` with:
   - Title: `[Query] <title>`
   - Body: what the user was trying to answer, why this query was needed, key assumptions or caveats from the conversation
6. Reply with the PR link

## Rules

- If a question involves a metric, table, or term not covered in these files, say so — do not guess.
- See context-file-style-guide.md for authoring guidelines when adding new files.
