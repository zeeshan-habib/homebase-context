# Main Street Health Report — Live Dashboard

A live Databricks App that replaces the monthly MSHR PowerPoint pipeline. React SPA served by FastAPI, querying Databricks SQL for all 6 MSHR metrics on every page load.

**Live URL:** https://mshr-dash-373323366197249.aws.databricksapps.com  
**Workspace:** homebase-staging.cloud.databricks.com  
**App name:** `mshr-dash`

---

## What this is

The Main Street Health Report (MSHR) is Homebase's monthly view into small business employment conditions. It previously required an analyst to run a Python notebook, export to Excel/Looker, and assemble a PowerPoint. This app automates all of it into a self-refreshing dashboard.

**Six metrics tracked:**

| Metric | Source | Type |
|---|---|---|
| Employees Working | `corona.shift_and_timecard_events` + benchmark tables | % vs January baseline |
| Hours Worked | Same | % vs January baseline |
| Businesses Open | Same | % vs January baseline |
| Hourly Wages | `postgres.payroll_payroll_runs` + `corona.shift_and_timecard_events` (payroll cohort) | % above Jan 2022 |
| Jobs Added | `postgres.jobs` + qualifying locations | % vs January pace |
| Jobs Archived | `postgres.jobs` + `postgres.job_versions` | % vs January pace |

---

## Documentation index

| Doc | What it covers |
|---|---|
| [ARCHITECTURE.md](ARCHITECTURE.md) | System design, FastAPI pattern, background loading, cache strategy |
| [DATA.md](DATA.md) | All 6 metrics: tables, SQL logic, notebook cell mapping, date math |
| [DEVELOPMENT.md](DEVELOPMENT.md) | Local setup, build, deploy, Databricks CLI |
| [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | Every error encountered building this + root cause + fix |

---

## Quick start (returning developer)

```bash
# 1. Build React
node build.js

# 2. Sync to workspace
databricks sync . /Workspace/Users/zhabib@joinhomebase.com/mshr-dash \
  --exclude .git --exclude __pycache__ --exclude client --exclude node_modules

# 3. Deploy
databricks apps deploy mshr-dash \
  --source-code-path /Workspace/Users/zhabib@joinhomebase.com/mshr-dash

# 4. Verify
databricks apps get mshr-dash
```

After deploying, **hard-refresh the browser** (Cmd+Shift+R) — Databricks Apps caches the JS bundle aggressively.

---

## File map

```
mshr-dash/
├── app.py               FastAPI entry point + background query warm-up
├── queries.py           All SQL + Databricks SDK execution + cache layer
├── app.yaml             Databricks Apps runtime config (warehouse permission grant)
├── requirements.txt     fastapi, uvicorn, databricks-sdk, arrow
├── build.js             esbuild: bundles client/src → static/dist
├── package.json         Local-only build deps (NOT synced to Databricks)
├── static/
│   ├── index.html       Copied from client/index.html by build.js
│   └── dist/main.js     Bundled React app
├── client/
│   ├── index.html       HTML shell (DesignBase CSS vars, Plus Jakarta Sans)
│   └── src/
│       ├── main.jsx     Root: polling, SummarySection, KPISection, chart sections
│       ├── api.js       fetch wrappers for /api/* endpoints
│       └── components/
│           ├── KPICard.jsx      Value + MoM arrow + color
│           ├── LaborChart.jsx   3-year overlay, tabs, raw table
│           ├── WageChart.jsx    National % + by-industry, raw tables
│           └── HiringChart.jsx  Jobs added + archived panels, raw table
└── reference/
    └── PR_Standard_EOM_Metrics.ipynb   Canonical source for wage/hiring/turnover SQL
```

---

## Report cadence

- The anchor date is the **27th of the month**. If today is before the 27th, the report covers through the 27th of the previous month.
- Queries are date-bounded from 2022-01-01 (wages) or 2024-01-01 (labor, jobs) to reduce scan cost.
- Data cache TTL: 5 min for labor, 1 hr for wages and jobs.
- Queries auto-warm in a background thread on app startup — first page load renders immediately with per-section loading spinners.
