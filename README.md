# homebase-context

## What is this?

A collection of curated markdown files that give AI tools the business context they need to work effectively at Homebase. These files contain proprietary definitions, domain knowledge, and behavioral instructions that models can't infer from training data alone.

The primary focus is **analytics and product context** - metric definitions, data environment guidance, SQL patterns, and business logic. The repo is designed to be extensible to other functions (engineering, support, ops) as teams adopt it.

## What's in it

- **Gold standard metric definitions** - exact logic, not just concepts
- **Business context for ambiguous terms** - disambiguation rules for terms like "active," "user"
- **Domain-specific knowledge** - product area context for timetracking, scheduling, and more
- **SQL reference queries** - curated, tested queries organized by category
- **Behavioral instructions** - rules for how AI tools should approach Homebase analytics

## Who is this for?

Any Homebase team member using AI tools (Claude, Copilot, Cursor, etc.) for self-serve analytics, product questions, or data exploration. The repo started with the Core Product Team and is expanding to other teams.

## Repo Structure

- `01-instructions/` - Behavioral rules and environment setup
- `02-business/` - Business overview, entity relationships, product timeline
- `03-data/` - Metric definitions, glossary, date conventions, engagement metrics
- `03-data/product-domains/` - Product-area schemas and logic (timetracking, scheduling, etc.)
- `04-queries/` - Curated SQL queries organized by category
- `context-file-style-guide.md` - Authoring guidelines for new context files
- `CLAUDE.md` - Top-level AI-facing instructions and folder directory (each subfolder also has its own `CLAUDE.md` with file-level guidance)

## Contributing

### Adding or editing a context file

Each folder has a `CLAUDE.md` that serves as the file index for AI tools - this is how models know which files to load for a given question.

1. Create a branch from `main`
2. Read [`context-file-style-guide.md`](context-file-style-guide.md) before writing - it covers what belongs, formatting rules, and anti-patterns
3. Every file must start with a one-line header describing its scope and when to load it
4. Add a row to the `CLAUDE.md` in the relevant subfolder with a "when to load" description
5. Open a PR for review

### Adding a query to `04-queries/`

Say **"save this query"** in your Claude conversation. Claude will create a branch, write the file, and open a draft PR automatically.

For project background and roadmap, see the [Structure & Plan](https://docs.google.com/document/d/1UM4C-UrP9I7CqhjR829C-B3Se_l_V-TJfcegKkcb2K0/edit) doc.
