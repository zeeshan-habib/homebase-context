# Cash Out — Funnel & User Lifecycle

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

## Enrollment Flow

| Step | Screen | Event Category | Key Properties |
|------|--------|---------------|----------------|
| 0a | Offer Intro (offer recipients) | `cash_out_onboarding_intro` | product_area: `mobile_app_sign_up` |
| 0b | Dashboard earnings card | `earnings_card` | product_area: `dashboard_v2`, button_text: `set up cash out` |
| 0c | Money Tab | `earnings_tab_6.3.1` | product_area: `cash_out_earnings_screen` |
| 1 | CO Intro (all users) | `cash_out_enrollment_details` | product_area: `cash_out_enrollment`, button_text: `Set up now` |
| 2a | Bank Consolidation (Plaid returning) | `select_available_bank` | product_area: `cash_out_enrollment` |
| 2b | Plaid Linking Intro (new Plaid) | `plaid_intro` | product_area: `Cash Out - Plaid` |
| 2c | Plaid Phone Screen | `submit_phone` | product_area: `cash_out_plaid` |
| 3 | Select Institution | `select_institution` | product_area: `cash_out_plaid`. **`Handoff` event = Plaid flow completed** |
| 4 | PII Screen | `confirm_signup_details` | product_area: `cash_out_enrollment`. *Some users bypass this screen* |
| 5 | Add Debit Card | `add_debit_card` | product_area: `cash_out_enrollment` |
| 6 | Confirm Payday (non-HB payroll) | `confirm_payday` | product_area: `cash_out_enrollment` |
| 7 | Customize Experience | `alert_settings` | product_area: `cash_out_enrollment`, button_text: `Finish Setup` |
| 8 | Signup Success | `success_confirmation` | product_area: `mobile_app_sign_up` |

Bank Account Selection screen (formerly between steps 3–4, `enrollment_1.5`) removed 2/23/26 via Hide Account Selection experiment (100% rollout).

### Enrollment Entry Points

| Channel | Event Category | % of Enrollments |
|---------|---------------|-----------------|
| Dashboard card | `advance_card` | ~65% |
| Cash Out Tab | `earnings_tab_6.3.1` | ~20% |
| Clock Out screen | `clock_out_4.3_enroll` | ~10% |
| Marketing comms | — | ~5% |

### Plaid Branching

- **Returning users** (previously connected via HB): Bank Consolidation screen → confirm existing or add new. Higher Plaid completion rates.
- **New users**: Full flow: Intro → Phone verification → Select Institution → Authenticate → Handoff.
- [Plaid branching spreadsheet](https://docs.google.com/spreadsheets/d/1HupqimGZ2pOs3a2i7qD5A_WZReGnLiLeYpUltaEZjgo/edit?gid=0#gid=0)

### Debit Card Verification

- BIN verified via Neutrino (matches institution, is debit card) — takes seconds
- If that fails: $0.02 transaction sent for confirmation — takes ~30 min

## KYC

### Plaid Decisioning

We do **not** use Plaid's `kyc_status`. We only check:

| Output | Required Value |
|--------|---------------|
| `risk_status` | `"success"` |
| `watchlist_screening_status` | `"cleared"` |

Everything else (including identity match result) is stored but **not used for decisioning**.

### Risk Rules (Plaid template `flwtmp_7RocfufAELQpSQ`)

AND chain — all must pass:

| Risk Sub-Check | Max Acceptable |
|---------------|---------------|
| Phone / Email / Network / Device / Behavior / Synthetic Identity / Stolen Identity Risk | Medium |
| Facial Duplicate Risk | High |

### KYC Field Requirements

- Plaid API minimum: `first_name`, `last_name`, `country_code`
- Our code hard-requires: `email`, `phone`, `DOB`, `address`
- **Resolved (Mar 2026):** Plaid confirmed email/phone can be safely omitted (sub-checks simply not scored)
- DOB and address still required (legal/regulatory)
- [EE-2756](https://joinhomebase.atlassian.net/browse/EE-2756) — KYC simplification | [EE-2823](https://joinhomebase.atlassian.net/browse/EE-2823) — Relax email/phone guards

### Watchlist Monitoring

Plaid monitors watchlist screening continuously without re-running identity verification. Safe to stop re-verifying on profile updates.

### Known KYC Issues (Mar 2026)

| Issue | Details |
|-------|---------|
| Missing IDV records | ~124K users enrolled with no IDV. 65.3K submitted (48K unique). Largest: D1/archived (39%), D4 (22%), A1 (15%), D6 (12%) |
| Missing PII fields | 53.5K couldn't submit KYC. 11,891 enrolled users missing ≥1 field (Sep 2025–Feb 2026). Most common: email (50%), city (36%), address (35%), DOB (25%). D6+D4 = 96% of population |

Zero overlap between the two populations. Data: [KYC re-verification sheet](https://docs.google.com/spreadsheets/d/) (Jon Blackwell)

## Communications Cadence

### Unenrolled Users

| Timing | Channel | Trigger / Event | Frequency Cap |
|--------|---------|----------------|---------------|
| First 14 days | Push | Day 1 & day 7 | Max 2 ever |
| First 14 days | Pop-up (`info_screen`) | >$25 available, A1 state | 1x ever |
| First 14 days | Dashboard card (`advance_card`) | Always present | "X" hides 7 days |
| First 14 days | Email drip | Day 1 clock-out & +7 days | Max 2 ever, excludes owners |
| Anytime | Push (`push_a1`) | Clock out | 1x / 7 days |
| Anytime | Clock out screen (`clock_out_4.3_enroll`) | A1, >$25 available | 1x / 21 days |
| Anytime | Push (drop-off) | 24 hrs after pre-Plaid or post-Plaid drop-off | Max 2 ever |
| Anytime | Email (Iterable, drop-off) | 1 day after drop-off | Max 1 ever, 14-day cooldown |
| After 14 days | Email/push (Iterable) | Drip | 1x / 6 months, ≥60 days after EE creation, 14-day cooldown |

### Enrolled Users

| Channel | Trigger / Event | Frequency Cap |
|---------|----------------|---------------|
| Dashboard card (`enrollment_card`) | B/B2 state | Always |
| Push (`push_b`) | Clock out | 1x / 2 days |
| Clock out screen (`clock_out_4.3_cash_out`) | Clock out | 1x / 21 days |
| Email (Plaid relink) | Plaid disconnected | Max 3 / 30 days (immediately, +3d, +3d) |
| Push (Plaid relink) | Plaid disconnected | Every 7 days, max 2 / 30 days |
| Email/push (1st CO, Iterable) | 24 hrs after enrollment if no CO | 2nd at +14 days |

### Transactional Messages (enrolled)

| Message | Trigger |
|---------|---------|
| CO initiated / Auto CO initiated | Cash Out created |
| Enrollment success | Enrollment complete |
| Overdraft / Low balance alert | Opted in, <$100 balance |
| Upcoming payment | 24 hrs before payback day |
| Repayment reminder | Payback fails, 5pm local, max 3 |
| Defaulted payback | Day 1, 3, 7 after due date |
| Debit card expired / verification / error | Card issue detected |

### Employer Communications

- Drip campaign mentioning CO (employee happiness & onboarding)
- Web app: Cash Out info under `Team` tab ([link](https://app.joinhomebase.com/cash_out))
- Marketing: [joinhomebase.com/employee-pay-advances](https://joinhomebase.com/employee-pay-advances/)

Source docs: [UX events & Jira](https://docs.google.com/spreadsheets/d/1KTQlrAPCJEppR4fDMLw97CpalU_nlY3RNdBC4rekOcw/edit) | [Engagement data](https://docs.google.com/spreadsheets/d/1x2iFfxaVmRAMUudyyu_xrSpkKFsfwITKqM8jNUTUNdE/edit)

## Activation

- First-time activation rate: ~42% (first CO within period after enrollment)
- Instant advance rate: ~96%
- Avg COs per user: ~5.2/month
- Mobile engagement rate among eligible base: ~69%

## Retention (cohorted by first CO month)

### Metric Definitions

| Metric | Definition |
|--------|-----------|
| CO Retention | % taking a CO X months after first CO |
| Active User Retention | % still MAU X months after first CO |
| Eligible User Retention | % of active users still eligible |
| % Active & Eligible with a CO | % of MAU+eligible users actually cashing out |

### Typical Curves

| Metric | M1 | M3 | M5 | M6 |
|--------|-----|-----|-----|-----|
| CO Retention | ~50% | ~20% | ~15% | ~12% |
| Active User Retention | ~100% | ~80% | ~70% | ~55% |
| Eligible User Retention | ~70% | ~65% | ~59% | — |
| % Active+Eligible with CO | ~75% | ~65% | ~55% | ~44% |

Users stay active and eligible but stop using CO. The drop-off is behavioral, not structural.

### CO Retention by Bank

| Bank | M1 | M3 | M5 | M6 |
|------|-----|-----|-----|-----|
| Chase | ~55% | ~34% | ~29% | ~17% |
| Wells Fargo | ~53% | ~32% | ~25% | ~15% |
| Bank of America | ~53% | ~30% | ~21% | ~13% |
| PNC | ~56% | ~26% | ~20% | ~14% |
| Current | ~55% | ~30% | ~15% | ~6% |
| Chime | ~44% | ~18% | ~12% | ~6% |

Chime M6 retention ~3x worse than Chase.

### CO Retention by Tenure at Enrollment

| Tenure | M1 | M3 | M5 | M6 |
|--------|-----|-----|-----|-----|
| First week | 45.6% | 15.9% | 5.5% | 1.8% |
| D15–D30 | 49.4% | 19.9% | 7.9% | 2.9% |
| D31–D60 | 49.4% | 20.5% | 6.7% | 2.4% |
| D61–D90 | 54.6% | 22.5% | 7.9% | 3.0% |
| D91–D180 | 53.6% | 23.6% | 8.6% | 2.7% |
| D181+ | 53.3% | 23.2% | 8.8% | 2.9% |
| Year+ | 52.3% | 21.8% | 7.7% | 3.3% |

First-week enrollees retain worst. Longer tenure modestly better but converges by M6.

### Other Retention Cuts

| Dimension | Notable |
|-----------|---------|
| Geography | Fairly flat; Far West slightly better (M2: 33.3%), Southeast slightly worse (M2: 27.0%) |
| Business Type | Retail (50.7% M1), Medical (53.3% M1) slightly better; Transportation, Hospitality slightly worse |
| Billing Source | Shopify (M2: 32.1%, M3: 25.6%) and Clover (M2: 30.1%, M3: 19.8%) retain better than HB direct (M2: 29.2%, M3: 18.5%) |

### Test User IDs

- Payroll Customer: `2297785` (live session) / `2297780`
- Non-payroll Customer: TBD
