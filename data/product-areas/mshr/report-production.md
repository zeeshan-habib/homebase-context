---
owner: vlad-akimenko
last_updated: 2026-05-28
review_cadence: monthly
next_review: 2026-06-28
source: internal
refs:
  - data/product-areas/mshr/mshr.md
  - data/product-areas/mshr/index-methodology.md
  - data/product-areas/mshr/workflows/monthly-report.md
---

# MSHR — Report Production Pipeline

Load when you need to understand how the monthly PPTX is produced — how Looker data flows into D-sheets, how the calculation layers work, or how to read/interpret chart values.

For the end-to-end monthly production workflow (data cutoff, QA, publish steps), see `workflows/monthly-report.md`.

---

## File Architecture

The monthly PPTX report is generated from a single master Excel file: **`Main Street Health Report - 2026.xlsx`**.

```
Looker (daily indexed values)  ──►  D-sheets (raw data pulls)  ──►  Labor Activity / Wages Activity  ──►  PPTX slides
Python script (monthly wages,
  hiring, turnover)            ──►  D-sheets (raw data pulls)  ──┘
```

The Cover sheet tracks every published PPTX linked from the workbook, timestamped by publication date. It also defines the cell colour legend: input cells, hardcoded historical values, linked cells, and formula cells.

---

## D-Sheets — Data Inputs

Each D-sheet is a direct data pull. The O-sheets (calculation intermediates) are not needed for understanding or regenerating the report — all final numbers live in **Labor Activity** and **Wages Activity**.

### `D-Employees_working` and `D-Hours_worked`

**Source:** Looker Explore `coronavirus_data_aph_jan_[YYYY]` (one explore per year, e.g. `coronavirus_data_aph_jan_2026`)

**Grain:** Daily. One row per calendar date. One column-pair per year (2022–2026).

| Looker field | Role |
|---|---|
| `Event Date Date.Date` | The calendar date |
| `(Aggregate) Changes Relative to Benchmark.Relative Level Agg Users with Clock In` | Indexed employees working — % above/below January baseline |
| `(Aggregate) Changes Relative to Benchmark.Relative Level Agg Total Hours Worked` | Indexed hours worked — % above/below January baseline |

**Important:** the index is computed inside Looker using the `corona.location_usage_benchmarks_from_aph_jan_[YYYY]` benchmark table. By the time data lands in the D-sheet, the value is already expressed as a relative level vs. January of that year. No further indexing is done in the spreadsheet.

### `D-Regions`

Same Looker Explore as above, with `Region` added as a dimension.

| Looker field | Role |
|---|---|
| `Event Date Date.Date` | Calendar date |
| `Region` | One of: Mid-Atlantic, Midwest, Northeast, Other, Southeast, Southwest, West |
| `(Aggregate) Changes Relative to Benchmark.Relative Level Agg Locs with Clock Ins` | Indexed businesses open by region |

### `D-Industry`

Same Looker Explore, with `Business Type` added as a dimension.

| Looker field | Role |
|---|---|
| `Event Date Date.Date` | Calendar date |
| `Business Type` | Industry label (matches `corona.shift_and_timecard_events.industry`) |
| `(Aggregate) Changes Relative to Benchmark.Relative Level Agg Users with Clock In` | Indexed employees working by industry |

Industries present in the data: Beauty & Wellness, Caregiving, Education, Entertainment, Food Drink & Dining, Home & Repair, Hospitality, Medical/Veterinary, Personal Services, Professional Services, Public/Nonprofit, Retail, Transportation & Logistics.

### `D-Wage+Labour_cost`

**Source:** Python payroll cohort query (the matched-cohort wage script).

**Grain:** Monthly. Two sections side by side.

| Column | Definition |
|---|---|
| `segmented_by` | `'national'` for the overall cut |
| `period_end` | Month end date (27th of reporting month) |
| `wage_rate` | Average hourly wage — two-step matched-cohort calculation |
| `sample_size_jobs` | `COUNT(DISTINCT job_id)` for that period |
| `business_type` | Industry label (second section only — BY JOB AND INDUSTRY) |

Data runs from January 2019. The Jan 2022 national `wage_rate` = **$11.4829** — this is the fixed denominator for all "% above January 2022" calculations in the report.

### `D-Hiring+Turnover`

**Source:** Python hiring/turnover query.

**Grain:** Monthly. Two sections (HIRING and TURNOVER) side by side.

| Column | Definition |
|---|---|
| `period_end` | Month end date (27th of reporting month) |
| `ss` | `COUNT(DISTINCT location_info.location_id)` — number of qualifying US locations in the period. Built from `consideration_set` → `location_info`. Used as the per-location normalization denominator: `timeseries_data / ss`. |
| `timeseries_data` | Raw count of jobs added (HIRING) or jobs archived (TURNOVER) |

Data runs from January 2019. Turnover data begins March 2019 (earlier months NULL).

---

## Calculation Layer — Labor Activity 2026

### Reference date for each month

The report uses the **Sunday of the week containing the 12th** of each month as the anchor date. The 7-day window runs Sunday through Saturday (Sun ≤ date ≤ Sat). See `index-methodology.md` for the full reference Sunday lookup table.

### 7-day rolling average

```
avg_indexed_value = AVERAGE(indexed_value WHERE date IN [sunday .. saturday])
```

Applied to whichever D-sheet column corresponds to the target year. The 7-day window smooths out day-of-week effects.

### Month-over-month change

```
MoM_change = avg_indexed_value(current_month) − avg_indexed_value(prior_month)
```

Both averages are already in indexed units (relative to January of each year). The difference is the MoM change in the indexed series — which is what slides 3, 4, 5, and 6 display. There is **no additional division** — the subtraction of two indexed values gives the percentage-point change directly.

### How to read the chart values

The chart shows three years overlaid (e.g. 2024, 2025, 2026). Each year's series starts at 0 in January and accumulates from there. A value of +0.018 for May → June in 2025 means: the indexed level of employees working in the June reference week was 1.8 percentage points higher than in the May reference week of 2025, each relative to that year's January baseline.

**You cannot compare absolute levels across years from these charts.** For absolute comparison, use the absolute `wage_rate` values in `D-Wage+Labour_cost` or query the underlying corona/payroll tables directly.

---

## Calculation Layer — Wages Activity 2026

### Absolute wages (Slide 8)

Direct pass-through from `D-Wage+Labour_cost.wage_rate` per `period_end` per `business_type`. No transformation. Plotted as dollar values on the time series.

Industries shown in the published report: Food & Drink, Entertainment (Leisure & Entertainment), Retail, Health Care, Professional Services, Total (national all-industry).

### Wages relative to January 2022 (Slide 7)

```
pct_above_jan2022 = (current_wage_rate − 11.4829) / 11.4829
```

The $11.4829 denominator is the national `wage_rate` for the period ending 2022-01-27 — the first full month after Homebase Payroll matured (product launched 2021, first complete year 2022). This baseline never changes across reports.

### MoM % change in wages by industry

```
MoM_pct_change = (current_month_wage / prior_month_wage) − 1
```

Computed per industry from the BY JOB AND INDUSTRY section of `D-Wage+Labour_cost`. Used in slide subheads to state month-level wage movements.

### Hiring per location (Slide 9) — normalization-first order

```
Step 1 — Normalize:     jobs_per_loc = timeseries_data / ss
Step 2 — MoM change:   MoM_pct = (current_month_jobs_per_loc / prior_month_jobs_per_loc) − 1
Step 3 — Index to Jan: cumulative_change = (current_month_jobs_per_loc − jan_jobs_per_loc) / jan_jobs_per_loc
```

**Normalization comes before MoM calculation**, not after. This prevents the growing consideration set (`ss`) from artificially inflating or deflating the apparent MoM change. January of each year resets the index to 0.

National benchmarks (jobs added per location per month):
- Jan 2026: 2.34 | Jan 2025: 2.39 | Jan 2024: 2.58 | Jan 2023: 2.73

### Turnover per location (Slide 10)

Identical three-step calculation using the TURNOVER section of `D-Hiring+Turnover`.

National benchmarks (jobs archived per location per month):
- Jan 2026: 3.10 | Jan 2025: 3.20 | Jan 2024: 3.35 | Jan 2023: 3.42

---

## Narrative Language Patterns

The report is written for external audiences (press, economists, policy analysts). Published reports follow these structural and language conventions:

| Element | Pattern observed | Example |
|---|---|---|
| **Slide title** | Active verb phrase naming the direction | "Workforce Participation Stalls Heading Into Spring" |
| **Subtitle** | Actual number + prior-year comparison + economic inference | "April marked the first negative Mar–Apr reading in three years (-0.2%), reversing the +1.1% to +1.2% gains seen in 2024 and 2025..." |
| **Chart note** | Literal data definition | "Data compares rolling 7-day averages for weeks encompassing the 12th of each month." |

**Recurring framing patterns observed across published reports:**
- All three years (current + prior 2) are shown. The current year is framed as "above," "below," or "tracking" prior years.
- Reports lead with the number, then the interpretation — the specific value is always cited before any interpretation.
- Seasonal moves are acknowledged — declines described as "consistent with seasonal patterns" unless anomalous.
- Small business agency language observed: SMBs "manage payroll cautiously," "hire to backfill," "correct for over-hiring" — not passive framing.
- Wages and labor activity are frequently contrasted to surface the divergence story (fewer workers, higher pay).
- Slide 2 (At A Glance) synthesizes all six metrics into a one-paragraph month title and three segment takeaways (Workforce & Hours / Industry & Region / Hiring & Turnover).

**Report cadence:** The PPTX was historically published in two packs (Pack 1 = labor metrics shortly after month end; Pack 2 = wages + hiring/turnover ~2 weeks later). Starting with the 2025 series this merged into a single monthly release.

---

## Chart Extraction from Databricks HTML Exports

Databricks notebooks export as HTML files containing a `NOTEBOOK_MODEL` JavaScript variable with base64-encoded content. Charts are embedded inside as `image/png` data. To extract:

```python
import re, base64, urllib.parse, json

with open('notebook_export.html', 'r') as f:
    content = f.read()

m = re.search(r"NOTEBOOK_MODEL\s*=\s*'(.*?)'", content, re.DOTALL)
nb = json.loads(urllib.parse.unquote(base64.b64decode(m.group(1)).decode('utf-8')))

# Charts are in commands[n]['results']['data'] as type=mimeBundle items
for cmd in nb['commands']:
    for item in (cmd.get('results') or {}).get('data', []):
        if item.get('type') == 'mimeBundle' and 'image/png' in item.get('data', {}):
            img_bytes = base64.b64decode(item['data']['image/png'])
            with open('chart.png', 'wb') as f:
                f.write(img_bytes)
```

Step outputs (text, tables) are in `item['type'] == 'ansi'` items in the same `data` list.
