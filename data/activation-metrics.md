# Activation & Lifecycle Metrics

| Metric | Definition |
|--------|------------|
| **1D1** | Company/location with activity (new user invites employee + employee logs in) within first 24 hours of signup |
| **2D7** | Company/location active on 2 different days within a continuous 7-day window, with at least one employee activity each day |
| **2D30** | Same as 2D7 but within a 30-day window |
| **Activated** | Location that first published a schedule OR created a timecard |

### Lifecycle Metric Columns

| Column | Table | Description |
|--------|-------|-------------|
| `signup_1d1` | `public.companies` | `true` if 1D1 active at signup |
| `signup_2d7` | `public.companies` | `true` if 2D7 active from signup |
| `signup_2d30` | `public.companies` | `true` if 2D30 active from signup |
| `twod7_active_today_location` | `dbt.active_paying_history_for_looker` | `true` if 2D7 active on snapshot day |
| `two_d_thirty_active_this_month_location` | `dbt.active_paying_history_for_looker` | `true` if 2D30 active on snapshot day |
