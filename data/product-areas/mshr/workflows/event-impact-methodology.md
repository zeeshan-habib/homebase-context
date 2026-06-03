---
owner: vlad-akimenko
last_updated: 2026-05-28
review_cadence: quarterly
next_review: 2026-08-28
source: internal
refs:
  - data/product-areas/mshr/workflows/event-impact-template.py
  - data/product-areas/mshr/workflows/adhoc-report.md
---

# Event Impact Methodology

Load when you need to understand the statistical approach used to measure how an event (sporting event, natural disaster, policy change, economic shock) affects small business labor metrics.

The reference implementation of this methodology is `event-impact-template.py`. This file describes **what it does and why** — read this before running or adapting the template.

---

## Overview

The event impact analysis answers: **did labor activity at small businesses near this event change more than we'd expect from normal seasonal variation?**

It uses a **seasonality-adjusted YoY delta** approach with statistical significance testing, comparing the event period to a baseline of equivalent weeks in the prior year.

---

## Three-Segment Business Model

Each event analysis splits the geographic sample into three segments, defined by proximity to the event:

| Segment | Definition | Purpose |
|---|---|---|
| **Impact zone** | Businesses within X miles of the event venue | Primary treatment group — directly exposed to the event |
| **Comparison region** | Businesses in the broader metro area, outside the impact zone | Controls for city-level factors (weather, local economy) |
| **National baseline** | All US qualifying businesses | Controls for macro factors (holidays, seasonality, economic cycles) |

The impact estimate is computed as the **impact zone delta minus the comparison region delta** — this double-difference removes both seasonal effects and city-level confounders.

---

## YoY Methodology

**Why YoY instead of MoM:** events occur at fixed calendar dates. Year-over-year comparisons align day-of-week, season, and local economic context. Month-over-month comparisons would conflate event effects with normal seasonal movement.

**Steps:**

1. Pull weekly labor metrics (`employees_per_location`, `hours_per_location`) for the event period in the current year and the same weeks in the prior year
2. Compute the YoY delta for each week: `delta = current_year_value / prior_year_value - 1`
3. Separate weeks into two groups: **event period** (weeks overlapping or adjacent to the event) and **baseline period** (weeks before the event, same year)
4. Compare the distribution of event-period deltas to baseline-period deltas using Welch's t-test

**Safe end boundary:** always exclude the current week and the prior week from analysis — data is incomplete for both (see `known-pitfalls.md` → Pitfall 5).

---

## Statistical Significance Testing

Uses **Welch's t-test** (`scipy.stats.ttest_ind` with `equal_var=False`) to compare the event-period delta distribution against the baseline delta distribution.

Minimum sample requirements before calling `ttest_ind`:
- At least 2 observations in the baseline delta group
- At least 2 observations in the event period delta group

Results are reported as: mean delta, p-value, and whether the result clears a 0.05 significance threshold. A significant result means the event period showed a statistically different pattern from the baseline — not necessarily that the event caused it.

---

## CONFIG Block — Parameters to Set

The template is parameterized via a CONFIG block at the top. Adapting the template for a new event requires editing only this block:

| Parameter | What it sets |
|---|---|
| `EVENT_NAME` | Label used in output headers and chart titles |
| `EVENT_START` / `EVENT_END` | Calendar dates of the event |
| `CITY` / `STATE` | Geographic scope for the comparison region |
| `IMPACT_RADIUS_MILES` | Radius around the venue for the impact zone |
| `VENUE_LAT` / `VENUE_LON` | Coordinates of the event venue |
| `PRIOR_YEAR_OFFSET` | How many years back for the YoY comparison (default: 1) |
| `MIN_LOCS` | Minimum qualified locations required for a publishable result |

The built-in example in `event-impact-template.py` uses FIFA World Cup 2026 / Miami FL as the reference event.

---

## Output

Each analysis produces:
1. **Weekly data table** — qualified location count, employees per location, hours per location, YoY delta — for all three segments across the full analysis window
2. **Statistical test results** — mean delta, p-value, significance flag for each segment
3. **Charts** — time series of YoY deltas with event period highlighted, comparison of event-period vs baseline distributions

The weekly data table is always printed before charts — chart failures should not suppress the underlying data.
