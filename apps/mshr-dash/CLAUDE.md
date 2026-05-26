# mshr-dash — Databricks App

## Architecture

```
mshr-dash/
├── app.py              # FastAPI application entry point
├── app.yaml            # Databricks Apps runtime config
├── requirements.txt    # Python dependencies
├── static/             # Static assets served at /
│   ├── index.html      # Copied from client/index.html by build script
│   └── dist/
│       └── main.js     # Bundled by esbuild from client/src/main.jsx
└── client/             # React frontend source (add when needed)
    ├── index.html
    └── src/
        └── main.jsx
```

### How the app works

FastAPI serves two layers using the mount pattern — **order is critical**:

```python
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

app = FastAPI()
api_app = FastAPI()

# API routes go on api_app, e.g.:
# @api_app.get("/health")

app.mount("/api", api_app)                                    # Must come FIRST
app.mount("/", StaticFiles(directory="static", html=True))   # Must come LAST
```

- `/api/*` → FastAPI JSON endpoints
- `/*` → Static files (React SPA)
- Port **8000** is required — Databricks Apps expects it.

### Build commands

```bash
# Install Python deps locally for testing
pip install -r requirements.txt

# Run locally
uvicorn app:app --host 0.0.0.0 --port 8000 --reload
```

### Deployment commands

```bash
# 1. Sync source files to workspace
databricks sync . /Workspace/Users/zhabib@joinhomebase.com/mshr-dash \
  --exclude .git --exclude __pycache__

# 2. Deploy
databricks apps deploy mshr-dash \
  --source-code-path /Workspace/Users/zhabib@joinhomebase.com/mshr-dash

# Check status
databricks apps get mshr-dash
```

**App URL:** https://mshr-dash-373323366197249.aws.databricksapps.com

---

## Frontend Build (React, when added)

- esbuild bundles `client/src/main.jsx` → `static/dist/main.js`
- Build script copies `client/index.html` → `static/index.html`
- **ALL npm packages must be in `dependencies`, not `devDependencies`** — Databricks Apps installs only `dependencies` in production

```bash
# Build React frontend
node build.js

# Or with esbuild directly
npx esbuild client/src/main.jsx --bundle --outfile=static/dist/main.js --jsx=automatic
```

---

## Databricks SQL

```python
from databricks.sdk import WorkspaceClient
from databricks.sdk.service.sql import StatementState

w = WorkspaceClient()
DEFAULT_WAREHOUSE_ID = "16984dfe9a2c3705"

# wait_timeout must be "5s" to "50s" (inclusive)
result = w.statement_execution.execute_statement(
    warehouse_id=DEFAULT_WAREHOUSE_ID,
    statement="SELECT * FROM table LIMIT 10",
    wait_timeout="30s",
)
```

- `wait_timeout` must be between `"5s"` and `"50s"` — values outside this range error
- `DATE_SUB` requires `INTERVAL` keyword: `DATE_SUB(current_date(), INTERVAL 7 DAY)`
- Use in-memory cache with 5-minute TTL for repeated queries (avoid hammering the warehouse)

```python
import time

_cache: dict = {}
CACHE_TTL = 300  # 5 minutes

def cached_query(key: str, sql: str) -> list:
    if key in _cache and time.time() - _cache[key]["ts"] < CACHE_TTL:
        return _cache[key]["data"]
    rows = run_query(sql)
    _cache[key] = {"data": rows, "ts": time.time()}
    return rows
```

---

## Design System — DesignBase

**Font:** Plus Jakarta Sans (load from Google Fonts)

### CSS Variables

```css
:root {
  --surface-brand:           #7e3dd4;
  --surface-brand-secondary: #52258f;
  --surface-brand-heavy:     #1e0b3a;
  --surface-brand-light:     #f1ecff;
  --surface-primary:         #ffffff;
  --surface-secondary:       #f2f2ec;
  --text-default:            #1e0b3a;
  --text-secondary:          #605f56;
  --text-inverted:           #ffffff;
  --text-brand:              #7e3dd4;
  --border-default:          #e6e4d6;
  --border-focus:            #e55ccd;
  --surface-negative:        #d72505;
  --surface-success:         #028810;
  --surface-warning:         #eb7f00;
  --surface-informational:   #0177b0;
}
```

### Components

**Cards**
```css
.card {
  background: var(--surface-primary);
  border: 1px solid var(--border-default);
  border-radius: 8px;
}
```

**Buttons**
```css
.btn {
  background: var(--surface-brand);
  border-radius: 8px;
  font-weight: 600;
  color: var(--text-inverted);
}
```

**Inputs**
```css
input {
  border-radius: 4px;
  border: 1px solid var(--border-default);
}
input:focus {
  border-color: var(--border-focus);
  outline: none;
}
```

**Icons:** Heroicons v2 (`@heroicons/react`)

---

## Animation

**Library:** Motion (`motion/react`) — always respect `prefers-reduced-motion`.

| Effect | Duration | Easing |
|--------|----------|--------|
| Fade in | 0.3s | ease-out |
| Slide | 0.4s | ease-out |
| Stagger (list items) | 0.05s between items | — |
| Hover | 0.15s | ease |

```jsx
import { motion } from "motion/react";

const item = {
  hidden: { opacity: 0, y: 8 },
  show:   { opacity: 1, y: 0, transition: { duration: 0.3, ease: "easeOut" } },
};

// Respect reduced motion
const prefersReduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
```
