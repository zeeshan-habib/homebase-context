# homebase-context

## What is this?

A collection of curated markdown files that give AI tools the business context they need to work effectively at Homebase. These files contain proprietary definitions, domain knowledge, and reusable skills that models can't infer from training data alone.

The repo covers **analytics, product context, and AI-powered workflows** - metric definitions, data environment guidance, SQL patterns, business logic, and shared skills for common tasks like dashboard creation and eventing specs.

## What's in it

- **Reusable skills** - shared Claude Code workflows for analytics, dashboard creation, eventing specs, and more
- **Gold standard metric definitions** - exact logic, not just concepts
- **Business context for ambiguous terms** - disambiguation rules for terms like "active," "user"
- **Domain-specific knowledge** - product area context for timetracking, scheduling, and more
- **SQL reference queries** - curated, tested queries organized by category

## Who is this for?

Any Homebase team member using AI tools (Claude, Copilot, Cursor, etc.) for self-serve analytics, product questions, or data exploration. The repo started with the Core Product Team and is expanding to other teams.

## Repo Structure

- `CLAUDE.md` - Top-level AI-facing instructions and folder directory (each subfolder also has its own `CLAUDE.md` with file-level guidance)
- `01-skills/` - Shared Claude Code skills (analyst, dashboard creation, eventing specs)
- `02-business/` - Business overview, entity relationships, product timeline
- `03-data/` - Metric definitions, glossary, date conventions, product-domain schemas
- `04-queries/` - Curated SQL queries organized by category
- `context-file-style-guide.md` - Authoring guidelines for new context files

## Contributing

### Adding a skill to 01-skills

See [`01-skills/README.md`](01-skills/README.md) for full instructions. Each skill lives in its own subfolder and is owned by the person who created it. Add a CODEOWNERS entry for your subfolder so you can approve changes to it.

### Adding or editing a context file

Each folder has a `CLAUDE.md` that serves as the file index for AI tools - this is how models know which files to load for a given question.

1. Create a branch from `main`
2. Read [`context-file-style-guide.md`](context-file-style-guide.md) before writing - it covers what belongs, formatting rules, and anti-patterns
3. Every file must start with a one-line header describing its scope and when to load it
4. Add a row to the `CLAUDE.md` in the relevant subfolder with a "when to load" description
5. Open a PR for review

### Adding a query to 04-queries

Say **"save this query"** in your Claude conversation. Claude will create a branch, write the file, and open a draft PR automatically.

For project background and roadmap, see the [Structure & Plan](https://docs.google.com/document/d/1UM4C-UrP9I7CqhjR829C-B3Se_l_V-TJfcegKkcb2K0/edit) doc.
