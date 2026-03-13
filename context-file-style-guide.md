# Context File Style Guide

Load this file when authoring or reviewing context files for the homebase-context repo.

---

## Core Principle

Every line must contain information the model cannot figure out on its own. If it's inferable from the codebase, public docs, or training data - cut it.

Research supports this: unnecessary context instructions reduce agent success rates and increase inference cost by 20%+. The exception is proprietary domain knowledge the model genuinely lacks. [1]

---

## What Belongs in a Context File

| Include | Example |
|---|---|
| Proprietary metric definitions | "engaged" = location with `engagement_boolean = 1`|
| Table/column names and schemas | `bizops.product_location_engagement_metrics.engagement_boolean` |
| Business logic and edge cases | A location can be paying but not engaged |
| Disambiguation rules | "active" has 4+ meanings - always specify which |
| Source-of-truth routing | Behavioral data → Amplitude; business metrics → Databricks semantic layer |
| Known LLM failure modes | Things the model consistently gets wrong without this context |

## What Does NOT Belong

| Exclude | Example of what to cut |
|---|---|
| Codebase overviews | "The repo has a src/ folder with..." |
| General SQL syntax | "Use LEFT JOIN when one table may have missing rows" (model knows this - but "always LEFT JOIN dim_locations to dim_companies because of orphaned records" is Homebase-specific and belongs) |
| Motivational framing | "You are a helpful analytics partner..." |
| Rationale for rules | "This is important because..." |
| Redundant public docs | Anything already in a README or wiki |

---

## File Header Requirement

Every context file must start with a one-line description of what it covers and when to load it. This line appears in the folder's `CLAUDE.md` index and helps AI tools decide whether to load the file.

Example:
```
# Engagement Metrics

Load when answering questions about DAU, WAU, MAU, or any product engagement/activity metric.
```

---

## Progressive Disclosure

Do not write files expecting them all to be loaded at once. Each file should stand alone for its domain and be useful without the others.

- Write so the file makes sense in isolation
- Don't reference other context files unless necessary for disambiguation
- Assume the model loads only 1-3 files per task

---

## Finding the Right Altitude

Calibrate between two failure modes:

**Too prescriptive**: Hardcoding IF/THEN rules for every possible scenario. This is brittle and bloats the file.

**Too vague**: "Be careful with dates" or "think about edge cases." This adds tokens without changing behavior.

The sweet spot: specific enough to prevent known mistakes, flexible enough to handle variations. Write rules for the cases where the model actually fails, not for every hypothetical.

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

For rules that are worth writing, use IF/THEN format:
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
| Behavioral instructions | 1,000-2,000 chars |
| Environment/routing | 500-1,000 chars |
| Domain/metric definitions | 2,000-5,000 chars |
| Schema references | As needed |

IF a file exceeds its target → audit every line against: "Would the model get this wrong without this line?"

---

## Structure Checklist for New Files

Before adding a new context file:

1. **Does this information exist in training data?** If yes, don't write the file
2. **Is there an existing file this should merge into?** Prefer fewer, denser files over many thin ones
3. **Can every statement be verified against a source of truth?** Don't write context from memory - check the schema, the dashboard, or the codebase
4. **Does the file start with a header?** One-line description of scope and when to load
5. **Does the folder's CLAUDE.md index reference this file?** Every file must be listed in the relevant subfolder's `CLAUDE.md` with a "when to load" description
6. **Can you test it?** Run a real question against the model with and without this file. If the output doesn't improve, the file isn't earning its tokens

---

## Anti-Patterns

| Pattern | Example |
|---|---|
| Kitchen sink | Cramming every instruction into one file instead of splitting by domain |
| Hedge | "You might want to consider checking..." - either it's a rule or it's not |
| Echo | Restating something already in another context file |
| Tutorial | Explaining what a JOIN is. The model knows. Tell it what's specific to Homebase |
| Wishlist | Instructions for capabilities the agent doesn't have today |
| Stale context | An outdated metric definition or deprecated table name left in a file. The model will use it confidently. Stale context is worse than no context |
| Overload | Loading every context file for every task. More context ≠ better results |

---

## References

[1] [Evaluating AGENTS.md](https://arxiv.org/abs/2602.11988) - Gloaguen, Mundler, Muller, Raychev, Vechev. ETH Zurich, 2026.

Further reading:
- [Effective Context Engineering for AI Agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) - Anthropic, 2025.
- [Context Repositories](https://www.letta.com/blog/context-repositories) - Letta, 2026.
- [Context Engineering for Coding Agents](https://martinfowler.com/articles/exploring-gen-ai/context-engineering-coding-agents.html) - Bockeler, 2026.
