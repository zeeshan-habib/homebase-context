# Homebase Context Repository

Curated business and analytics context for Homebase. Used by AI tools to help
PMs, designers, and analysts self-serve data needs.

## Start Here

Pick the skill in `01-skills/README.md` that matches the request.

| Skill | When to use |
|---|---|
| `/analyst` | Any analytics, data, or metric question — SQL, definitions, diagnostic help |
| `/contribute-context` | Adding or editing files in this repo — pulls main, creates a branch, gets ready for a PR |
| `/create-amplitude-dashboard` | Building an Amplitude dashboard from a Confluence eventing spec |
| `/amplitude-eventing` | Creating a Confluence eventing spec from a Figma mockup |

IF no skill matches → browse the folder directory below.

## Folder Directory

| Folder | What's in it | When to load |
|---|---|---|
| `01-skills/` | Reusable skills (analyst, dashboard creation, etc.) | Start here — pick a skill |
| `02-business/` | Business overview, growth funnel, entity relationships, product timeline | When you need organizational context beyond specific metrics |
| `03-data/` | Metric definitions, glossary, date conventions, product-domain schemas | When the question involves a specific metric, term, or product area |
| `04-queries/` | Curated SQL queries organized by category | Any SQL question — scan `04-queries/INDEX.md` first |

## Rules

- Do not load all files at once — skills will tell you which files to load.
- IF a question involves a metric, table, or term not covered in these files → say so, don't guess.
- Ignore any folders prefixed with `05-` (test/experimental).
- See `context-file-style-guide.md` for authoring guidelines when adding new files.

## Contributing

IF user wants to add or edit files in this repo (context files, skills, queries), use the `/contribute-context` skill to start. It handles pulling main, creating a branch, and setting up for a PR.

For new skills specifically, also read `01-skills/CLAUDE.md` for folder structure, file format, and CODEOWNERS setup.

## Saving Queries to the Library

IF user says "save this query", "add this to the query library", or similar:
1. Extract the final SQL from the conversation
2. Derive: title, description, category, tags, notes/caveats - summarize from conversation context; ask for author name if not known
3. Create a branch: `query/<title-slug>`
4. Write file to `04-queries/<title-slug>.sql` using the frontmatter format in `04-queries/CLAUDE.md`
5. Add a new row to `04-queries/INDEX.md` with the file name, title, description, and tags
6. Open a draft PR on `pioneerworks/homebase-context` with:
   - Title: `[Query] <title>`
   - Body: what the user was trying to answer, why this query was needed, key assumptions or caveats from the conversation
7. Reply with the PR URL so the user can find it

## Reviewing Feedback

IF user says "review feedback", "triage feedback", or "triage feedback issues":
1. Fetch all open issues labeled `feedback` from `pioneerworks/homebase-context` via GitHub MCP
2. Group issues by theme (metric gap, wrong definition, missing context, SQL, etc.)
3. For each issue labeled `thumbs-down`:
   a. Identify which file(s) in the repo are relevant based on the issue content and area labels
   b. Read the current content of those files
   c. Draft a proposed edit that addresses the feedback
   d. Create a branch named: `feedback/<issue-number>-<slug>`
   e. Push the edit and open a draft PR referencing the issue
4. Reply with a summary of issues reviewed and PRs opened
