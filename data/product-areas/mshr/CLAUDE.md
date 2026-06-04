<!-- Load when: navigating the MSHR data layer — match your question below and go directly to the file -->

# MSHR Data Layer — Direct Routing

| If you're asked... | Go directly to |
|---|---|
| Metric definitions, terminology, suppression rules, disambiguation | `mshr.md` |
| What table to use; what columns exist; how pipelines are structured; entity disambiguation (job vs payroll run, etc.) | `data-model.md` |
| Table/column schemas for corona, dbt, payroll, hiring/turnover pipelines | `schemas.md` |
| How the MSHR index is calculated; benchmark construction; MoM formulas | `index-methodology.md` |
| Production SQL for wages, hiring, turnover, shifts | `example-queries.md` |
| How to produce the monthly MSHR report end-to-end | `workflows/monthly-report.md` |
| How to produce a scoped or event-driven ad hoc report | `workflows/adhoc-report.md` |
| Which methodology to use for a given request type; qualification flags; efficiency rules | `workflows/code-generation-protocol.md` |
| Known SQL/Python bugs and required Databricks notebook structure | `workflows/known-pitfalls.md` |
| How the monthly PPTX is built; D-sheet structure; calculation layers; extracting charts from Databricks HTML exports | `report-production.md` |
| Data freshness, refreshing source tables, recreating the January benchmark table | `workflows/data-sourcing.md` |
| How to analyze event impact on small businesses | `workflows/event-impact-methodology.md` |

**Do not read all files in this folder.** Pick the one file that answers the question and read only that.
