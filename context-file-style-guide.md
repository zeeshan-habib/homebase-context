# Context File Style Guide

Load this file when authoring or reviewing context files for the homebase-context repo.

---

## Core Principle

Every line must contain information the model cannot figure out on its own. If it's inferable from the codebase, public docs, or training data — cut it. [1]

---

## What Belongs in a Context File

| Include | Example |
|---|---|
| Proprietary metric definitions | "paying active" = location with `is_paying = true` and activity in trailing 28d |
| Table/column names and schemas | `bizops.dim_locations.is_paying` |
| Business logic and edge cases | A location can be paying but not engaged |
| Disambiguation rules | "active" has 4+ meanings — always specify which |
| Source-of-truth routing | Behavioral data → Amplitude; business metrics → Databricks semantic layer |

## What Does NOT Belong

| Exclude | Example of what to cut |
|---|---|
| Codebase overviews | "The repo has a src/ folder with..." |
| General SQL syntax | "Use LEFT JOIN when..." |
| Motivational framing | "You are a helpful analytics partner..." |
| Rationale for rules | "This is important because..." |
| Redundant public docs | Anything already in a README or wiki |

---

## Formatting Rules

Use tables and conditional patterns over prose.

Do:
```
| Trigger | Action |
|---|---|
| "active" | Ask: paying, engaged, shift active, or payroll active? |
```

Don't:
```
When a user mentions the word "active," it's important to clarify what they mean
because Homebase has several different definitions of active including paying,
engaged, shift active, and payroll active.
```

Use IF/THEN for behavioral rules:
```
IF user term ≠ official definition → surface the gap, don't silently translate
```

Use imperative verbs, not descriptions:
- Do: "Ask which active definition before proceeding"
- Don't: "It's helpful to clarify the active definition with the user"

Keep bullets unnested and short. One idea per line.

---

## File Size Targets

| File type | Target |
|---|---|
| Behavioral instructions | 1,000–2,000 chars |
| Environment/routing | 500–1,000 chars |
| Domain/metric definitions | 2,000–5,000 chars |
| Schema references | As needed |

IF a file exceeds its target → audit every line against: "Would the model get this wrong without this line?"

---

## Structure Checklist for New Files

Before adding a new context file:

1. **Does this information exist in training data?** If yes, don't write the file
2. **Is there an existing file this should merge into?** Prefer fewer, denser files over many thin ones
3. **Can every statement be verified against a source of truth?** Don't write context from memory — check the schema, the dashboard, or the codebase
4. **Does the README index reference this file?** Every file must be listed in the README with a "when to load" description

---

## Anti-Patterns

| Pattern | Example |
|---|---|
| Kitchen sink | Cramming every instruction into one file instead of splitting by domain |
| Hedge | "You might want to consider checking..." — either it's a rule or it's not |
| Echo | Restating something already in another context file |
| Tutorial | Explaining what a JOIN is. The model knows. Tell it what's specific to Homebase |
| Wishlist | Instructions for capabilities the agent doesn't have today |

---

[1] Research basis: [Evaluating AGENTS.md (ETH Zurich, 2026)](https://arxiv.org/abs/2602.11988) — unnecessary context instructions reduce agent success rates and increase cost by 20%+. Exception: proprietary domain knowledge the model genuinely lacks.
