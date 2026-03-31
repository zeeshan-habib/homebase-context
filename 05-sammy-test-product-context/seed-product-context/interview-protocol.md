---
owner: sammy
last_updated: 2026-03-30
review_cadence: yearly
next_review: 2027-03-30
source: manual
---
# Domain Context Interview Protocol

A structured 45-60 minute interview (24 questions across 5 sections) to populate product context files for a domain. Record on Granola, then process the transcript with `/seed-product-context transcript [domain]`.

## Before the Interview

1. **Pull EPDD context:** Fetch the domain's row from the [EPDD Teams page](https://joinhomebase.atlassian.net/wiki/spaces/HE/pages/2494791869). Extract:
   - "Responsible for" list (use as opening prompt)
   - Team members
   - Slack channel
2. **Load existing stubs:** Review the domain's stub files to know what's missing
3. **Share the framing:** Tell the interviewee: "Explain your domain like you're onboarding a new PM starting Monday"

## Interview Sections

### Section 1: Domain Identity (5-10 min)
**Output file:** `domain-overview.md`

**Opening prompt:** "Your domain owns [X, Y, Z from EPDD]. Let's walk through each of these."

1. In one paragraph, what does your domain do? What problem space do you own?
2. What are the 5-7 most important workflows in your domain? Who initiates each one?
3. Where does your domain hand off to other teams? What do you NOT own that people think you do?
4. If you had to draw a boundary around your domain, what's inside and what's outside?

### Section 2: Customer Archetypes (10-15 min)
**Output file:** `customers.md`

5. Who are the 2-3 types of OAMs (owners/managers) who use your features most? What are they trying to accomplish?
6. Who are the 2-3 types of employees who interact with your features? What's their experience like?
7. Where do OAM needs and employee needs conflict? Where do they align?
8. What's the biggest misconception users have about how your features work?
9. Which customer segment gets the most value from your domain? Which gets the least?

### Section 3: Domain Workflows (15-20 min)
**Output files:** `workflows/` subfolder — one file per workflow (e.g., `workflows/onboarding.md`, `workflows/documents.md`)

10. Walk me through the most common workflow in your domain, step by step. What triggers it? What does success look like?
11. Walk me through the second most common workflow. Same detail.
12. Where do things break? What are the top 3 failure points in your domain?
13. What's the impact when things fail? On the OAM? On the employee?
14. Are there workflows that work differently for different customer segments (by tier, vertical, size)?
15. What data does your domain own? What's the most important piece of information on a user profile from your perspective?
16. How does your domain connect to Payroll? To Scheduling? To other products?

### Section 3b: Data Model (3-5 min)
**Output file:** `data-model.md`

17. What are the key "things" or entities in your domain? (e.g., HRM has Team Members, Jobs, Documents — what are yours?)
18. Where do people get confused between similar concepts? What's the most common mix-up?
19. How do your entities relate to entities in other domains? (e.g., does your domain create or consume Users, Locations, Payments?)

### Section 4: OKRs and Metrics (5-10 min)
**Output file:** `okrs-and-metrics.md`

20. What's your team's primary objective this quarter? What are the key results?
21. What metrics does your team watch daily/weekly? Which ones actually change your decisions?
22. Are there metrics you wish you had but don't?
23. How does your domain contribute to company-level metrics (engagement, activation, retention)?

### Section 5: Knowledge Gaps (5 min)
**Output:** Distributed across all files as TODO markers

24. What's the thing about your domain that's hardest to explain to someone new? What do people consistently get wrong?

## After the Interview

1. **Process transcript:** Run `/seed-product-context transcript [domain]`
2. **Review generated files:** Each section will have confidence indicators (HIGH/MEDIUM/LOW)
3. **Fill gaps:** Mark any LOW-confidence sections for follow-up
4. **Run validation:** `bash validate.sh` should pass for all generated files
5. **PR and review:** Open a PR with the domain owner as reviewer

## Section → Output Mapping

| Section | Output file(s) |
|---|---|
| 1: Domain Identity | `domain-overview.md` |
| 2: Customer Archetypes | `customers.md` |
| 3: Domain Workflows | `workflows/*.md` (one file per workflow, named by the domain owner) |
| 3b: Data Model | `data-model.md` |
| 4: OKRs and Metrics | `okrs-and-metrics.md` |
| 5: Knowledge Gaps | Distributed as TODO markers across all files |

## Replication Guide

To seed a new domain:

1. Create a new folder: `02-domains/[domain-name]/` with a `workflows/` subfolder
2. Copy the CLAUDE.md from `02-domains/hrm/CLAUDE.md` and update file names/descriptions
3. Use HRM as a **reference template**, not a rigid requirement:
   - Every domain gets: `domain-overview.md`, `customers.md`, `data-model.md`, `okrs-and-metrics.md`, and a `workflows/` folder
   - Which workflow files go in `workflows/` depends on the interview — a Hiring domain might have `applicant-pipeline.md` instead of `onboarding.md`
   - `data-model.md` might have 3 entities or 10, depending on domain complexity
4. Schedule the interview using this protocol
5. Process with `/seed-product-context`
6. Update `02-domains/CLAUDE.md` to list the new domain
