# Cash Out — Customers & Segments

## User States

| State | Description |
|-------|-------------|
| **A1** | Company and user eligible to enroll (not enrolled) |
| **B / B2** | Enrolled, able to Cash Out (B2 = has owed Cash Out) |
| **A3** | $0 available, no upcoming payback due |
| **C2** | $0 available, yes upcoming payback due |
| **D1 / D2** | Cash Out unavailable (company/fraud block). D2 = has CO history |
| **D4** | Bank ineligible |
| **D5** | Past due payback |
| **D6** | Connected bank but hasn't finished setup (KYC, debit card) |
| **D7** | Bank on block list |
| **D8** | User's risk score exceeds thresholds |
| **D9** | Access delayed — high risk, no 1st CO limit score assigned |

## CO User Segments (used in WBR tracking)

| Segment | Code | Description |
|---------|------|-------------|
| Chime New | 1.1 | First-time CO user, Chime bank |
| Neo New | 1.2 | First-time CO user, non-Chime neobank |
| Non-Neo New | 1.3 | First-time CO user, traditional bank |
| Chime Returning | 2.1 | Returning CO user, Chime |
| Neo Returning | 2.2 | Returning CO user, non-Chime neobank |
| Non-Neo Returning | 2.3 | Returning CO user, traditional bank |
| New Continued Access | 3.1 | ConAccess — first CO from continued access |
| Returning Continued Access | 3.2 | ConAccess — returning CO user |
| Reactive Dormant | 4.1 | Previously dormant, reactivated |
| New True Dormant | 4.2 | First-time CO from dormant segment |
| Returning True Dormant | 4.3 | Returning CO from dormant segment |

### Continued Access vs Dormant

| Segment | Definition | User State |
|---------|-----------|------------|
| Continued Access | User has been **archived** by employer (e.g., terminated/removed) | Still B/B2 |
| Dormant | User is **not archived** but hasn't worked a shift recently | Still B/B2 |

Both require $100 minimum payback (all time) and no outstanding CO balances. Draw limits follow high-risk returning user logic (risk model score is recalculated).

## Not Enrolled — Eligible (LCM Phase 1 Segment)

~1.12M users (75% of total, as of Feb 2026). Shift-active users who haven't enrolled but could.

**Definition:** All of the following must be true:
- Had a shift in last 15 days (`postgres.shifts`, `postgres.jobs.level` in Manager/Employee)
- No enrollment record in `postgres.shift_pay_eligibilities`
- Company has not disabled CO (`public.cashout_rollout_dates.turn_off_time IS NULL`)
- Location not blocked (not in NV, WI, CT, ME, UT, DC, IN, or outside USA via `public.locations.state_cleaned`)

**Pre-enrollment exclusion:** Watchlist rejected (`postgres.kyc_watchlist_screenings.status = 'rejected'`) — ~35 users. Only pre-enrollment risk signal available; all other checks (fraud, KYC, Plaid, bank eligibility) occur during enrollment.

**Enrollment drop-offs:** ~8K users (0.7%) fired `enrollment_started` but have no record in `shift_pay_eligibilities` — they started enrollment but dropped off before reaching the Plaid flow.
- Data source: `ext_homebase1_public.payments_one_time_events` where `event = 'enrollment_started'`, joined to `postgres.accounts` on `user_id = uuid`
