# Troubleshooting

This document records every error encountered building this dashboard, the root cause, and the fix. When a new error is encountered, add it here.

---

## Error 1: All API endpoints return 500 immediately

**Symptom:** Every request to `/api/labor`, `/api/wages`, `/api/jobs`, `/api/overview` returns HTTP 500. The dashboard shows "Some data failed to load" for all sections.

**Root cause A: `arrow` missing from `requirements.txt`**

`queries.py` uses `import arrow` for date math. If `arrow` is not in `requirements.txt`, Databricks Apps installs Python dependencies from that file on startup, and every endpoint call immediately throws `ImportError: No module named 'arrow'`.

**Fix:** Add `arrow` to `requirements.txt`. Then redeploy.

```
fastapi
uvicorn
databricks-sdk
arrow        ← this line was missing
```

**Root cause B: `month_end_dates` CTE missing from wage queries**

The reference notebook (PR_Standard_EOM_Metrics.ipynb) creates `month_end_dates` as a temp view in cell 3, then references it in cells 4–7. When directly porting the SQL from cells 4–7 into `queries.py`, the `month_end_dates` reference exists in the SQL but is never defined — causing a "Table or view not found: month_end_dates" SQL error.

**Fix:** `_month_end_cte(DATE, start)` returns the CTE definition as a string. Every wage query's `shared` prefix must include it as the first CTE:

```python
shared = f"""WITH
{_month_end_cte(DATE, start="2022-01-27")},
consideration_jobs_start AS ( ...
```

**Root cause C: Temp views don't survive between `execute_statement` calls**

Each call to `execute_statement()` is an isolated session. Temp views created in one call do not exist in the next. If `_setup_temp_views()` creates `month_end_dates`, `consideration_set`, `location_info` in three separate calls, then the hiring/turnover queries that JOIN those views immediately fail with "Table or view not found."

**Fix:** Eliminate temp view setup entirely. Use `_month_end_cte()` and `_consideration_and_location_ctes()` to embed all dependencies as inline CTEs in each query. Every `_run_sql()` call must be fully self-contained.

**Root cause D: Service principal lacks SQL warehouse access**

If `app.yaml` does not declare the SQL warehouse as a resource, the app's service principal has no `CAN_USE` permission on the warehouse. The `WorkspaceClient()` will authenticate successfully but every `execute_statement` call fails with a permission error.

**Fix:** Add the resource block to `app.yaml`:

```yaml
resources:
  - name: mshr-warehouse
    sql_warehouse:
      id: "16984dfe9a2c3705"
      permission: "CAN_USE"
```

Redeploy after this change — permission grants only take effect on deploy.

**Diagnosis tip:** If you can't get logs from `databricks apps logs` (PAT tokens don't support OAuth log streaming), test the endpoint directly:

```bash
curl https://mshr-dash-373323366197249.aws.databricksapps.com/api/health
```

If `/health` returns `{"status":"ok"}`, the app is running. If it also returns 500, the issue is in `app.py` itself (before the route handlers).

---

## Error 2: Dashboard shows "Loading…" forever (page never finishes)

**Symptom:** The browser shows the loading spinner indefinitely. No error message ever appears. Network tab shows the `/api/*` requests are pending.

**Root cause:** Databricks App proxy has a hard ~60s request timeout. Heavy SQL queries (especially wages scanning `corona.shift_and_timecard_events` from 2019 with payroll cohort joins) run for 3–10 minutes. The proxy drops the connection after 60s and returns nothing to the browser. The browser's `fetch()` has no timeout, so the promise never settles — it just hangs.

**Fix:** Background loading pattern.

1. Queries run in a daemon background thread on app startup (`threading.Thread(target=_warm, daemon=True).start()` in the `startup` event).
2. API endpoints check the cache and return `{"loading": true}` if the query isn't done yet — they never block.
3. The React frontend polls every 15 seconds for sections still loading.

This means the proxy never sees a slow request. The HTTP round-trip is always instant.

**Secondary fix:** Restrict date ranges to reduce total query time:
- Wages: scan from `2022-01-01` instead of `2019-01-01` (Jan 2022 baseline still captured)
- Jobs: `month_end_dates` sequence starts from `2024-01-27` instead of `2019-01-27`

---

## Error 3: Dashboard shows 502 Bad Gateway

**Symptom:** Error message reads "Labor: /labor → 502" or "Overview: /overview → 502".

**Root cause:** Same as Error 2 — the proxy timeout. A 502 means the proxy connected to the backend but got no response before the timeout. 500 means the backend responded with an error. 502 means the backend was still running the query when the proxy gave up.

**Fix:** Same as Error 2 (background loading). Additionally, if the `/overview` endpoint was still being called while also running `/labor`, `/wages`, `/jobs` in parallel — the total query load doubled. Remove the `/overview` endpoint from the frontend parallel fetch; compute KPI card values client-side from the labor/wages/jobs data already returned.

---

## Error 4: Page still shows old layout after deploy

**Symptom:** After deploying a new `static/dist/main.js`, the browser still shows the previous version of the dashboard.

**Root cause:** Browser caching. The Databricks App proxy serves `main.js` with aggressive cache headers. `F5` (normal refresh) doesn't bypass the cache.

**Fix:** Hard refresh — **Cmd+Shift+R** (Mac) or **Ctrl+Shift+R** (Windows/Linux). This forces the browser to re-download all assets, bypassing the cache.

If the old version persists even after hard refresh, confirm the sync actually uploaded the new file:
```bash
databricks sync . /Workspace/Users/zhabib@joinhomebase.com/mshr-dash ...
# Should show: "Uploaded static/dist/main.js"
```

---

## Error 5: "databricks apps logs" fails with OAuth error

**Symptom:** Running `databricks apps logs mshr-dash` returns `Error: OAuth Token not supported for current auth type pat`.

**Root cause:** The app log streaming endpoint requires an OAuth session (browser-based login), not a PAT token. The CLI's `--profile DEFAULT` uses a PAT token which is rejected.

**Workaround:** You cannot stream live app logs with a PAT token. Diagnose from code review and endpoint testing instead:

```bash
# Test health endpoint
curl https://mshr-dash-373323366197249.aws.databricksapps.com/api/health

# Test individual endpoints (will show the Python exception in the response body)
curl https://mshr-dash-373323366197249.aws.databricksapps.com/api/labor
# If erroring: {"data":null,"loading":false,"error":"RuntimeError: Query failed..."}
```

The `app.py` error handler returns the full Python exception string in the `error` field of the response body. The React frontend displays this in the section's error state.

---

## Error 6: Wages query returns correct national data but 0 rows for by-industry

**Symptom:** National wages chart shows data, but by-industry tab is empty or shows fewer industries than expected.

**Root cause candidate A:** `business_type` column is NULL or missing for many locations. The `HAVING sample_size_jobs > 20` filter then eliminates all groups.

**Root cause candidate B:** If the query was accidentally changed from `locations.business_type` (legacy) to `locations.business_type_new`, the industry labels will be different and may not match what's in the timeseries data.

**Fix:** Ensure the by-industry query uses `locations.business_type` (the legacy column) to exactly match the reference notebook:

```sql
-- From notebook cell 5 — use business_type, not business_type_new
SELECT job_averages.period_end, locations.business_type, AVG(...) ...
FROM public.locations INNER JOIN job_averages ...
WHERE locations.state NOT IN ('Not USA', 'Unclassified')
GROUP BY locations.business_type, job_averages.period_end
```

---

## Error 7: "execute_statement" fails with timeout error before 50s

**Symptom:** Queries fail with `wait_timeout out of range` or similar error.

**Root cause:** `wait_timeout` must be a string between `"5s"` and `"50s"` inclusive. Passing `"0s"`, `"60s"`, `"5m"`, or an integer will cause an error.

**Fix:** Keep `wait_timeout="50s"` and implement the polling loop for queries that run longer than 50s:

```python
result = w.statement_execution.execute_statement(
    warehouse_id=WAREHOUSE_ID, statement=sql, wait_timeout="50s",
)
while result.status.state in (StatementState.PENDING, StatementState.RUNNING):
    time.sleep(3)
    result = w.statement_execution.get_statement(result.statement_id)
```

---

## Error 8: Warehouse startup delay — queries fail or timeout on first request

**Symptom:** The first request after the app has been idle succeeds at the HTTP level (no 500/502) but the query eventually fails with "Warehouse is starting" or takes 5+ minutes.

**Root cause:** Databricks SQL warehouses auto-stop after a period of inactivity. The first query must wait for the warehouse to start (can take 2–5 minutes). If this happens during the background warm-up, the warm-up simply takes longer — not an error. If it happens during a request (if background loading is bypassed), the proxy timeout kicks in.

**Behavior with background loading:** The `_warm()` function will wait for the warehouse to start. The frontend shows loading spinners during this time. Once the warehouse is up and the queries complete, all sections fill in at once. This is expected and acceptable.

**If you want to reduce cold-start impact:** Configure the SQL warehouse to not auto-stop (or set a longer idle timeout) in the Databricks workspace settings. This keeps the warehouse warm between deployments.

---

## Error 9: Service principal can use the warehouse but can't access tables

**Symptom:** `/api/health` returns `{"status":"ok","cached":[]}`, but API endpoints return errors like `"PERMISSION_DENIED: User does not have SELECT privilege on..."` or `"TABLE_OR_VIEW_NOT_FOUND"`.

**Root cause:** The `app.yaml` warehouse resource grants `CAN_USE` on the SQL warehouse (the right to submit queries), but does NOT grant access to the underlying data tables. Data access is controlled separately through Unity Catalog permissions.

**Fix:** A workspace admin must grant the app's service principal SELECT access on the relevant schemas. The service principal name is `app-4iecla mshr-dash` (client ID `282a3890-93b5-486c-af12-cee9f418f721`).

```sql
-- Run in a Databricks notebook as admin:
GRANT SELECT ON SCHEMA corona TO `app-4iecla mshr-dash`;
GRANT SELECT ON SCHEMA postgres TO `app-4iecla mshr-dash`;
GRANT SELECT ON SCHEMA public TO `app-4iecla mshr-dash`;
```

Or grant at the catalog level if all three schemas are in the same catalog.

---

## Error 10: National wages tooltip shows `25.13` instead of `+25.13%`

**Symptom:** Hovering on the national wages chart shows a raw number without the percent sign.

**Root cause:** Recharts passes `p.value` as the raw number to the tooltip. The original `CustomTooltip` component did not format it — just rendered `p.value` directly.

**Fix:** Pass a `formatVal` function to the tooltip component. For the national tab, format as a signed percent:

```jsx
<Tooltip
  content={(props) => <ChartTooltip {...props}
    formatVal={(v) => `${parseFloat(v) >= 0 ? "+" : ""}${parseFloat(v).toFixed(2)}%`}
  />}
/>
```

For the by-industry tab, format as dollar amount:
```jsx
formatVal={(v) => `$${parseFloat(v).toFixed(2)}`}
```

---

## Quick diagnosis checklist

When something breaks, check these in order:

1. **Is the app running?**
   ```bash
   databricks apps get mshr-dash | jq '.app_status.state'
   # Should be: "RUNNING"
   ```

2. **Is the health endpoint reachable?**
   ```bash
   curl https://mshr-dash-373323366197249.aws.databricksapps.com/api/health
   ```

3. **What's the actual error message?**
   The error field in the API response contains the Python exception. Open DevTools → Network, click the failing request, read the response body.

4. **Is the browser serving the new JS?**
   DevTools → Network → filter for `main.js` → check the response timestamp. If it matches your deploy time, the new bundle is being served. If not, hard refresh.

5. **Was `arrow` forgotten in requirements?**
   Check `requirements.txt` — it must contain `arrow` on its own line.

6. **Was the sync correct?**
   Re-run the sync command and check that `queries.py` and `static/dist/main.js` appear in the "Uploaded" list.
