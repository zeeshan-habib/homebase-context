# Cash Out — OKRs & Metrics

Domain interpretation of how Cash Out relates to company metrics. For canonical metric definitions, see `data/glossary.md`. For computation details, tables, and dashboards, see `data/product-areas/cash-out.md`.

## What CO Tracks and Why

| Metric | Why It Matters | Ref |
|--------|---------------|-----|
| CO ARR | Primary revenue metric. Driven by volume x instant % x fee. | `data/glossary.md` |
| CO Users (MAU) | Usage health. Leading indicator of revenue. | `data/glossary.md` |
| Eligible Base | Top of funnel. Shift-active + mobile-active employees. Constraints: state blocks, company opt-out. | `data/glossary.md` |
| Enrollment Completion Rate | Funnel efficiency. Historically ~11% (Looker). Key leverage point — small improvements compound into ARR. | `data/glossary.md` |
| Activation Rate | First-time CO within period. ~42%. Measures whether enrolled users convert to revenue. | `data/glossary.md` |
| Instant Advance Rate | ~96%. Directly multiplies revenue — if this drops, ARR drops proportionally. | `data/glossary.md` |
| D120 Non-Repayment Rate | Loss rate. Blended ~2.0%. Segments differently: first-time (~6.5%) vs returning (~1.9%). Neobanks (~3.8%) are higher risk. | `data/glossary.md` |
| CO Retention (MX) | Long-term usage health. M6 ~12%. Drop-off is behavioral, not structural — users stay active and eligible but stop cashing out. | `data/glossary.md` |
| Contribution Margin | Revenue - COGS - Losses. ~26.5%. The bottom line for CO as a business unit. | `data/product-areas/cash-out.md` |

## Strategic Context

**Revenue model:** CO revenue = volume x instant % x $4.99. Growth levers are (1) expand eligible base, (2) improve enrollment conversion, (3) increase activation/retention, (4) maintain instant %. Cost levers are COGS (dominated by money movement ~82%) and losses (dominated by first-time users ~6.5%).

**Current bets:**
- **Web enrollment (full build):** Expanding CO to ~343K non-mobile employees via timeclock, SMS, and email channels. Projected $934K ARR floor. See `domains/cash-out/experiments.md`.
- **Refit model:** Redesigning the risk/limits model for CO draw sizes.
- **LCM segmentation:** Targeting eligible-but-inactive users with lifecycle marketing.

**WBR reporting:** CO is tracked weekly in the company WBR. Slide includes commentary bullets, metrics table (eligible base, enrollment & activation, usage, loss rate), PoR variance, and prior year comparison. Updated by Strategic Finance; Analytics supports pacing and validation. See `data/product-areas/cash-out.md` for data feeds and pacing methodology.

## Forecast Summary

For current forecast numbers, see [FinServ Forecast Model — Cash Out sheet](https://docs.google.com/spreadsheets/d/1OryVpdyJyrNc6fevFoX5tNj5EUUOJiZhGPwKdGHSQ0k/edit?gid=728486487#gid=728486487). Key 2026 benchmarks: ~$14.5M annualized revenue, ~48.8K CO users/month, ~63% gross margin, ~26.5% contribution margin.
