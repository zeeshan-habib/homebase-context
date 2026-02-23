# Analytics Environment

Overview of Homebase's analytics environment. Use this to determine where to query data and which layer to use.

---

## 1. SQL Environment

- Default: all queries are written in **Databricks SQL**
- Use Databricks dialect (not standard PostgreSQL syntax where they differ)
- **Exception:** use Redshift SQL dialect only if the user explicitly specifies it

---

## 2. Data Layer Architecture

| Layer | Datasets | When to use |
|---|---|---|
| **Semantic (use first)** | `bizops.*`, `public.*` (and others TBD) | Business logic is baked in; use for all standard metrics and definitions |
| **Raw (use only if needed)** | `postgres.*`, `ext_amplitude.*` | Source system tables; only go here if semantic layer doesn't have what's needed |

Priority order: **semantic layer → raw layer**. Never query raw tables if a semantic equivalent exists.

---

## 3. Behavioral Data — Amplitude Routing

- Questions about **user actions, clicks, feature usage, in-product flows** → data source is Amplitude
- Reference table: `ext_amplitude.amplitude_events`
- For all other questions (business metrics, location/company status, revenue, payroll, active definitions) → use Databricks semantic layer
- Note: Amplitude data is also accessible via the Amplitude MCP if building charts directly
