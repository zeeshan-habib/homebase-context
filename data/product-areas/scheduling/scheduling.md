# Scheduling Specific Context

**When to use this file:** Questions about shifts, schedules, open shifts, publishing schedules, shift edits, or shift trades.

**Context Source:** Looker `shifts` explore, dbt models `s_dim_shifts` and `p_scheduling_usage_metrics`.

---

## Key Metrics

| Metric | Column / Source | Description |
|--------|----------------|-------------|
| Scheduled Shifts (7d) | `scheduling_count_lastd7` from `bizops.product_scheduling_usage_metrics` | Count of published shifts in the last 7 days |
| % Roster Scheduled | `percent_roster_w_sched_shift` from `bizops.product_scheduling_usage_metrics` | Percentage of active roster with at least one scheduled shift |
| Relevant Edits per Shift | Looker `shift_events` | Average meaningful edits per shift, excluding publish, timecard ops, auto-rounding, and sync events |

## Time Tracking Feature Engagement Definitions

#### Scheduling Engaged
**Measures:** Active use of shift scheduling.
**Lookback:** 7 days
**Threshold:** 3+ scheduled shifts OR 20%+ of roster with a scheduled shift
**Requirement:** At least one shift must belong to an Employee.
**Context:** One of two "core" engagement features. Critical for workforce planning and communication.

| `scheduling_engaged_boolean` | `scheduling_engaged_boolean_30d_ago` |
|---|---|

#### Shift Trades Engaged
**Measures:** Use of shift swap/trade functionality between employees.
**Lookback:** 7 days
**Threshold:** 2+ shift trades OR 10%+ of roster with a shift trade
**Context:** Lower threshold — shift trades are situational. Indicates employee self-service adoption.

| `shift_trades_engaged_boolean` | `shift_trades_engaged_boolean_30d_ago` |

|---|---|


#### Shift Notes Engaged
**Measures:** Use of shift-level notes and instructions.
**Lookback:** 7 days
**Requirements (ALL):**
- At least one shift note attached to a shift scheduled in the last 7 days
- Scheduling engaged
**Context:** Indicates scheduling is used for more than just time assignment.

| `shift_notes_engaged_boolean` | `shift_notes_engaged_boolean_30d_ago` |
|---|---|

---

## Key Tables

| Table | Schema | Grain | Purpose |
|-------|--------|-------|---------|
| `shifts` | `postgres` | per shift | Raw shifts, all statuses including drafts and deleted |
| `product_scheduling_usage_metrics` | `bizops` | location + date | Pre-aggregated scheduling metrics, published shifts only, 7d rolling window |
| `publish_schedule_events` | `firehose` | per publish event | When and how schedules were published (web, mobile, etc.) |
| `shift_change_events` | `firehose` | per edit event | Edit stream for shifts (available from 2024-04-01 onward only) |
| `shift_notes` | `postgres` | per note | Notes attached to shifts |
| `trades` | `postgres` | per trade | Shift swap/trade requests between employees |

---

## Key Business Logic & Caveats

- **`owner_type`:** `'Job'` = shift assigned to a specific employee; `'Location'` = open/unassigned shift available for pickup.
- **`publish_status`:** `'not_changed'` = published as-is; `'was_changed'` = published then later updated; `'changed_version'` = still a draft (not yet published).
- **`unscheduled` flag:** When `unscheduled = true`, the shift was auto-created by a clock-in with no matching schedule. Exclude these from scheduling analysis.
- **Timezone:** Shifts are stored in UTC. Convert to local time using `postgres.locations.time_zone` joined on `location_id`.
- **`scheduled_hours`:** Computed as `(end_at - start_at) / 3600`. This value is calculated, not stored as a column.
- **"Relevant edit"** in `shift_change_events`: Excludes publish events, timecard operations, auto-rounding, archiving, timezone adjustments, and sync events. Only counts direct user edits.
- **"Meaningful change"** in shift versions: A version counts as a real change only if `start_at`, `end_at`, `role_id`, or `owner_id` was modified.
- **`shift_notes` placeholder:** Notes where `text = '.'` are system-generated placeholders. Exclude them from analysis.
- **`shift_change_events` data availability:** This table starts on 2024-04-01. There is no shift edit event data before that date.

---

## Location Properties & Settings for Segmentation and Filtering

| Table | Schema | Description |
|-------|--------|-------------|
| `locations` | `public` | Location attributes and properties | Join on `location_id` |
| `companies` | `public` | Company attributes and properties | Join on `company_id` |
| `location_properties` | `postgres` | Location settings and preferences | Join on `location_id` |

---

## Example SQL Queries

### Published shifts per location per week
```sql
SELECT
    l.location_id,
    DATE_TRUNC('week', s.start_at) AS week,
    COUNT(DISTINCT s.id) AS published_shifts
FROM postgres.shifts s
JOIN postgres.jobs j ON s.job_id = j.id
JOIN public.locations l ON j.location_id = l.location_id
WHERE s.publish_status IN ('not_changed', 'was_changed')
  AND s.unscheduled = false
GROUP BY 1, 2
ORDER BY 1, 2;
```

### Open shifts vs assigned shifts
```sql
SELECT
    DATE_TRUNC('week', s.start_at) AS week,
    COUNT(DISTINCT CASE WHEN s.owner_type = 'Job' THEN s.id END) AS assigned_shifts,
    COUNT(DISTINCT CASE WHEN s.owner_type = 'Location' THEN s.id END) AS open_shifts
FROM postgres.shifts s
WHERE s.publish_status IN ('not_changed', 'was_changed')
  AND s.unscheduled = false
GROUP BY 1
ORDER BY 1;
```

### Schedule publish frequency by platform
```sql
SELECT
    DATE_TRUNC('week', pse.created_at) AS week,
    pse.platform,
    COUNT(*) AS publish_events
FROM firehose.publish_schedule_events pse
GROUP BY 1, 2
ORDER BY 1, 2;
```

### Scheduling metrics from pre-aggregated table
```sql
SELECT
    date,
    location_id,
    scheduling_count_lastd7,
    percent_roster_w_sched_shift
FROM bizops.product_scheduling_usage_metrics
WHERE date = CURRENT_DATE - 1
ORDER BY scheduling_count_lastd7 DESC;
```