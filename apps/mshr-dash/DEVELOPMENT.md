# Development Guide

## Prerequisites

- Databricks CLI configured for `homebase-staging.cloud.databricks.com`
- Node.js ≥ 18 (for esbuild)
- Python ≥ 3.10

### Databricks CLI auth

```bash
# Verify config
cat ~/.databrickscfg
# Should show:
# [DEFAULT]
# host = https://homebase-staging.cloud.databricks.com
# token = dapi...
```

If not configured:
```bash
databricks configure
# Enter: https://homebase-staging.cloud.databricks.com
# Enter your PAT token from the workspace settings
```

---

## First-time setup

```bash
# 1. Clone the repo and enter the project
cd mshr-dash

# 2. Install Python dependencies
pip install -r requirements.txt

# 3. Install Node build dependencies (local only, never deployed)
npm install

# 4. Build the React app
node build.js
# Output: static/dist/main.js, static/index.html
```

---

## Local development

```bash
# Run FastAPI locally (requires Databricks credentials in ~/.databrickscfg)
uvicorn app:app --host 0.0.0.0 --port 8000 --reload
```

Then open http://localhost:8000. The app will work the same as production — it queries the real Databricks SQL warehouse via your PAT token.

**Note on local query speed:** the background warm-up runs on startup. Depending on warehouse state, the first query may take 2-10 minutes if the warehouse is cold (starting up). Subsequent requests hit the cache. Check http://localhost:8000/api/health to see which keys are cached.

---

## Making frontend changes

```bash
# Edit client/src/main.jsx or client/src/components/*.jsx, then:
node build.js

# For fast iteration, run esbuild in watch mode:
npx esbuild client/src/main.jsx \
  --bundle \
  --outfile=static/dist/main.js \
  --jsx=automatic \
  --sourcemap \
  --watch
```

Then reload http://localhost:8000 (no server restart needed — esbuild rebuilds the bundle).

---

## Making backend changes

Edit `queries.py` or `app.py`, then restart uvicorn. If you added a Python package:

```bash
pip install <package>
echo "<package>" >> requirements.txt
```

---

## Deploy to Databricks

```bash
# 1. Build React (always do this before deploying)
node build.js

# 2. Sync source files to workspace
#    IMPORTANT: exclude client/ and node_modules/ — these are local-only build tools
databricks sync . /Workspace/Users/zhabib@joinhomebase.com/mshr-dash \
  --exclude .git \
  --exclude __pycache__ \
  --exclude client \
  --exclude node_modules

# 3. Deploy the app
databricks apps deploy mshr-dash \
  --source-code-path /Workspace/Users/zhabib@joinhomebase.com/mshr-dash

# 4. Check deployment status
databricks apps get mshr-dash
# Look for: "state": "SUCCEEDED"  and  "state": "RUNNING"
```

After deploying, **always hard-refresh the browser** (Cmd+Shift+R / Ctrl+Shift+R). The Databricks App proxy caches the previous JS bundle and regular refresh (`F5`) will serve the old version.

---

## What gets deployed vs. what stays local

| Path | Deployed? | Reason |
|---|---|---|
| `app.py` | Yes | FastAPI entry point |
| `queries.py` | Yes | Data layer |
| `app.yaml` | Yes | Runtime config + warehouse permission |
| `requirements.txt` | Yes | Python deps |
| `static/` | Yes | Built React SPA |
| `reference/` | Yes | Notebook reference (passive — not executed) |
| `client/` | **No** | Source files only — esbuild output goes to `static/` |
| `node_modules/` | **No** | Build tools only |
| `package.json` | **No** | Local build config |
| `build.js` | No | Local build script |
| `.git/` | **No** | Never sync git state |

---

## app.yaml — critical fields

```yaml
command:
  - uvicorn
  - app:app
  - --host
  - 0.0.0.0
  - --port
  - "8000"         # Must be 8000 — Databricks Apps expects this port
resources:
  - name: mshr-warehouse
    description: SQL warehouse for MSHR queries
    sql_warehouse:
      id: "16984dfe9a2c3705"
      permission: "CAN_USE"    # Grants the app's service principal warehouse access
```

If the `resources` block is missing, the service principal will not have access to execute SQL against the warehouse. This causes silent 500 errors on all `/api/*` endpoints.

---

## Verifying a deployment

```bash
# 1. Check app status
databricks apps get mshr-dash | jq '.app_status,.active_deployment.status'

# 2. Check the /health endpoint
curl https://mshr-dash-373323366197249.aws.databricksapps.com/api/health
# Returns: {"status":"ok","cached":["labor"]}   ← keys that are warm

# 3. Load the dashboard
# Open https://mshr-dash-373323366197249.aws.databricksapps.com
# You should see:
# - Immediate page render with 3 loading spinners
# - Each section filling in as its query completes
# - "Main Street Health Report — [Month Year]" in the header
```

---

## Query cost notes

- **Labor query**: scans `corona.shift_and_timecard_events` from 2024-01-01 with benchmark join. ~30–90s on a warm MEDIUM warehouse.
- **Wages query**: scans the same table from 2022-01-01 with payroll cohort joins. ~2–8 min cold.
- **Jobs query**: two queries against `postgres.jobs` (PostgreSQL external table over JDBC). ~1–3 min.
- All three run in the background thread on startup — no user request waits on them.
- 1-hour cache means the heavy queries run at most once per hour.

---

## Adding a new metric

1. Write the SQL in `queries.py` following the inline-CTE pattern (no temp views)
2. Add a `get_<metric>()` function with the slow cache TTL
3. Add it to the `_warm()` function in `app.py`
4. Add a `/api/<metric>` endpoint in `app.py` using the same `_safe_get` pattern
5. Add `fetch<Metric>()` in `client/src/api.js`
6. Add state slot in `App` component and include in `Promise.allSettled`
7. Add a new chart component or extend an existing one
8. Pass the data to the new component from `main.jsx`
