# Date Conventions — SQL Patterns for Analytics Queries

**When to use this file:** Any query involving date filtering, grouping, or period-over-period comparison.

---

## 1. SQL Environment Note

All date functions below use **Databricks SQL** syntax. Key differences from BigQuery:
- `DATE_TRUNC('MONTH', date)` not `DATE_TRUNC(date, MONTH)`
- `DATEDIFF(end_date, start_date)` returns days (integer)
- `date + INTERVAL n DAYS` or `DATEADD(DAY, n, date)` for arithmetic
- `DATE_FORMAT(date, 'yyyy-MM')` not `FORMAT_DATE('%Y-%m', date)`

---

## 2. Standard Date Aggregation Granularities

| Granularity | Databricks SQL | Output Format |
|---|---|---|
| Day | `DATE_TRUNC('DAY', date_col)` | `2024-01-15` |
| Week (Mon start) | `DATE_TRUNC('WEEK', date_col)` | `2024-01-15` (Monday) |
| Month | `DATE_TRUNC('MONTH', date_col)` | `2024-01-01` |
| Quarter | `DATE_TRUNC('QUARTER', date_col)` | `2024-01-01` |
| Year | `DATE_TRUNC('YEAR', date_col)` | `2024-01-01` |
| Month label | `DATE_FORMAT(date_col, 'yyyy-MM')` | `2024-01` |
| Year only | `YEAR(date_col)` | `2024` |

Homebase uses **Monday** as the start of week. `DATE_TRUNC('WEEK', ...)` in Databricks returns the ISO Monday of that week — no adjustment needed.

---

## 3. Relative Date Windows (Trailing Periods)

| Window | SQL |
|---|---|
| Last 7 days | `date_col >= CURRENT_DATE - INTERVAL 7 DAYS` |
| Last 28 days | `date_col >= CURRENT_DATE - INTERVAL 28 DAYS` |
| Last 30 days | `date_col >= CURRENT_DATE - INTERVAL 30 DAYS` |
| Last 90 days | `date_col >= CURRENT_DATE - INTERVAL 90 DAYS` |
| Yesterday | `date_col = CURRENT_DATE - INTERVAL 1 DAY` |
| Week to date | `date_col BETWEEN DATE_TRUNC('WEEK', CURRENT_DATE) AND CURRENT_DATE` |
| Month to date | `date_col BETWEEN DATE_TRUNC('MONTH', CURRENT_DATE) AND CURRENT_DATE` |
| Quarter to date | `date_col BETWEEN DATE_TRUNC('QUARTER', CURRENT_DATE) AND CURRENT_DATE` |

Use `CURRENT_DATE` (no parentheses) in Databricks SQL.

---

## 4. Calendar Period Filters

```sql
-- Full calendar month (parameterized)
WHERE date_col BETWEEN '2024-01-01' AND '2024-01-31'

-- Full calendar month (dynamic — current month)
WHERE DATE_TRUNC('MONTH', date_col) = DATE_TRUNC('MONTH', CURRENT_DATE)

-- Full prior calendar month
WHERE DATE_TRUNC('MONTH', date_col) = DATE_TRUNC('MONTH', CURRENT_DATE - INTERVAL 1 MONTH)

-- Full calendar quarter (current)
WHERE DATE_TRUNC('QUARTER', date_col) = DATE_TRUNC('QUARTER', CURRENT_DATE)
```

---

## 5. Period-Over-Period Comparison Pattern

Compare any metric for this period vs. the equivalent prior period in the same query.

```sql
SELECT
    DATE_TRUNC('WEEK', date_col)               AS week_start,
    COUNT(DISTINCT CASE
        WHEN date_col BETWEEN DATE_TRUNC('WEEK', CURRENT_DATE)
                          AND CURRENT_DATE
        THEN location_id END)                  AS this_week,
    COUNT(DISTINCT CASE
        WHEN date_col BETWEEN DATE_TRUNC('WEEK', CURRENT_DATE) - INTERVAL 7 DAYS
                          AND CURRENT_DATE - INTERVAL 7 DAYS
        THEN location_id END)                  AS prior_week
FROM bizops.product_location_engagement_metrics
WHERE date_col >= DATE_TRUNC('WEEK', CURRENT_DATE) - INTERVAL 7 DAYS
GROUP BY 1;
```

Extend to month-over-month by swapping `INTERVAL 7 DAYS` → `INTERVAL 1 MONTH`.

---

## 6. Dynamic Aggregation (Looker / Ad-hoc)

When the user wants to "slice by day / week / month / quarter / year" in a single query, use a CASE on the grouping level:

```sql
-- Replace 'month' with the desired granularity
SELECT
    DATE_TRUNC('month', date_col) AS period,
    COUNT(DISTINCT location_id)   AS locations
FROM bizops.product_location_engagement_metrics
GROUP BY 1
ORDER BY 1;
```

Supported granularity values for `DATE_TRUNC`: `'DAY'`, `'WEEK'`, `'MONTH'`, `'QUARTER'`, `'YEAR'`.

---

## 7. Date Arithmetic Quick Reference

| Operation | Databricks SQL |
|---|---|
| Add N days | `date_col + INTERVAL n DAYS` |
| Subtract N days | `date_col - INTERVAL n DAYS` |
| Days between two dates | `DATEDIFF(end_date, start_date)` |
| Add N months | `date_col + INTERVAL n MONTHS` |
| Add N years | `date_col + INTERVAL n YEARS` |
| Cast string to date | `TO_DATE('2024-01-15', 'yyyy-MM-dd')` |
| Cast timestamp to date | `CAST(ts_col AS DATE)` or `DATE(ts_col)` |

---

## 8. Timestamp vs. Date Columns

| Column type | Behavior | When to cast |
|---|---|---|
| `DATE` | No time component; safe for equality filters | Never |
| `TIMESTAMP` | Includes time; equality filter `= '2024-01-15'` will miss rows | Always cast: `DATE(ts_col)` or `CAST(ts_col AS DATE)` before grouping |

IF a column ends in `_at` (e.g., `created_at`, `updated_at`) → assume TIMESTAMP, cast before date truncation.
IF a column ends in `_date` (e.g., `submission_date`, `date`) → assume DATE, no cast needed.

---

## 9. Cohort Date Windows

Day X (DX) = exactly X days after company signup. Anchor column: `DATEDIFF(event_date, company_created_at)`.

### Standard Checkpoints Across Products

| Day | What it measures |
|---|---|
| D1 (1D1) | First meaningful product action within 24 hours of signup. Core acquisition metric; uploaded to Google/Bing for conversion tracking. |
| D5 | Hiring job health: 20+ applicants AND 5+ top matches by Day 5. |
| D7 | 2D7 rate — early engagement signal; used in ad platform uploads alongside 1D1. |
| D14 | Trial-to-pay conversion window for Hiring (`Trial:Pay % D14`). Also Cash Out first-advance activation window. |
| D17 | Paying rate and engaged rate checkpoint for Team App funnel. |
| D30 | Primary monetization checkpoint across all products (Team App paying %, Payroll ran payroll %, Clover embedded activation, MRR/1D1). |
| D60 | Paying retention checkpoint. |
| D90 | Paying retention checkpoint (stabilized signal for cohort quality). |
| D120 | Cash Out ultimate loss rate (final default signal). |

### Trial Period

The **trial period is the first 14 days** after company signup. Applies to Hiring. `Trial:Pay % (D14)` = % of trial starts that convert to a paying subscription by Day 14.

### Product-Specific Windows

| Product | Key windows | Primary metric |
|---|---|---|
| Team App | D1, D7, D17, D30 | D30 Paying %, D30 MRR / 1D1 |
| Payroll | D30 | Day 30 Ran Payroll % |
| Hiring | D5, D14 | Trial:Pay % (D14), % Jobs Healthy by D5 |
| Cash Out | D1, D7, D14 | % First Time Activation (first advance taken); D1/D7/D14 used to measure speed-to-first-advance |
| Cash Out (loss) | D28, D30, D120 | D28 Loss Rate % (WBR primary); D30 = stabilized; D120 = ultimate |
| Clover Embedded | D30 | % activated by D30 (~45–50% target); `2D30` = active/inactive classification |
| Retention (AI) | D60, D90 | D60 and D90 paying retention rates |

### Cohort SQL Pattern

```sql
-- Companies that ran payroll within their first 30 days
SELECT
    DATE_TRUNC('MONTH', c.created_at)                    AS signup_month,
    COUNT(DISTINCT c.company_id)                         AS signups,
    COUNT(DISTINCT CASE
        WHEN DATEDIFF(p.ran_payroll_date, DATE(c.created_at)) <= 30
        THEN c.company_id END)                           AS ran_payroll_d30,
    COUNT(DISTINCT CASE
        WHEN DATEDIFF(p.ran_payroll_date, DATE(c.created_at)) <= 30
        THEN c.company_id END)
    / COUNT(DISTINCT c.company_id)                       AS d30_ran_payroll_rate
FROM public.companies c
LEFT JOIN payroll_events p ON p.company_id = c.company_id
GROUP BY 1
ORDER BY 1;
```
