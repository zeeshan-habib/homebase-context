# Time Tracking — Data Field Guide

Specific definitions, gotchas, disambiguation, data boundaries, and pointers for time tracking data.
For metric definitions, see the cross-cutting files (`data/glossary.md`,
`engagement/engagement-metrics.md`). For product context, see `domains/time-tracking/`.



## Source of Truth

The primary Looker explore for time tracking is `timecard_metrics` in
`core_product.model.lkml` (`pioneerworks/looker` repo). Use this for field
descriptions and join relationships.

---

## Gotchas & Caveats

### Joins that trip people up

- **`bizops.timecards.location_id` is usually null.** Always join through
  `postgres.jobs` to get the location:
  `FROM bizops.timecards t LEFT JOIN postgres.jobs j ON t.job_id = j.id`
  → use `j.location_id`

- **ACO/ACI joins use `timecard_uuid`, not `timecard_id`.** The table
  `postgres.time_tracking_timecard_change_requests` joins to timecards on
  `timecard_uuid`: `cr.timecard_uuid = tc.timecard_uuid`


### Column Clarification

- **`manager_modified`** is the broadest edit flag — covers manager added,
  edited, or deleted. Use this for OKR tracking on manager time savings.

- **`is_late_clock_out`** uses a 10-minute threshold after scheduled shift end.

- **Unscheduled shifts** (`shift_unscheduled = true`) don't have a meaningful
  scheduled end time — late clock-out calculations break on these. Filter them
  out or handle separately.
  

### Clock-Out/In Method Priority

When multiple sources could claim a clock event, priority order is:

1. Manager actions (highest)
2. ACO / ACI
3. Normal employee actions
4. Auto / POS (lowest)

### ACO/ACI Handling

**Join key:** `time_tracking_timecard_change_requests` joins to `timecards` on `timecard_uuid` (not `timecard_id`). Use `cr.timecard_uuid = tc.timecard_uuid`.

**Filtering:**
```
postgres.time_tracking_timecard_change_requests.status = 'approved'
AND source = 'assisted_clock_out'  -- or 'assisted_clock_in'
```
A submitted but unresolved request does NOT count.

---

## Data Boundaries

| What | Start date | Notes |
|---|---|---|
| Engagement booleans | 2025-01-01 | Earlier data may be incomplete |
| ACO data | 2025-08-16 | Initial rollout; GA 2026-01-16 |
| ACI data | 2025-12-10 | Initial rollout; GA 2026-02-03 |

---

## Key Tables

| Table | What it's for | Join key |
|---|---|---|
| `prod_redshift_replica.bizops.timecards` | Core timecard data | `timecard_id` |
| `prod_redshift_replica.bizops.timecard_clockouts` | Clock-out details, method, manager edits | `timecard_id` |
| `prod_redshift_replica.bizops.timebreaks_parsed` | Break details with edit flags | `timecard_id` |
| `prod_redshift_replica.postgres.time_tracking_timecard_change_requests` | ACO/ACI requests | `timecard_uuid` |
| `prod_redshift_replica.public.locations` | Location attributes | `location_id` |
| `prod_redshift_replica.public.companies` | Company attributes | `company_id` |
| `prod_redshift_replica.postgres.location_properties` | Location settings | `location_id` |
| `prod_redshift_replica.postgres.timesheets_settings` | TT-specific settings | `location_id` |
| `prod_redshift_replica.bizops.product_location_engagement_metrics` | Engagement booleans | `location_id` |

---

## Disambiguation

| If you see... | Use this | Not this |
|---|---|---|
| Need `location_id` from timecards | Join `postgres.jobs` on `job_id` | `bizops.timecards.location_id` (usually null) |
| ACO/ACI join to timecards | `timecard_uuid` | `timecard_id` |
| "Active" in TT context | `time_tracking_engaged_boolean = 1` | `active_now`, `is_active`, `mau` |
| Manager edits | `manager_modified = 1` | Individual edit-type flags (unless you need the breakdown) |
