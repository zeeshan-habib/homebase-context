---
owner: vlad-akimenko
last_updated: 2026-05-28
review_cadence: monthly
next_review: 2026-06-28
source: internal
refs:
  - data/product-areas/mshr/workflows/code-generation-protocol.md
---

# MSHR — Known Pitfalls

Load when generating SQL or Python against MSHR data sources, or when diagnosing unexpected query results.

These issues were discovered during live production use of `dbt.temp_timeclock_data` in Databricks. Every generated query or Python notebook must account for all of them.

---

## 1. `qualified_for_*` columns do not exist in `dbt.temp_timeclock_data`

**Error you will see:** `[UNRESOLVED_COLUMN] A column with name 'qualified_for_hours' cannot be resolved`

These flags only exist in `dbt.new_data_weekly`. Any query against `dbt.temp_timeclock_data` that references them will fail immediately. Always replace with the inline filter:

```sql
AND employee_count IN (
    '5–9 employees',
    '10–19 employees',
    '20–49 employees',
    '50–99 employees'
)
AND location_age >= 84   -- 12 weeks minimum, in days
AND loc_archived_at IS NULL
```

For `qualified_for_turnover`, use `'10–19 employees'` as the lower band floor instead of `'5–9 employees'`.

---

## 2. `employee_count` is a band string — not a number

**Error you will see:** silent wrong results or type errors if treated as numeric.

The confirmed distinct values are:
`'0 employees'`, `'1–4 employees'`, `'5–9 employees'`, `'10–19 employees'`, `'20–49 employees'`, `'50–99 employees'`, `'100–249 employees'`, `'250–499 employees'`, `'500–999 employees'`, `'Unknown'`

Always filter with `IN (...)` using the exact strings above. Never use `employee_count BETWEEN 5 AND 99` — it will return no rows.

---

## 3. City strings are mixed case in the data

**Error you will see:** missing or incomplete results with no error message — the query runs but silently returns a subset.

`dbt.temp_timeclock_data` stores city values in inconsistent case (`'Miami'`, `'MIAMI'`, `'miami'` all appear). Always:
- Filter with `UPPER(city) = 'CITYNAME'` — never `city = 'Miami'`
- Always pair with `state = 'XX'` to exclude cross-state collisions (Miami FL vs Miami OH, Portland OR vs Portland ME)
- Before writing a city-level query, run the discovery SQL first:

```sql
SELECT UPPER(city) AS city_upper, state, COUNT(DISTINCT location_id) AS locs
FROM dbt.temp_timeclock_data
WHERE state = '[STATE]' AND city ILIKE '%[partial name]%'
  AND event_date >= DATE_SUB(CURRENT_DATE, 90)
  AND loc_archived_at IS NULL
GROUP BY 1, 2 ORDER BY 3 DESC
```

---

## 4. Spark returns DECIMAL columns as `decimal.Decimal` objects in pandas

**Error you will see:** `TypeError: unsupported operand type(s) for -: 'float' and 'decimal.Decimal'` or `ValueError: data type <class 'numpy.object_'> not inexact`

Any column computed with `ROUND(...)` or division in Spark SQL may arrive as `decimal.Decimal` instead of Python `float` when converted via `.toPandas()`. This breaks pandas arithmetic, `.sem()`, `.mean()`, and scipy functions downstream.

**Fix: always cast immediately after `.toPandas()`:**

```python
for col in ['businesses_open', 'active_locs', 'employees_working',
            'hours_worked', 'emp_per_loc', 'hrs_per_loc']:
    df[col] = pd.to_numeric(df[col], errors='coerce')
```

Use `pd.to_numeric(..., errors='coerce')` — not `.astype(float)` — because `errors='coerce'` handles `None`, `NaN`, and `decimal.Decimal` safely without raising.

---

## 5. Never include the current or most recent week — data is incomplete

**Error you will see:** a sudden unexplained drop in the most recent week of every metric.

Timeclock data for the current week is always partial (the week is in progress). The immediately prior completed week is often also incompletely loaded due to data pipeline lag. Always exclude the last 2 weeks from any analysis:

```python
_current_week_start = TODAY - pd.Timedelta(days=TODAY.dayofweek)  # Monday of this week
SAFE_END = _current_week_start - pd.Timedelta(days=8)             # Last day of 2 weeks ago
```

Use `SAFE_END` as the upper bound in the SQL `WHERE event_date BETWEEN ... AND '{SAFE_END}'`. Never use `CURRENT_DATE` or `TODAY` directly as the end date for labor metrics.

---

## 6. Pandas `.loc[w, col]` on a non-unique index returns a Series, not a scalar

**Error you will see:** `ValueError: The truth value of a Series is ambiguous`

This happens when the same `iso_week` value appears more than once (e.g., at year boundaries with ISO week 52/53), causing `.loc[w, col]` to return a Series. Any conditional on a Series (`if val != 0`, `if val > x`) then raises this error.

**Fix: use a merge instead of index-based lookup:**

```python
df_curr_slim  = df[df['yr'] == current_yr][['iso_week', 'week_start', 'period'] + metric_cols]
df_prior_slim = df[df['yr'] == prior_yr  ][['iso_week'] + metric_cols]
df_delta      = df_curr_slim.merge(df_prior_slim, on='iso_week', suffixes=('_curr', '_prior'))
```

Then compute deltas as vectorised column operations — no row loops, no `.loc`.

---

## 7. Nested f-strings and Unicode characters fail in Databricks

**Errors you will see:**
- `SyntaxError: unexpected character after line continuation character` — from `f"...{f\"...\"}..."` nested f-strings
- `invalid character` errors — from Unicode arrows (`→`), special symbols (`✱`, `↑`, `↓`)

Rules for all generated Python:
- Pre-compute any variable needed inside an f-string before the `print()` call — never nest f-strings
- Use only ASCII: `->` not `→`, `*` not `✱`, `up/down` not `↑↓`

---

## 8. Required structure for every generated Python notebook

Every multi-step Python script generated for Databricks must follow this pattern:

```python
# Step N: [description]
print("=" * 70)
print("STEP N — [description]")
print("=" * 70)

try:
    # ... step logic ...

    # Validation assertions with plain-English messages
    assert condition, (
        "What went wrong in plain English.\n"
        "   How to fix it or what to share with your analyst."
    )
    print(f"OK Step N — [brief confirmation of what was produced]")

except AssertionError as e:
    print(f"\nFAILED Step N: {e}")
    print("Share this message with your analyst.")
    raise
except Exception as e:
    print(f"\nFAILED Step N — unexpected error:")
    print(f"  {type(e).__name__}: {e}")
    print("Share this full message with your analyst.")
    raise
```

**What the checks must verify at each step:**

| Step | What to assert |
|---|---|
| City discovery (Step 1) | `len(city_check) > 0` — at least one city variant found |
| Data pull (Step 2) | `len(df) > 0` — rows returned; `df['yr'].nunique() >= 2` — at least 2 years for YoY |
| Sample size (Step 3) | Print thin-sample warning if `active_locs < min_locs`; print full tabular data for manual verification |
| Delta build (Step 4) | `len(df_delta) > 0` — overlapping weeks exist between years |
| Stat sig (Step 5) | Check `len(baseline_deltas) >= 2` and `len(period_deltas) >= 2` before calling `ttest_ind` |
| Charts (Step 6) | Wrap in try/except — chart failure should not hide the data tables from Steps 3 and 5 |

The tabular print in Step 3 is not optional. Users cannot verify chart values without seeing the underlying numbers. Always print the weekly data table before generating charts.
