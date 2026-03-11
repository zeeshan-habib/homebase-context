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
- `04-queries/` — Curated SQL queries organized by category. Always scan when answering a SQL question.

## Using the Query Library

For any SQL question:
1. Read `04-queries/INDEX.md` — match the question against the description and tags columns
2. IF any row is relevant (same tables, filters, joins, or business concept) → load that `.sql` file and use it as reference context when writing the new query. Use it to inform table choices, filter logic, join patterns, or metric definitions — not to copy it verbatim.
3. IF no match → write the query from scratch using the context files

## Saving Queries to the Library

After providing a SQL query, always end your response with:
> "Want me to save this query to the library?"

IF user says yes, "save this query", or "add this to the query library":
1. Extract the final SQL from the conversation
2. Derive: title, description, category, tags, notes/caveats — summarize from conversation context; ask for author name if not known
3. Create a branch: `query/<title-slug>`
4. Write file to `04-queries/<title-slug>.sql` using the frontmatter format in `04-queries/README.md`
5. Add a new row to `04-queries/INDEX.md` with the file name, title, description, and tags
6. Open a draft PR on `pioneerworks/homebase-context` with:
   - Title: `[Query] <title>`
   - Body: what the user was trying to answer, why this query was needed, key assumptions or caveats from the conversation
7. Reply with the PR URL so the user can find it

## Rules

- If a question involves a metric, table, or term not covered in these files, say so — do not guess.
- See context-file-style-guide.md for authoring guidelines when adding new files.
