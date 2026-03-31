---
name: seed-product-context
description: >
  Seed product context files for a domain via structured interview or Granola transcript.
  Use when a domain owner wants to populate their product-context folder with real content.
  Supports two modes: interactive (guided Q&A) and transcript (process a recording).
---

# Seed Product Context

Populates product-context files for a Homebase domain. Two modes:

- **Interactive:** `seed-product-context interactive [domain]` — walks through interview questions via AskUserQuestion
- **Transcript:** `seed-product-context transcript [domain]` — processes a Granola transcript into context files

## Setup (Both Modes)

1. **Load the style guide:**
   Read `homebase-context/context-file-style-guide.md` for authoring standards.

2. **Load existing stubs:**
   Read `homebase-context/05-sammy-test-product-context/02-domains/[domain]/CLAUDE.md` to find all files.
   Read each file to understand what sections need content.

3. **Bootstrap from EPDD page:**
   Use the Atlassian MCP to fetch the EPDD Teams Confluence page (page ID: `2494791869`, site: `joinhomebase.atlassian.net`):
   ```
   mcp__atlassian__getConfluencePage(cloudId: "joinhomebase.atlassian.net", pageId: "2494791869", contentFormat: "markdown")
   ```
   Extract for the target domain:
   - "Responsible for" list → use as interview opening prompt
   - Team members → populate front matter
   - Slack channel → populate CLAUDE.md

4. **Load interview protocol:**
   Read the co-located `interview-protocol.md` (same folder as this skill) for the full question set.

5. **Understand the expected domain folder structure:**
   ```
   02-domains/[domain]/
   ├── CLAUDE.md               # Index of all files in this domain
   ├── domain-overview.md      # What the domain is, boundaries, key workflows
   ├── customers.md            # Domain-specific OAM + EE archetypes
   ├── data-model.md           # Key entities, relationships, confusion points
   ├── okrs-and-metrics.md     # Current OKRs + metrics
   └── workflows/              # One file per key workflow
       ├── CLAUDE.md           # Index of workflow files
       └── [workflow-name].md  # Individual workflow documentation
   ```

   **HRM is the reference domain, not a rigid schema.** Each domain owner decides:
   - Which workflow files to create (guided by interview, not a fixed list)
   - Whether `data-model.md` has 3 entities or 10
   - Whether `customers.md` splits OAM/EE or uses domain-specific personas
   - File naming within `workflows/`

---

## Core Rules (Non-Negotiable)

These apply to every domain, regardless of structure decisions:

1. **Front matter convention** — every `.md` file (except CLAUDE.md, README.md) must have:
   ```yaml
   ---
   owner: github-handle
   last_updated: YYYY-MM-DD
   review_cadence: quarterly
   next_review: YYYY-MM-DD
   source: vault | interview | jira | stub | manual
   refs:
     - path/to/related-file.md
   ---
   ```

2. **"Load when..." header** — every file starts with a `# Title` followed by a one-line "Load when..." sentence

3. **No SQL, table names, or column names** — product definitions only; those belong in `homebase-context/03-data/`

4. **Every file listed in its folder's CLAUDE.md** — no orphan files

5. **File size target** — keep content files under 5,000 characters

6. **Use `refs` for cross-references** — never duplicate content from other files

7. **Review before writing** — never write a file without the PM reviewing the key content first. Use AskUserQuestion to present summaries after each section (interactive) or a full outline (transcript). One round of "Looks good" vs. "Needs changes" minimum per file.

---

## Interactive Mode

Walk through the interview protocol using AskUserQuestion. Group questions by section. **Draft and review each file with the PM before writing it.**

### Section Review Gate

After finishing each section's questions, follow this pattern before moving to the next section:

1. **Draft in memory** — compose the output file content from the PM's answers
2. **Present a summary via AskUserQuestion** — show the key bullets, entities, or workflow names that will go in the file (not raw markdown). Ask:
   - "Looks good" — proceed to write the file
   - "Needs changes" — PM provides corrections via free text
   - "Skip this file for now" — leave it stubbed, move on
3. **If "Needs changes"** — revise the draft based on feedback, re-present the summary. Repeat until the PM approves.
4. **Write the file** only after approval. Apply proper front matter (`source: interview`, `last_updated: today`, etc.)

### Flow:

**Section 1 — Domain Identity (Questions 1-4):**
Present the EPDD "Responsible for" list and ask: "Your domain owns [X, Y, Z]. Let's walk through each."
Then ask questions 1-4 from the protocol, one at a time or grouped logically.
→ **Review gate** → Output: `domain-overview.md`

**Section 2 — Customer Archetypes (Questions 5-9):**
Ask questions 5-9.
→ **Review gate** → Output: `customers.md`

**Section 3 — Domain Workflows (Questions 10-16):**
Ask questions 10-16. Map answers to workflow files.
→ **Review gate** — present the list of workflow files to be created and key content for each. PM approves file names and content.
→ Output: `workflows/` subfolder — create one file per key workflow identified.
  File names come from the interview (e.g., `workflows/applicant-pipeline.md` for Hiring, `workflows/onboarding.md` for HRM).
  Create `workflows/CLAUDE.md` to index the workflow files.

**Section 3b — Data Model (Questions 17-19):**
Ask questions 17-19. Capture entities, relationships, and confusion points.
→ **Review gate** — present the entity list, relationship map, and confusion points table.
→ Output: `data-model.md`
  Include: entity descriptions, relationship map, common confusion points table.
  See `02-domains/hrm/data-model.md` for the reference format.

**Section 4 — OKRs and Metrics (Questions 20-23):**
Ask questions 20-23.
→ **Review gate** → Output: `okrs-and-metrics.md`

**Section 5 — Knowledge Gaps (Question 24):**
Ask question 24.
→ **Review gate** — show where each insight will be placed across files.
→ Distribute insights across relevant files.

### After All Sections:

1. Update the domain's `CLAUDE.md` to list all generated files and the `workflows/` subfolder.

2. Print a summary showing:
   - Files generated (with approval status)
   - Sections skipped or still stubbed
   - Suggested follow-ups for gaps

---

## Transcript Mode

Process a Granola meeting transcript into context files. **Present a full outline for PM review before writing any files.**

### Flow:

1. **Get the transcript:**
   Use `mcp__granola__query_granola_meetings` to find the interview recording, or ask the user to paste the transcript.

2. **Map content to sections:**
   For each output file, scan the transcript for relevant content using the section→output mapping from the interview protocol. Assess confidence per section:
   - **HIGH:** Direct, detailed answers from the interviewee covering the full stub prompt
   - **MEDIUM:** Partial coverage or inferred from adjacent discussion
   - **LOW:** Mentioned briefly or not covered — keep the stub comment with a note

3. **Review pass — present outline via AskUserQuestion (before writing anything):**
   Show a file-by-file outline:
   - File name and target path
   - Key bullets that will go in each file
   - Confidence level (HIGH/MEDIUM/LOW) with reasoning
   - Any inferences made from context (flagged explicitly)

   For each file, ask: "Looks good", "Needs changes", or "Skip for now".
   For any LOW-confidence sections, explicitly ask: "The transcript didn't clearly cover [X]. Should I stub it, infer from [related discussion Y], or skip?"

   Repeat the review for any files the PM flags until approved.

4. **Generate approved files with confidence indicators:**
   Add confidence as a comment at the top of each section:
   ```markdown
   ## Section Title
   <!-- Confidence: HIGH | Source: transcript 12:30-15:45 -->
   ```

5. **Create workflow files based on what was discussed:**
   Don't force HRM's workflow file names onto other domains. Name `workflows/*.md` files based on what the interviewee actually described as their key workflows.

6. **Create data-model.md from entity discussion:**
   Map questions 17-19 from the transcript. If the interviewee didn't explicitly discuss entities, infer from workflow descriptions and flag as MEDIUM confidence.

7. **Front matter:**
   - `source`: interview
   - All other fields same as interactive mode

8. **Print summary:**
   - Coverage assessment per file (% of stubs filled, approval status)
   - LOW confidence sections that need follow-up
   - Topics mentioned in transcript but not mapped to any file (potential new sections)

---

## File Writing Rules

- Follow `homebase-context/context-file-style-guide.md` strictly
- No SQL, table names, or column names — product definitions only
- Use tables over prose for structured information
- Use imperative verbs, not descriptions
- Keep files under 5,000 characters
- Every claim should be verifiable — flag anything that seems like opinion vs. fact
- Reference `homebase-context/03-data/` for the query layer, never duplicate it

## Validation

After generating files, run:
```bash
bash homebase-context/05-sammy-test-product-context/validate.sh
```
Report any violations and fix them before finishing.

## Git Workflow

All domain files live in the `homebase-context` repo under `05-sammy-test-product-context/`.

### Where files go:

```
homebase-context/
└── 05-sammy-test-product-context/
    ├── 01-company/          # Shared company context (already seeded)
    ├── 02-domains/
    │   ├── CLAUDE.md        # Index of all domains — update when adding a new domain
    │   ├── hrm/             # Reference domain (already seeded)
    │   └── [new-domain]/    # New domain folder you're creating
    ├── CLAUDE.md            # Root index
    └── validate.sh          # Linting script
```

### How to push:

1. **Create a branch** from `main`:
   ```bash
   cd homebase-context
   git checkout -b [your-name]/seed-[domain]-context main
   ```

2. **Generate files** using this skill (interactive or transcript mode)

3. **Run validation:**
   ```bash
   bash 05-sammy-test-product-context/validate.sh
   ```

4. **Commit and push:**
   ```bash
   git add 05-sammy-test-product-context/
   git commit -m "Seed product-context for [domain] domain"
   git push -u origin [your-name]/seed-[domain]-context
   ```

5. **Open a PR** targeting `main` with the domain owner as reviewer
