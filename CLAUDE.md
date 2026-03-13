# Homebase Context Repository

This repo contains curated business context files for Homebase - primarily analytics and product domain knowledge, not code. Any Homebase team member using AI tools for self-serve analytics, product questions, or data exploration can benefit from these files.

Load files selectively based on the task - do not load everything at once. Always read the folder's CLAUDE.md before loading individual files.

## Folder Directory

| Folder | What's in it | When to load |
|---|---|---|
| `01-instructions/` | Behavioral rules, environment setup | Any analytics request or SQL query |
| `02-business/` | Business overview, entity relationships, product timeline | When you need organizational context beyond specific metrics |
| `03-data/` | Metric definitions, glossary, date conventions, product-domain schemas | When the question involves a specific metric, term, or product area |
| `04-queries/` | Curated SQL queries organized by category | Any SQL question - scan `04-queries/INDEX.md` first |

## Rules

- If a question involves a metric, table, or term not covered in these files, say so - do not guess.
- See context-file-style-guide.md for authoring guidelines when adding new files.
- Ignore any folders prefixed with `05-` - these are test/experimental and should not be loaded or referenced.

## Saving Queries to the Library

After providing a SQL query, always end your response with:
> "Want me to save this query to the library?"

IF user says yes, "save this query", or "add this to the query library":
1. Extract the final SQL from the conversation
2. Derive: title, description, category, tags, notes/caveats - summarize from conversation context; ask for author name if not known
3. Create a branch: `query/<title-slug>`
4. Write file to `04-queries/<title-slug>.sql` using the frontmatter format in `04-queries/README.md`
5. Add a new row to `04-queries/INDEX.md` with the file name, title, description, and tags
6. Open a draft PR on `pioneerworks/homebase-context` with:
   - Title: `[Query] <title>`
   - Body: what the user was trying to answer, why this query was needed, key assumptions or caveats from the conversation
7. Reply with the PR URL so the user can find it
