---
owner: ray-sanza, vlad
last_updated: 2026-05-14
review_cadence: monthly
next_review: 2026-06-14
source: internal
refs: []
---

<!-- Load when: getting oriented to what MSHR is, its report tracks, production cycle, and domain boundaries -->

# MSHR Domain Overview

## What MSHR Is

The Main Street Health Report (MSHR) is Homebase's aggregated small business economy report. It takes operational signal data from across the Homebase platform — shifts, time clocks, hires, separations — and rolls it up to produce economy-level employment metrics for U.S. small businesses.

The repo is internal: it records all context, metric definitions, table locations, and production logic so that Claude (and analysts) can query Databricks and produce the report without manual re-explanation. The outputs of that process are used to build public-facing reports published by leadership and the GTM team.

## Report Purpose

MSHR answers the question: *What is happening with employment, hiring, and workforce health at U.S. small businesses right now?*

It is not a product health report. It does not measure Homebase's own growth or retention. It uses Homebase's data as a signal layer for the external economy — specifically the segment of the U.S. labor market that small businesses represent.

Consumers of the output:
- **Internal**: Leadership (CRO and above) and GTM team use the data to build narratives, press releases, and research publications.
- **External / public**: Reports derived from this domain are published externally as Homebase's research voice on small business employment.

## Report Tracks

Two production tracks exist:

| Track | Cadence | Trigger |
|---|---|---|
| Monthly MSHR | Every month | Calendar-driven; fixed data cutoff and publish schedule |
| Ad Hoc MSHR | As needed | Leadership or GTM request; specific question or event-driven |

Both tracks draw from the same underlying data and metric definitions. The ad hoc track may scope to a subset of metrics or a specific time window.

## Production Cycle

1. **Data cutoff** — 27th of the reporting month. Confirm `MAX(event_date)` in `corona.shift_and_timecard_events`, `MAX(payday)` in `postgres.payroll_payroll_runs`, and `MAX(created_at)` in `postgres.jobs` all meet or exceed this date.
2. **Looker pull** — Export indexed daily values from Looker Explore `coronavirus_data_aph_jan_[current_year]` into four D-sheets in the master Excel file: D-Employees_working, D-Hours_worked, D-Regions, D-Industry.
3. **Python script runs** — Execute payroll cohort query → paste results into D-Wage+Labour_cost. Execute hiring and turnover queries → paste into D-Hiring+Turnover.
4. **Excel auto-calculation** — Labor Activity and Wages Activity sheets automatically compute 7-day rolling averages, MoM changes, per-location normalization (÷ `ss`), and indexing to January from the D-sheets. No manual formula entry needed.
5. **QA** — Validate data freshness, suppression thresholds (`sample_size_jobs > 20`), and MoM anomalies. See `workflows/monthly-report.md` for the full checklist.
6. **PPTX assembly** — Update slides with computed values from Labor Activity and Wages Activity; write narrative following the title/subtitle/note formula documented in `mshr.md`.
7. **Review** — Ray Sanza reviews narrative framing and headline metric accuracy; Vlad signs off on data accuracy and suppression compliance.
8. **Publish** — Save final PPTX; log it in the Cover sheet of the master Excel file with the publication date.

## Key Workflows

| Workflow | File | Description |
|---|---|---|
| Monthly report production | workflows/monthly-report.md | End-to-end steps for the regular monthly MSHR |
| Ad hoc report production | workflows/adhoc-report.md | Steps for scoped, event-driven MSHR requests |
| Data sourcing | workflows/data-sourcing.md | How to identify, refresh, and validate source tables in Databricks |

## Domain Boundaries

| In scope | Out of scope |
|---|---|
| Aggregated employment metrics derived from Homebase platform data | Homebase product health metrics (DAU, retention, revenue) |
| U.S. small business economy signals | Individual company or location-level data (not aggregated) |
| Monthly and ad hoc public-facing report production | Real-time dashboards or operational alerting |

## Ownership

| Role | Person |
|---|---|
| DRI / Executive sponsor | Ray Sanza (Chief Revenue Officer) |
| Data owner / production lead | Vlad (former manager) |
| Analyst | Zeeshan Habib |

## Cadence

- **Monthly**: Fixed schedule; data cutoff and publish date TBD once production steps are confirmed.
- **Ad hoc**: No fixed schedule; triggered by leadership or GTM request.
