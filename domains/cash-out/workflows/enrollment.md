# Cash Out — Enrollment Flow

## Enrollment Steps

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

Bank Account Selection screen (formerly between steps 3-4, `enrollment_1.5`) removed 2/23/26 via Hide Account Selection experiment (100% rollout).

## Entry Points

| Channel | Event Category | % of Enrollments |
|---------|---------------|-----------------|
| Dashboard card | `advance_card` | ~65% |
| Cash Out Tab | `earnings_tab_6.3.1` | ~20% |
| Clock Out screen | `clock_out_4.3_enroll` | ~10% |
| Marketing comms | — | ~5% |

## Plaid Branching

- **Returning users** (previously connected via HB): Bank Consolidation screen -> confirm existing or add new. Higher Plaid completion rates.
- **New users**: Full flow: Intro -> Phone verification -> Select Institution -> Authenticate -> Handoff.
- [Plaid branching spreadsheet](https://docs.google.com/spreadsheets/d/1HupqimGZ2pOs3a2i7qD5A_WZReGnLiLeYpUltaEZjgo/edit?gid=0#gid=0)

## Debit Card Verification

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

### KYC Run Triggers

| Trigger | When | Frequency |
|---------|------|-----------|
| Enrollment | CO signup flow | Once per enrollment |
| KYC re-verification | Profile attribute update (email, phone, DOB, address, etc.) | Every update to KYC-relevant fields |

**Fix deployed (Mar 2026):** Logic to skip re-verification if the user already has a passing `risk_status` + `watchlist_screening_status` from their last run. Cost: $0.22/call ($0.137 IDV + $0.083 Anti-Fraud).

### Watchlist Monitoring

Plaid monitors watchlist screening continuously without re-running identity verification. Safe to stop re-verifying on profile updates.

### Known KYC Issues (Mar 2026)

| Issue | Details |
|-------|---------|
| Missing IDV records | ~124K users enrolled with no IDV. 65.3K submitted (48K unique). Largest: D1/archived (39%), D4 (22%), A1 (15%), D6 (12%) |
| Missing PII fields | 53.5K couldn't submit KYC. 11,891 enrolled users missing >=1 field (Sep 2025-Feb 2026). Most common: email (50%), city (36%), address (35%), DOB (25%). D6+D4 = 96% of population |

Zero overlap between the two populations.
