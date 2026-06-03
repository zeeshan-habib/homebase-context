# Architecture

## Overview

```
Browser
  │  fetch /api/labor, /api/wages, /api/jobs  (parallel)
  ▼
Databricks App proxy (HTTPS)
  │
  ▼
uvicorn  (port 8000)
  │
  ├── FastAPI sub-app  mounted at /api
  │     └── queries.py  →  Databricks SQL Statement Execution API
  │                             └── SQL warehouse 16984dfe9a2c3705
  │                                   └── Unity Catalog tables
  │
  └── StaticFiles  mounted at /  (React SPA)
```

---

## FastAPI mount pattern

The app uses two FastAPI instances with a strict mount order. **This order cannot be reversed.**

```python
app     = FastAPI()   # root app — only mounts, no routes
api_app = FastAPI()   # all API routes go here

# Routes on api_app:
@api_app.get("/labor")
@api_app.get("/wages")
@api_app.get("/jobs")
@api_app.get("/health")

app.mount("/api", api_app)                                  # MUST be first
app.mount("/", StaticFiles(directory="static", html=True))  # MUST be last
```

If the static mount is registered before `/api`, FastAPI routes `/api/*` to the filesystem before the sub-app gets a chance to handle it — the API returns 404.

---

## Background query warm-up

Databricks SQL queries are slow (30s–5+ min). The Databricks App proxy has a hard ~60s request timeout that returns a **502** to the client if a request exceeds it. Triggering queries on the first HTTP request guarantees a 502 for the heavy pipelines.

**Solution:** queries run in a daemon background thread on app startup. API endpoints return immediately:
- `{"data": ..., "loading": false}` → cache is warm, return data
- `{"data": null, "loading": true}` → query still running, try again

```python
# app.py
@app.on_event("startup")
def startup():
    threading.Thread(target=_warm, daemon=True).start()

def _warm():
    for fn in (queries.get_labor, queries.get_wages, queries.get_jobs):
        try: fn()
        except Exception: pass
```

The React frontend polls every 15 seconds for each section still showing `loading: true`. Sections fill in independently as their queries complete.

---

## Cache layer

```python
_cache: dict = {}
CACHE_TTL_FAST = 300    # 5 min — labor (relatively fast query)
CACHE_TTL_SLOW = 3600   # 1 hr  — wages, jobs (heavy historical scans)

def _cached(key, ttl, fn):
    if key in _cache and time.time() - _cache[key]["ts"] < ttl:
        return _cache[key]["data"]
    data = fn()
    _cache[key] = {"data": data, "ts": time.time()}
    return data
```

Cache is in-process memory. On Databricks Apps with a single worker process, this is safe. On restart or redeploy, the cache is cold and the background warm-up re-runs.

---

## The session-scope problem (CRITICAL)

Each call to `execute_statement()` creates a **new, independent session**. Temp views created in one call do not exist in the next.

The reference notebook (PR_Standard_EOM_Metrics.ipynb) creates temp views across cells:
```python
# Cell 3: creates temp view
spark.sql("...").createOrReplaceTempView('month_end_dates')

# Cell 4: references it
spark.sql("SELECT ... FROM month_end_dates JOIN ...")
```

This works in a notebook because Spark sessions are persistent across cells. It **does not work** via the Statement Execution API — each `execute_statement` call gets a clean session.

**Fix:** every query must be fully self-contained. All dependencies are inlined as CTEs:

```python
def _month_end_cte(DATE, start="2024-01-27"):
    return f"""
month_end_dates AS (
    SELECT
        date_add(ADD_MONTHS(month_end, -12), 1) AS year_beginning,
        date_add(ADD_MONTHS(month_end, -1),  1) AS month_beginning,
        month_end
    FROM (
        SELECT EXPLODE(sequence(to_date('{start}'), to_date('{DATE}'), interval 1 month)) AS month_end
    )
)"""

# Every query embeds it:
sql = f"WITH\n{_month_end_cte(DATE)},\n..."
```

---

## Query execution + polling

`execute_statement` has a `wait_timeout` cap of 50s. Longer queries return PENDING/RUNNING and must be polled:

```python
result = w.statement_execution.execute_statement(
    warehouse_id=WAREHOUSE_ID, statement=sql, wait_timeout="50s",
)
while result.status.state in (StatementState.PENDING, StatementState.RUNNING):
    time.sleep(3)
    result = w.statement_execution.get_statement(result.statement_id)

if result.status.state != StatementState.SUCCEEDED:
    raise RuntimeError(f"Query failed: {result.status.error}")
```

---

## React frontend

- **Bundler:** esbuild (fast, no config files needed)
- **Charts:** Recharts — pure React, handles 3-year overlaid line series well
- **Design:** Homebase DesignBase CSS variables (see `client/index.html` for the full set)
- **No framework router:** single-page with tab state managed locally in each chart component
- **`client/` and `node_modules/` are local only** — not synced to Databricks. Only `static/` is deployed.

```
Build step:
  client/src/main.jsx
    └─ esbuild (bundle + minify)
       └─ static/dist/main.js  ← deployed
```

---

## Databricks Apps service principal

The app runs as the service principal `app-4iecla mshr-dash` (ID `282a3890-93b5-486c-af12-cee9f418f721`). The `WorkspaceClient()` in the app automatically authenticates as this principal using environment variables injected by the Apps runtime.

The principal must have `CAN_USE` on the SQL warehouse. This is declared in `app.yaml`:

```yaml
resources:
  - name: mshr-warehouse
    sql_warehouse:
      id: "16984dfe9a2c3705"
      permission: "CAN_USE"
```

The principal also needs SELECT access on all data tables (`corona.*`, `postgres.*`, `public.*`). This must be granted by a workspace admin in Unity Catalog — it is not handled by `app.yaml`.

---

## Design decisions — what was tried and rejected

| Approach | Why rejected |
|---|---|
| Query on first HTTP request | Databricks App proxy times out at ~60s → 502 for heavy queries |
| `/overview` endpoint that called all 3 queries | Doubled total query count (parallel requests + overview each called all 3); removed in favor of client-side KPI computation |
| Temp views for shared CTEs | Sessions don't persist across `execute_statement` calls |
| `timeseries_data` scanned from 2019 | Too slow; wage query scoped to 2022+, jobs to 2024+ |
| Hardcoded Jan 2022 wage baseline ($11.4829) | Retroactive payroll updates change this value each run; baseline is now derived dynamically from query results |
