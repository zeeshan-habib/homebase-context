---
owner: vlad-akimenko
last_updated: 2026-05-24
review_cadence: quarterly
next_review: 2026-08-24
source: internal
refs:
  - mshr.md
---
# MSHR Metrics

Load when answering questions about what MSHR measures and what success looks like for the Main Street Health Report.

For full technical definitions (SQL logic, cohort rules, normalization, suppression), see `data/product-areas/mshr/mshr.md`.

For the canonical metric definitions used across the repo, see [`data/glossary.md`](../../data/glossary.md).

> "Business" = location; "employee" = hourly worker; "clock-in" = timecard (employee punched in).

| Metric | What it measures | Why it matters | Report slide |
|---|---|---|---|
| **Employees Working** | Distinct employees with ≥1 clock-in in the reference week (7-day avg around the 12th) | Core labor demand signal; primary headline metric | Slide 3 |
| **Hours Worked** | Total timecard hours (clock-out − clock-in) in the reference week | Captures intensity of labor, not just headcount; leads wage pressure signals | Slide 4 |
| **Businesses Open** | Locations with ≥1 clock-in in the reference week | Small business activity / survival indicator; reported by Census region | Slide 5 |
| **Hourly Wages** | Avg hourly wage, matched-cohort Payroll locations; expressed as % above Jan 2022 baseline ($11.4829) | Wage inflation signal for small business sector; industry-level breakdowns available | Slides 7–8 |
| **Jobs Added** | MoM change in new roster jobs, normalized per location | Leading indicator of hiring appetite | Slide 9 |
| **Jobs Archived** | MoM change in archived roster jobs, normalized per location | Proxy for employee turnover; lagging signal of labor market tightness | Slide 10 |
