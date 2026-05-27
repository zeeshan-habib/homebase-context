<!-- Load behaviour: read this file first. Ask the user what they need before loading any other file. -->

# mshr-dash — Session Guide

**Don't load all docs upfront.** Ask the user what they're trying to do, then load only the file that matches:

| User intent | File to load |
|---|---|
| "What is this?" / first time here | [README.md](README.md) |
| Changing app structure, adding endpoints, debugging API issues | [ARCHITECTURE.md](ARCHITECTURE.md) |
| Changing queries, adding metrics, understanding data sources | [DATA.md](DATA.md) |
| Building, running locally, deploying | [DEVELOPMENT.md](DEVELOPMENT.md) |
| Something broke — error diagnosis | [TROUBLESHOOTING.md](TROUBLESHOOTING.md) |

---

## Always-on context (no extra file needed)

### Critical rules

1. **Mount order in app.py is not negotiable**
   ```python
   app.mount("/api", api_app)                                  # FIRST
   app.mount("/", StaticFiles(directory="static", html=True))  # LAST
   ```

2. **Each execute_statement is an isolated session** — temp views from one `_run_sql()` call do not exist in the next. All CTEs must be inlined. Use `_month_end_cte()` and `_consideration_and_location_ctes()` helpers.

3. **requirements.txt must include `arrow`** — `queries.py` uses `import arrow`. Missing it causes every endpoint to 500 on import.

4. **Never sync `client/` or `node_modules/` to Databricks** — built output only goes in `static/dist/main.js`.

5. **Always build before deploying** — `node build.js` bundles `client/src/main.jsx` → `static/dist/main.js`.

6. **Hard-refresh after every deploy** — Cmd+Shift+R (Mac). The proxy caches main.js aggressively.

7. **Wage baseline is dynamic — never hardcode it** — Jan 2022 national wage rate changes with retroactive payroll updates. Derived from query results every run.

8. **By-industry wages use `locations.business_type` (legacy column)** — matches the reference notebook. Do not change to `business_type_new`.

### Warehouse and app identity

| Item | Value |
|---|---|
| Workspace | homebase-staging.cloud.databricks.com |
| SQL warehouse ID | 16984dfe9a2c3705 |
| App name | mshr-dash |
| App URL | https://mshr-dash-373323366197249.aws.databricksapps.com |
| Service principal | app-4iecla mshr-dash (ID 282a3890-93b5-486c-af21-cee9f418f721) |

### Deploy one-liner

```bash
node build.js && \
databricks sync . /Workspace/Users/zhabib@joinhomebase.com/mshr-dash \
  --exclude .git --exclude __pycache__ --exclude client --exclude node_modules && \
databricks apps deploy mshr-dash \
  --source-code-path /Workspace/Users/zhabib@joinhomebase.com/mshr-dash && \
databricks apps get mshr-dash
# Then: Cmd+Shift+R in browser
```

### Design tokens (DesignBase)

**Font:** Plus Jakarta Sans (Google Fonts)

```css
--surface-brand:       #7e3dd4
--surface-brand-heavy: #1e0b3a
--surface-secondary:   #f2f2ec
--border-default:      #e6e4d6
--text-default:        #1e0b3a
--text-secondary:      #605f56
--text-inverted:       #ffffff
--surface-negative:    #d72505
--surface-success:     #028810
```
