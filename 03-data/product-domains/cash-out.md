# Cash Out (CO) Knowledge Repository

## Overview
Central knowledge base for the Cash Out product at Homebase.

**Source:** [Cash Out Key Systems Non-Engineers](https://joinhomebase.atlassian.net/wiki/spaces/EE/pages/2029879340/Cash+Out+Key+Systems+Non-Engineers) (Confluence, last updated 2/25/2026)

---

## Table of Contents
1. [Product Overview](#product-overview)
2. [Access & Eligibility](#access--eligibility)
3. [KYC System](#kyc-system)
4. [Accrual](#accrual)
5. [Enrollment](#enrollment)
6. [Taking a Cash Out](#taking-a-cash-out)
7. [Paying Back a Cash Out](#paying-back-a-cash-out)
8. [User States](#user-states)
9. [Communication & Messaging](#communication--messaging)
10. [Integrations](#integrations)
11. [Dashboards & Analytics](#dashboards--analytics)
12. [Retention & Churn](#retention--churn)
13. [Enrollment Funnel Eventing](#enrollment-funnel-eventing)
14. [Financial Forecast Model](#financial-forecast-model)
15. [Active Projects](#active-projects)
16. [Key Links](#key-links)
17. [Changelog](#changelog)

---

## Product Overview

Cash Out is a Homebase service that allows users to take out a cash advance for the hours they've worked within their current pay period whenever they need it via the mobile application.

**Delivery methods:**
- **Standard (ACH):** Same-day delivery, free of charge
- **Instant (Debit / Plaid RTP):** Within an hour, $4.99 flat fee (waived if referral available)
  - RTP only available at supported financial institutions

---

## Access & Eligibility

Access depends on three key areas: company experiment enrollment, pre-enrollment user eligibility, and post-enrollment user eligibility.

### Pre-Enrollment User Eligibility (gates enrollment)
- `user_id` must not be in `ShiftPay::BlockedUser` table (updated for removal requests or fraud)
- **Fraud indicators:**
  - Bank account or debit card reused by another user
  - PII associated with government watchlists
  - Flagged manually by risk or security team
- **Plaid eligibility/risk rules:**
  - US valid account
  - 2 continuous paychecks
  - Minimum account activity
  - Minimum days of transactions
  - Low risk bank

### Post-Enrollment User Eligibility (gates use after enrolling)
- **User eligibility:**
  - Must have accrued enough hours in current pay period (defaults: 1 week, $10/hour)
- **Bank eligibility:**
  - US checking account
  - Activity at least 30 days old
  - At least 8 days with a transaction in the last 30 days (live 1/16/23)
  - At least two income transactions >= $150 in non-blacklisted categories in the last 60 days
  - **Transaction category blocklist:**
    - `[Transfer, ...]` — exclude all Transfer categories except:
      - `[Transfer, Payroll]`
      - `[Transfer, Payroll, Benefits]`
      - `[Transfer, Deposit, Check]`
      - `[Transfer, Deposit, ATM]`
    - `[Tax, ...]` — exclude all
    - `[Bank Fees, ...]` — exclude all
    - `[Service, Financial, Loans and Mortgages]`
    - `[Service, Business Services]`
    - `[Service, Financial, Taxes]`
    - `[Service, Financial]`
    - `[Service, Insurance]`
    - `[Service, Financial, Financial Planning and Investments]`
    - `[Service, Financial, Stock Brokers]`
    - `[Service]`
  - Not a blocked bank account ([admin link](https://app.joinhomebase.com/admin/bank_accounts_plaid_institutions?scope=blocked_banks))

---

## KYC System

**Source:** [Cash Out KYC Investigation v3](https://docs.google.com/document/d/1Lg07oIj5rickJj_plmNElHnCqCsvquBL/edit) (Jon Blackwell, March 2026 — still pending Plaid clarification on some items)

### What We Use from Plaid

Homebase does **not** use Plaid's `kyc_status` (identity verification pass/fail) in decisioning. We only rely on two outputs:

| Output | Required Value |
|--------|---------------|
| `risk_status` | Must equal `"success"` |
| `watchlist_screening_status` | Must equal `"cleared"` |

If either condition is not met, the user is not verified. Everything else (including the identity match result) is stored but **not used for decisioning**. Our code does not inspect individual risk sub-fields — only the top-level `risk_status`.

### How risk_status Is Determined

Determined by Plaid based on Risk Rules in our production template (`flwtmp_7RocfufAELQpSQ`). These rules are an **AND chain** — all must pass:

| Risk Sub-Check | Acceptable Threshold |
|---------------|---------------------|
| Phone Risk | Medium Risk |
| Email Risk | Medium Risk |
| Network Risk | Medium Risk |
| Device Risk | Medium Risk |
| Behavior Risk | Medium Risk |
| Synthetic Identity Risk | Medium Risk |
| Stolen Identity Risk | Medium Risk |
| Facial Duplicate Risk | High Risk |

If any sub-check exceeds its threshold, the overall `risk_status` will not be `"success"`.

### KYC Field Requirements

**Plaid's API** accepts identity verification requests with minimal fields (just `first_name`, `last_name`, `country_code`).

**Our code requires more:** The `VerifyIdentityWorker` and `IdentityVerificationRequest` classes currently hard-require `email`, `phone`, `DOB`, and `address` before sending to Plaid.

**Resolved (March 2026):** Plaid confirmed that when optional fields like email or phone are omitted, the corresponding risk sub-checks are simply **not scored** and won't cause the overall `risk_check.status` to fail. This means email and phone can be safely omitted from KYC submissions.
- **DOB and address are still required** — DOB for age verification (legal requirement), address for regulatory compliance.

**JIRA:** [EE-2756](https://joinhomebase.atlassian.net/browse/EE-2756) — KYC simplification investigation
**JIRA:** [EE-2823](https://joinhomebase.atlassian.net/browse/EE-2823) — Relax email/phone guards in `VerifyIdentityWorker` and `IdentityVerificationRequest`

### Watchlist Monitoring

Plaid confirmed that watchlist screening continues to be monitored **even without re-running identity verification**. Plaid uses the same underlying Monitor screening case per user, and it rescans automatically. This means we can safely stop re-verifying users on profile updates without losing watchlist coverage.

### Known KYC Issues (from March 2026 Investigation)

**Issue 1 — Users missing identity verification records:**
- ~124K users went through enrollment with no IDV on file
- 65.3K were successfully submitted for KYC (mapped to 48K unique users after dedup)
- Largest segments: D1/archived former employees (39%), D4/bank ineligible (22%), A1/eligible to enroll (15%), D6/no debit card (12%)

**Issue 2 — Users missing required PII fields:**
- 53.5K users couldn't have KYC submitted due to missing PII
- 11,891 enrolled users missing at least one field (Sep 2025 – Feb 2026)
- Most commonly missing: email (50%), city (36%), address (35%), state (35%), zip (33%), DOB (25%)
- D6 and D4 users account for 96% of missing fields population

**Zero overlap** between the two populations (confirmed by cross-referencing user IDs).

**Data:** [KYC re-verification data (updated)](https://docs.google.com/spreadsheets/d/) — see Jon's Google Sheet

---

## Accrual

### Key Concepts
- **Accrual rate** = net wage rate x hours worked in period x risk factor
  - **Net wage rate:** Estimated post-tax income from eligible Plaid income transactions / hours worked. Recalculated 1x/month.
  - **Risk factor:** Homebase-applied reduction — currently 50% of earnings available.
- **Accrual period:** The time window a user can access for a Cash Out.
- **Accrual balance:** Sum of (hours worked each day x accrual rate) for all days in the accrual period.
  - Includes 5 days prior to previous payday for full earned amount.
- **Minimum Cash Out:** $25
- **Max shift hours counted:** 16 hours per shift (anything over 16 is capped at 16).

### Accrual — Pay Any Day
Two user types:
1. **Banking users with payroll direct deposit:** Service `ShiftPay::Accrual::BankingWithPayroll::CalculateNetWageRate` calculates expected average hourly wage from latest payroll data.
2. **Banking users without payroll:** Service `ShiftPay::Accrual::BankingWithoutPayroll::CalculateNetWageRate` calculates accrual from income transactions in last 62 days (same counterparty routing number or PPD_SEC_CODE).

---

## Enrollment

### Access Points to Begin Flow
| Channel | Description | % of Enrollments |
|---------|-------------|-----------------|
| Dashboard card (`advance_card`) | CTA: "Get paid as soon as you clock out." Closing hides for 7 days. | ~65% |
| Cash Out Tab (`earnings_tab_6.3.1`) | Info about CO with "Get Started" CTA | ~20% |
| Clock Out screen (`clock_out_4.3_enroll`) | Slider bar to select earnings amount | ~10% |
| Marketing comms | Email/push notifications | ~5% |

### Enrollment Flow
1. How Cash Out works (education)
2. Enter/confirm personal info for KYC
3. Connect bank account with Plaid
   - Blocked if user selects a blocked bank
   - ~~Bank Account Selection screen~~ — removed 2/23/26 (Hide Account Selection experiment, 100% rollout)
4. Connect verified debit card
   - BIN verified via Neutrino (matches institution, is debit card) — takes seconds
   - If that fails: $0.02 transaction sent for confirmation — takes ~30 min
5. Select payday and frequency (confirmation screen if estimate available; user can edit)
6. Customize push notifications and features

---

## Taking a Cash Out

### Prerequisites
- Accrued more than minimum Cash Out amount with remaining accrual
- No past due Cash Out
- Have not reached full pay period limit

### Access Points
1. **Dashboard card** (`advance_card`): Shows max amount with +/- buttons
2. **Cash Out Tab:** Amount available, history, settings, repayment status
3. **Clock Out screen** (`clock_out_4.3`): Slider bar for earnings
4. **Marketing comms:** Email/push CTAs

### Flow
1. Select amount to Cash Out
2. Select delivery method:
   - Standard: Same Day ACH (free)
   - Instant: Within an hour ($4.99 fee; waived with referral)
3. Confirmation of amount, delivery method, payback date
4. Loading screen → success/failure

### Limits

**Transaction limits:** $100 for all users (per single Cash Out).

**Pay period limits (first-time users):**
- Determined by a data science model after enrollment
- First check: "very high-risk criteria" — if met, eligibility is delayed until a data science score is assigned
  - Criteria: High risk bank
- First Cash Out limits depend on model scores ([admin link](https://app.joinhomebase.com/admin/shift_pay_first_cash_out_scores))
- Bank-specific: Chime = $50 limit ([admin link](https://app.joinhomebase.com/admin/shift_pay_first_cash_out_bank_amount_thresholds))

**Pay period limits (returning users — low risk banks):**
Set dynamically by data science model with "likely to repay" tiers based on:
- Amount paid back successfully
- Average bank income
- Days negative
- Bank used

See limit tiers: [admin link](https://app.joinhomebase.com/admin/shift_pay_returning_limit_ranks?scope=version_two)

**Pay period limits (returning users — high risk banks):** (as of 1/12/24)
- \>$500 paid back in last 90 days → $125 limit ([SP-8668](https://joinhomebase.atlassian.net/browse/SP-8668))
- \>$250 paid back in last 90 days → $125 limit ([SP-8442](https://joinhomebase.atlassian.net/browse/SP-8442))
- Else → $50 limit

---

## Paying Back a Cash Out

**Further docs:**
- [Payback details](https://joinhomebase.atlassian.net/wiki/spaces/EE/pages/1835794433)
- [Cash Out Overview — Payback](https://joinhomebase.atlassian.net/wiki/spaces/EE/pages/177733633/Cash+Out+Overview#Payback)

### Setting Payback Date (by priority)
1. **Homebase Payroll data** — if active and provides a payday
2. **User manual entry** — 5-step flow, no monthly option. 90% completion rate.
3. **Pave ML model** — estimates income stream ([SP-6170](https://joinhomebase.atlassian.net/browse/SP-6170))
4. **First location pay period** — ~8% of users
5. **Internal Plaid-based model** — approximates pay frequency from income transactions. ~2% of users.

> Note: We skip signup payday if a payday estimate doesn't already exist so more users go to Pave (as of May 2023).

### Manual Payback
- Users with past due payback can attempt manual repayment with card on file or different debit card
- Runs on debit network regardless of balance
- Max 3 different cards per week

### Automatic Paybacks — Cash Out

| Worker | Days | Schedule | Conditions |
|--------|------|----------|------------|
| `EnqueueTodayPaybacksDebitWorker` | Day 1, 8, 15, 22, 29 (excl. Sunday) | Every 1 hr from 12am local | No debit error, no Plaid error |
| `EnqueuePastDuePaybacksDebitWorker` | Days 2-90 (excl. 8,15,22,29 & Sunday) | Every 30 min, 2-7am local | No debit error, no Plaid error |
| `CheckPaybacksDebitWithPlaidErrorWorker` | Days 1-90 (excl. Sunday) | 10am UTC | No debit error, YES Plaid error |
| `CheckPaybacksSameDayAchWorker` | Days 1-90, Mon-Fri | 4pm UTC | YES debit error, no Plaid error |
| `CheckPaybacksAchWorker` | Days 1-90, Mon-Thu | 9pm UTC | YES debit error, no Plaid error |
| `shift_pay_payback_methods` (Same Day ACH) | Days 1-30, Mon-Thu | 1x per 28 days, 2pm UTC | YES debit error, YES Plaid error |
| `CheckWebhookNewTransactionsWorker` | Days 1-360 | On webhook alert | Checks if income txn > outstanding + buffer, then attempts debit |

Partial paybacks of at least $25 allowed after day 1 via debit rails.

### Automatic Paybacks — Pay Any Day

1. **On credit received:** When user receives a credit to HB Money account, `ShiftPay::Payback::ProcessForBankingUserWorker` runs if due or past due.
2. **Daily cron:** `Scheduled::ShiftPay::Banking::EnqueueUsersForDueRepaymentWorker` — runs 1x/day at end of night for due and past due users.

---

## User States

| State | Description |
|-------|-------------|
| **A1** | Company and user eligible to enroll (not enrolled) |
| **D1** | Company not eligible, no user CO history (not enrolled) |
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

---

## Communication & Messaging

Full details on UX events, Jira tickets, and engagement data:
- [UX events & Jira tickets](https://docs.google.com/spreadsheets/d/1KTQlrAPCJEppR4fDMLw97CpalU_nlY3RNdBC4rekOcw/edit)
- [Engagement data](https://docs.google.com/spreadsheets/d/1x2iFfxaVmRAMUudyyu_xrSpkKFsfwITKqM8jNUTUNdE/edit)
- [Investigation doc](https://docs.google.com/document/d/1ytxhAHzG1zytTdI1A1nGJtOUxLm3JAUWIBy8_EoBHOk/edit)

### Unenrolled — First 14 Days
- **Push notifications** (day 1 & day 7): "Homebase gives you access to your earnings before payday." Max 2 ever.
- **Intro pop-up** (`info_screen`): Shown once when user has >$25 available and is in A1 state.
- **Dashboard card** (`advance_card`): Always present, high priority. Clicking "No"/"X" hides for 7 days.
- **Email drip** (day 1 clock-out & +7 days): Max 2 emails ever. Excludes owners.

### Unenrolled — Anytime
- **Clock out push** (`push_a1`): Max 1x every 7 days.
- **Clock out screen** (`clock_out_4.3_enroll`): 1x every 21 days, user in A1, >$25 available.
- **Drop-off push** (pre-Plaid & post-Plaid): 24 hrs after drop-off. Max 2 occurrences ever.
- **Drop-off email** (Iterable): 1 day after drop-off, max 1 ever, 14-day cooldown.

### Unenrolled — After 14 Days
- **Iterable email/push drip:** 1x every 6 months, at least 60 days after employee creation, 14-day cooldown.

### Enrolled
- **Dashboard card** (`enrollment_card`): Shown in B/B2 state.
- **Clock out push** (`push_b`): Max 1x every 2 days.
- **Clock out screen** (`clock_out_4.3_cash_out`): 1x every 21 days.
- **Plaid relink email:** Up to 3 emails per 30 days (immediately, +3 days, +3 days).
- **Plaid relink push:** Every 7 days, max 2 per 30 days.
- **1st Cash Out email/push** (Iterable): 24 hrs after enrollment if no CO, 2nd at +14 days.

### Transactional Messages (enrolled)
- Cash Out initiated / Auto Cash Out initiated
- Enrollment success
- Overdraft alerts / Low balance alert (if opted in, <$100 balance)
- Upcoming payment (24 hrs before payback day)
- Repayment reminder (5pm local if fails, max 3 reminders)
- Defaulted payback (day 1, 3, 7 after due date)
- Debit card expired / verification / error notifications

### Employer Communications
- Drip campaign mentioning CO (employee happiness & onboarding)
- Web app: Cash Out info under `Team` tab ([link](https://app.joinhomebase.com/cash_out))
- Marketing page: [joinhomebase.com/employee-pay-advances](https://joinhomebase.com/employee-pay-advances/)

---

## Integrations

| Partner | Purpose |
|---------|---------|
| **[Plaid](https://plaid.com/)** | Secure bank account connection via pre-built mobile UI |
| **[Synapse](https://synapsefi.com/)** | Sending/receiving funds between user bank account and Homebase account |

### Disabling Cash Out
Global kill switch available for critical P0 bugs when a quick fix isn't possible.

---

## Dashboards & Analytics

### Looker Dashboards (Source of Truth for Absolute Counts)

| Dashboard | Purpose | Link |
|-----------|---------|------|
| **Cash Out Core Output Metrics** | Comprehensive daily monitoring: Cashout Volume (hourly/daily w/w, running total delta, forecasted EOD), CO Users (hourly w/w, first-time daily w/w), Enrollments (hourly/daily w/w, eligibility pass rates by rule, enrollments by bank), Repayments (hourly/daily w/w, D1 repayment % by day), User States (daily w/w changes by state, state distribution), D7 Activation/Eligibility (weekly rates by bank, D1/D7 by enrollment week), Neobank % of Portfolio, Weekly Cashouts by User Bucket, True Dormant/Continued Access per week | [Looker #748](https://homebase.looker.com/dashboards/748) |
| **Non Repayments Dashboard** | Non-repayment rates/loss rates, non-repayment maturation (rates require at least 25% of cohort to be mature) | [Looker #970](https://homebase.looker.com/dashboards/970) |
| **CO Enrollment Funnel** | Enrollment funnel by entry point & platform: users starting enrollment (by mobile platform, by tenure bucket), completion rates by platform, offer-to-enroll conversion by entry point (All, Dashboard, Money Tab, More Options, Clock Out, Signup), enrolled users by entry point, dashboard click rate/completion rate (v1 & v2), 3-step funnel (Start→Plaid→Finish) by platform, overall funnel visualization, D7 activation by entry point, eligible base (new users created weekly, shift active weekly, Dash v2 CO card by rank) | [Looker #1171](https://homebase.looker.com/dashboards/1171) |
| **CO Key Input and Output Metrics** | CO business health summary pairing output metrics with input funnel drivers. **Output Metrics:** Revenue by advance month, CO users by advance month (with CO frequency), MAUs as % of CO TAM, non-repayment rate by days since advance (D1–D120 with FDIC/Dave benchmarks), D28 non-repayment rate by advance month (with YoY). **Input Metrics:** CO users MoM change (TAM vs MAU), enrollment completion rate (started→enrolled), eligibility + risk rules pass rate (enrolled→eligible), activation quality for all eligible users (% with ≥1 CO in 30 days), activation quality for new enrollments (% of recent enrollments who cashed out). Filterable by source (Plaid, Synapse, Checkout). | [Looker #1494](https://homebase.looker.com/dashboards/1494?Source=plaid%2Csynapse%2Ccheckout) |
| **Finserv Retention & Activation** | Cohorted retention metrics by first CO month. Includes: % of active & eligible users with a CO (M1–M6), active user retention (still MAU after first CO, M1–M11), CO retention (taking a CO X months after first, M1–M11), eligible user retention (% of active users still eligible, M0–M6). Also breaks out CO retention by bank (BofA, Chase, Wells Fargo, PNC, Current, Chime), user tenure at enrollment, geography, business type, and billing source. | [Looker #899](https://homebase.looker.com/dashboards/899?First+Cash+Out+Date+Month=6+month+ago+for+6+month) |

### Amplitude Dashboard (Directional Trends Only)

| Dashboard | Purpose | Link |
|-----------|---------|------|
| **Cash Out Enrollment Funnel Dashboard** | Step-by-step enrollment funnel with screen-level conversion | [Amplitude](https://app.amplitude.com/analytics/homebaseone/dashboard/mkdo3i8v) |

Owners: Janice Lee, Jon Blackwell. Contains 16 charts covering funnel steps, conversion rates, and breakdowns.

### Amplitude vs Looker: Key Caveats

> **Looker is the source of truth for absolute enrollment counts. Amplitude is better suited for relative trends and directional % changes.**

Key findings from investigation (Feb 2026, Janice + Kevin McDonough):

1. **Amplitude funnel logic is strict:** Requires users to complete *every step* in the defined funnel sequence. If a user skips a screen, an event misfires, or tracking fails at any step, they drop out entirely. Downstream steps get significantly undercounted.
   - Example: Full funnel shows ~4.3% conversion; simplified 2-step funnel (intro → success) shows ~11%, much closer to Looker.

2. **Looker funnel logic is snapshot-based:** Does not require users to have seen all prior screens in sequence. Takes a snapshot of users who reached a specific event within the date range. Better for complete/absolute counts.

3. **Amplitude sampling:** Amplitude samples a portion of user journeys. Combined with occasional misfiring or skipped UX events, this materially impacts funnel completion numbers.

4. **UX events break with front-end changes:** In late January 2026, Product Analytics re-instrumented events, breaking DBT models and Looker metrics. UX events are fragile and not suitable as the sole source of truth.

5. **Known data quirks:**
   - ~4.5K users/month skip PII screen after Bank Account Selection, landing directly on Add Debit Card ([Slack thread, 2/10/26](https://pioneerworks.slack.com/archives/C092VCS8GP6/p1770765892029319))
   - Amplitude sometimes doesn't record session events at all (reported by QA, 2/13/26)
   - Material decline in enrollment flow completion starting Feb 11 in Amplitude was likely an Amplitude issue, not a real decline — Looker showed flat enrollment rates ([Slack thread, 3/2/26](https://pioneerworks.slack.com/archives/C051KVARH7Y/p1772492943716639))

**Sources:** [Slack investigation thread (2/20/26)](https://pioneerworks.slack.com/archives/C0AG5RM0G8M/p1771621239431059) | [Slack summary (2/23/26)](https://pioneerworks.slack.com/archives/C0AG5RM0G8M/p1771864995688289)

---

## Retention & Churn

**Source:** [Finserv Retention & Activation Dashboard (Looker #899)](https://homebase.looker.com/dashboards/899?First+Cash+Out+Date+Month=6+month+ago+for+6+month) | Data as of March 2026 (cohorts: Sep 2025 – Jan 2026)

### Key Retention Metrics (Cohorted by First CO Month)

Four distinct retention views are tracked:

| Metric | Definition | Typical Curve |
|--------|-----------|---------------|
| **CO Retention** | % taking a cash out X months after first CO | ~50% M1 → ~15-20% M5 → ~12% M6 |
| **Active User Retention** | % still MAU X months after first CO | ~100% M1 → ~70% M5 → ~55% M6 |
| **Eligible User Retention** | % of active users still eligible | ~66% M0 → ~70% M1 → ~59% M5 (fairly flat) |
| **% Active & Eligible with a CO** | % of MAU+eligible users actually cashing out | ~75% M1 → ~63% M4 → ~44% M6 |

**Key insight:** Users stay active on the platform and remain eligible, but stop using CO. The drop-off is **behavioral, not structural** — a usage/engagement problem, not an eligibility or churn-from-platform problem.

### CO Retention by Bank

Significant variation by bank — Chime is worst, Chase is best:

| Bank | M1 | M3 | M5 | M6 |
|------|-----|-----|-----|-----|
| **Chase** | ~55% | ~34% | ~29% | ~17% |
| **Wells Fargo** | ~53% | ~32% | ~25% | ~15% |
| **Bank of America** | ~53% | ~30% | ~21% | ~13% |
| **PNC** | ~56% | ~26% | ~20% | ~14% |
| **Current** | ~55% | ~30% | ~15% | ~6% |
| **Chime** | ~44% | ~18% | ~12% | ~6% |

Chime's M6 retention is ~3x worse than Chase. Could be driven by fee sensitivity, user demographics, or transfer experience.

### CO Retention by User Tenure at Enrollment

| Tenure Bucket | M1 | M3 | M5 | M6 |
|--------------|-----|-----|-----|-----|
| First week | 45.6% | 15.9% | 5.5% | 1.8% |
| D15–D30 | 49.4% | 19.9% | 7.9% | 2.9% |
| D31–D60 | 49.4% | 20.5% | 6.7% | 2.4% |
| D61–D90 | 54.6% | 22.5% | 7.9% | 3.0% |
| D91–D180 | 53.6% | 23.6% | 8.6% | 2.7% |
| D181+ | 53.3% | 23.2% | 8.8% | 2.9% |
| Year+ | 52.3% | 21.8% | 7.7% | 3.3% |

First-week enrollees retain worst. Longer-tenured users retain modestly better but the difference narrows by M6.

### Other Retention Cuts

- **Geography:** Fairly flat; Far West slightly better (M2: 33.3%), Southeast slightly worse (M2: 27.0%)
- **Business Type:** Retail (50.7% M1) and Medical (53.3% M1) slightly better; Transportation and Hospitality slightly worse
- **Billing Source:** Shopify (32.1% M2, 25.6% M3) and Clover (30.1% M2, 19.8% M3) retain noticeably better than Homebase direct (29.2% M2, 18.5% M3). Apple/ADP also show decent retention.

---

## Enrollment Funnel Eventing

**Source:** [Cash Out - Mobile Eventing](https://joinhomebase.atlassian.net/wiki/spaces/EE/pages/4595351553/Cash+Out+-+Mobile+Eventing+WIP) (Confluence, last updated 2/11/2026)

### Enrollment Funnel Steps

| Step | Screen | Event | Key Properties |
|------|--------|-------|----------------|
| 0a | Offer Intro Screen (offer recipients only) | `Screen Viewed` / `Button Clicked` | product_area: `mobile_app_sign_up`, event_category: `cash_out_onboarding_intro` |
| 0b | HB Dashboard (earnings card) | `Screen Viewed` / `Button Clicked` | product_area: `dashboard_v2`, event_category: `earnings_card`, button_text: `set up cash out` |
| 0c | Money Tab Dashboard | `Screen Viewed` | product_area: `cash_out_earnings_screen`, event_category: `earnings_tab_6.3.1` |
| 1 | CO Intro Screen (all users) | `Screen Viewed` / `Button Clicked` | product_area: `cash_out_enrollment`, event_category: `cash_out_enrollment_details`, button_text: `Set up now` |
| 2a | Bank Consolidation (Plaid returning users) | `Screen Viewed` / `Cancel Clicked` | product_area: `cash_out_enrollment`, event_category: `select_available_bank` |
| 2b | Plaid Linking Intro (new Plaid users) | `Screen Viewed` | product_area: `Cash Out - Plaid`, event_category: `plaid_intro` |
| 2c | Plaid Phone Screen | `Screen Viewed` / `Skip Submit Phone` | product_area: `cash_out_plaid`, event_category: `submit_phone` |
| 3 | Select Institution | `Screen Viewed` / `Select Institution` / `Handoff` | product_area: `cash_out_plaid`, event_category: `select_institution`. **`Handoff` event = Plaid flow completed** |
| 4 | PII Screen | `Screen Viewed` / `Button Clicked` | product_area: `cash_out_enrollment`, event_category: `confirm_signup_details`. *Note: Some users bypass this screen* |
| 5 | Add Debit Card | `Screen Viewed` / `Button Clicked` | product_area: `cash_out_enrollment`, event_category: `add_debit_card` |
| 6 | Confirm Payday (non-HB payroll only) | `Screen Viewed` / `Button Clicked` | product_area: `cash_out_enrollment`, event_category: `confirm_payday` |
| 7 | Customize Experience | `Screen Viewed` / `Button Clicked` | product_area: `cash_out_enrollment`, event_category: `alert_settings`, button_text: `Finish Setup` |
| 8 | Signup Success | `Screen Viewed` / `Button Clicked` | product_area: `mobile_app_sign_up`, event_category: `success_confirmation` |

> *Note: Bank Account Selection screen (formerly between steps 3 and 4, event_category: `enrollment_1.5`) was removed via the Hide Account Selection experiment — 10% on 2/11/26 → 50% on 2/13/26 → 100% on 2/23/26 ([Slack ref](https://pioneerworks.slack.com/archives/C051KVARH7Y/p1772557900895859?thread_ts=1772492943.716639))*

### Plaid Branching Logic
- **Plaid Returning Users** (previously connected via HB): Go to Bank Consolidation screen → can confirm existing bank or add new one. Higher Plaid completion rates.
- **Plaid New Users:** Full Plaid flow: Intro → Phone verification (if in Plaid DB) → Select Institution → Authenticate → Handoff back to HB.
- Details: [Plaid branching spreadsheet](https://docs.google.com/spreadsheets/d/1HupqimGZ2pOs3a2i7qD5A_WZReGnLiLeYpUltaEZjgo/edit?gid=0#gid=0)

### Test User IDs
- Payroll Customer: `2297785` (live session) / `2297780`
- Non-payroll Customer: TBD

---

## Financial Forecast Model

**Source:** [FinServ Forecast Model — Cash Out sheet](https://docs.google.com/spreadsheets/d/1OryVpdyJyrNc6fevFoX5tNj5EUUOJiZhGPwKdGHSQ0k/edit?gid=728486487#gid=728486487)

### Model Structure

The Cash Out financial model is a detailed P&L forecast spanning Jan 2020 – Dec 2028, with monthly, quarterly, and annual views. Key sections:

**P&L Summary**
- Revenue (by segment: Core Banks, Neobanks, ConAccess, Dormant)
- COGS (setup, transaction, connection, platform, support costs)
- Gross Profit & Gross Margin
- Losses (by segment, with D120 default rate)
- Contribution Margin

**Model Drivers**
- Enrollments (new + repeat, by bank segment: Core Banks, Chime, Non-Chime Neobanks)
- CO Users (first-time + returning, by segment)
- Number of Cash Outs taken
- Revenue per CO, $ cashed out per CO
- Loss rates (by segment, first-time vs returning, EOM estimates vs D120 estimates)
- Activation rates, retention rates, attach rates

**Cost Breakdown**
- Money Movement Costs (Checkout: RTP send, Payouts send, Payments payback)
- User Connection Costs (Plaid: Assets API, Auth API, Transaction API, Balance Calls)
- Platform Costs (VGS)
- Support Costs

### How Revenue Works
- Revenue = instant delivery fees ($4.99) from Cash Outs taken that month
- Segmented by bank type: Core Banks (~60-70% of rev), Neobanks (growing share), ConAccess (continuing access users), Dormant

### How Losses Work
- Losses = total $ advanced that month × D120 default rate (forecasted)
- D120 = amount not paid back 120 days after advance
- Loss rates differ significantly by segment:
  - **First-time CO users:** ~6.5% blended (higher risk)
  - **Returning CO users:** ~1.9% blended (lower risk, proven payback history)
  - **Neobanks:** ~3.8% (higher than core banks)
  - **Overall blended:** ~2.0%

### Support Costs (Plaid Connection Costs)

Support costs include two Plaid API cost categories:

**Auth API (Plaid)**
- Fetches bank account details (account and routing numbers) when a user links or relinks their bank account
- **Where it's used:**
  - **CO enrollment:** Called when a user links or relinks their bank account during Cash Out enrollment
  - **Payroll:** Called when an account is linked/relinked for payroll through Plaid, and through the payroll self-setup flow
- **Volume drivers:**
  - Number of CO enrollments (link/relink events)
  - Payroll link/relink events and self-setup flow volume
  - Seasonality — volume may spike at similar times year-over-year (e.g., holiday/Dec cohorts with lower quality may trigger more relinks)
- **Source:** [Slack thread (ee_dev_team, 2/24/26–3/4/26)](https://pioneerworks.slack.com/archives/C092VCS8GP6/p1771975081066459) — Abdullah Al-Omaisi

**Assets API (Plaid Asset Reports)**
- Fetches Plaid Asset Reports — a snapshot of a user's financial accounts (balances, transactions, identity info)
- **Where it's used:**
  - **Eligibility engine:** Asset report is fetched when running the eligibility engine (CO underwriting)
  - **Plaid webhooks:** Fetched when receiving webhooks from Plaid indicating the asset report is ready
  - **Post-advance tracking (legacy):** Fetched to send tracking data after an advance is created, if the report isn't already cached (legacy logic, no recent changes)
- **Volume drivers:**
  - Number of eligibility checks (tied to CO enrollment/re-evaluation volume)
  - Webhook activity from Plaid for report updates — includes unnecessary updates for archived/unused accounts (Zobair working on archiving unused reports to reduce this, as of March 2026)
  - Advance creation volume
- **Source:** [Slack thread (ee_dev_team, 2/24/26–3/4/26)](https://pioneerworks.slack.com/archives/C092VCS8GP6/p1771975081066459) — Abdullah Al-Omaisi

**Transaction API (~$0.10/call)**
- Used for eligibility checks — we check user's transactions to detect if they have payroll
- Affected by # of CO enrollments with an active Plaid connection
- Costs relate to previous cohorts and show up when we get paid back
- 2026 forecast: ~630K-786K calls/month, ~$55K-$74K/month

**Balance Calls (~$0.02/call)**
- Used for payback collection — we send balance calls on and after payment due date to detect if user has sufficient funds in their account
- Payment due date is usually 1 day – 2 weeks after advance date
- Balance calls are sent frequently in first 7 days (~50 calls per user), then decrease until Day 90
- Affected by non-repayments (more non-repayments = more balance calls)
- Costs relate to previous cohorts — we send balance calls on or after payback date until D90
- 2026 forecast: ~4.2M-5.2M calls/month, ~$77K-$94K/month

### Weekly Business Review (WBR)

**Source:** [WBR Refresh - 2026](https://docs.google.com/spreadsheets/d/1zWO8QiOC2rrj_QUIAnqCEDhMNIzS2PVASmQwxnD8D-s/edit?gid=350728135#gid=350728135) — Sheets: `8. Cash Out`, `Cash Out Data`, `Cash Out Pacing`

**Ownership:** Updated by Strategic Finance team. Analytics team (Janice) supports with pacing questions and number validation.

The WBR tracks weekly and monthly actuals against PoR (Plan of Record) goals.

**`8. Cash Out` sheet — Weekly dashboard with:**
- **Eligible Base:** Users added to Homebase, eligible employees (mobile + shift active), mobile engagement rate (~69%)
- **Enrollment & Activation:** New enrollments, first-time CO users, first-time activation rate (~42%), total CO users
- **Usage Metrics:** Instant advance rate (~96%), avg COs per user (~5.2/mo), CO ARR
- **Loss Rate:** D28 loss rate (lagged ~2 weeks), tracked weekly
- **PoR Goals:** Full-year monthly targets for all key metrics
- **Clover Embedded:** Separate tracking for Clover upsold users (growing from ~950 users Jan '26 to projected ~9.2K Dec '26)
- **Pacing:** Daily cumulative CO user count for current month, with prior year distribution curve for forecasting EOM

**`Cash Out Data` sheet — Raw data feeds from Looker:**

| Data Feed | Looker Source | Frequency |
|-----------|--------------|-----------|
| Eligible Base (Shift Active + Mobile Active) | [Look #3136](https://homebase.looker.com/looks/3136) | Weekly |
| Monthly Eligible Base | — | Monthly |
| Weekly Enrollments | [Look #3151](https://homebase.looker.com/looks/3151) | Weekly |
| Monthly Enrollments | [Look #3147](https://homebase.looker.com/looks/3147) | Monthly |
| Weekly Advances (by CO bucket) | [Look #3176](https://homebase.looker.com/looks/3176) | Weekly |
| Monthly Advances | [Look #3148](https://homebase.looker.com/looks/3148) | Monthly |

**CO User Segments (used in WBR advance tracking):**
- `1.1 Chime New User` / `1.2 Neo New User` / `1.3 Non-Neo New User` — First-time CO users by bank
- `2.1 Chime Returning` / `2.2 Neo Returning` / `2.3 Non-Neo Returning` — Returning CO users by bank
- `3.1 New Continued Access` / `3.2 Returning Continued Access` — ConAccess users
- `4.1 Reactive Dormant` / `4.2 New True Dormant` / `4.3 Returning True Dormant` — Dormant users

**`Cash Out Pacing` sheet:** [CO Pacing Model](https://docs.google.com/spreadsheets/d/188uNT9pGntmUsgqqXX0A-HNCru4ZyP4YdTZ02uuLYeQ/edit?gid=174548655#gid=174548655)

#### Pacing Methodology

```
                        ┌─────────────────────┐
                        │   Monthly CO Goal    │
                        │      248,522         │
                        └──────────┬──────────┘
                                   │
                    ┌──────────────┴──────────────┐
                    │  Weekly Distribution Table   │
                    │  (from 2025 historical data) │
                    │  W1-W4: 22.6%  W5: 9.7%     │
                    └──────────────┬──────────────┘
                                   │
                        ┌──────────┴──────────┐
                        │    Weekly Goals      │
                        │  W1-W4: 56,166 each  │
                        │  W5: 24,107          │
                        └──────────┬──────────┘
                                   │
                    ┌──────────────┴──────────────┐
                    │  Day-of-Week Distribution    │
                    │  (from last 6 months actuals)│
                    │  Mon 12.9%  Fri 20.9%        │
                    │  Tue 13.2%  Sat 13.9%        │
                    │  Wed 13.6%  Sun 11.6%        │
                    │  Thu 13.9%                    │
                    └──────────────┬──────────────┘
                                   │
                        ┌──────────┴──────────┐
                        │    Daily Goals       │
                        │  (per day of month)  │
                        └──────────┬──────────┘
                                   │
                        ┌──────────┴──────────┐
                        │  Cumulative Goals    │
                        │  (running sum)       │
                        └─────────────────────┘


    ═══════════════════ FORECAST SIDE ═══════════════════

    ┌─────────────────┐   ┌──────────────┐   ┌──────────────┐
    │  7-Days-Ago     │   │  W1% / W4%   │   │   Manual     │
    │  CO Actual      │ × │  Ratio       │ × │   Adj.       │
    │  (SUMIFS)       │   │  (currently  │   │   (optional) │
    │                 │   │   1.0)       │   │              │
    └────────┬────────┘   └──────┬───────┘   └──────┬───────┘
             │                   │                   │
             └───────────────────┴───────────────────┘
                                 │
                      ┌──────────┴──────────┐
                      │  Daily Predicted    │
                      │  (Column P)         │
                      └──────────┬──────────┘
                                 │
             ┌───────────────────┴───────────────────┐
             │                                       │
  ┌──────────┴──────────┐             ┌──────────────┴────────────┐
  │  Cumulative Actuals │      +      │  Sum of Remaining         │
  │  (days with data)   │             │  Predicted (future days)  │
  └──────────┬──────────┘             └──────────────┬────────────┘
             │                                       │
             └───────────────────┬───────────────────┘
                                 │
                      ┌──────────┴──────────┐
                      │   EOM Forecast      │
                      │   (e.g. 241,675)    │
                      └──────────┬──────────┘
                                 │
                      ┌──────────┴──────────┐
                      │   Pacing %          │
                      │   EOM Forecast /    │
                      │   Monthly Goal      │
                      │   (e.g. 97.2%)      │
                      └─────────────────────┘
```

**Goal-Setting Pipeline (top half):**
1. **Monthly Goal** (248,522) is split into **Weekly Goals** using a weekly distribution table (from 2025 historical data)
2. Weekly Goals are split into **Daily Goals** using a day-of-week distribution (from last 6 months of actual CO data)
3. Daily Goals are summed into **Cumulative Goals** (running total)

**Forecast Pipeline — Legacy (LW Method):**
1. **Daily Predicted** = (7-days-ago actual) × (W1% / W4% ratio) × (manual adjustment, if any)
   - W1%/W4% ratio adjusts for weekly volume seasonality within a month (currently 1.0 for all month types)
   - Manual adjustments are multipliers on select rows for known anomalies
2. **EOM Forecast** = Cumulative Actuals + Sum of Remaining Predicted
3. **Pacing %** = EOM Forecast / Monthly Goal

**Known issues with LW method:**
- Uses a single data point (7 days ago) — high variance
- Cross-month boundary distortion: late-month volumes from the prior month are systematically different from early-month volumes (e.g., Feb W4 → Mar W1 caused 17–28% prediction errors in March 2026)
- W1/W4 ratio was designed to correct this but is set to 1.0 (no effect)
- Requires heavy manual adjustments (0.9x, 1.15x multipliers) to compensate

**Forecast Pipeline — Current (Cumulative YoY Method):**

Introduced March 2026. Replaces the LW method as the primary forecast. Built in the `CO Pacing 2026` sheet.

1. **Track weekly CO volumes by ISO week (Mon–Sun)** from Looker, stored in `Reference_Tables` sheet with historical data for 2023–2026
2. **Calculate cumulative YoY growth rate:**
   ```
   Cumulative YoY % = (Sum of all complete 2026 weeks) / (Sum of same 2025 weeks) − 1
   ```
   As of Week 9 (ending 3/1/2026): **+3.77%**. This rate self-corrects as more 2026 weeks complete.
3. **Forecast future weekly volumes:**
   ```
   2026 Week N Forecast = 2025 Week N Actual × (1 + Cumulative YoY %)
   ```
4. **Distribute weekly forecast to daily using day-of-week weights** (from 2025 full-year data):
   | Mon | Tue | Wed | Thu | Fri | Sat | Sun |
   |-----|-----|-----|-----|-----|-----|-----|
   | 12.99% | 13.25% | 13.28% | 13.82% | 20.82% | 14.14% | 11.69% |
   ```
   Daily Forecast = Weekly Forecast × DOW Weight
   ```
5. **EOM Forecast** = Cumulative Actuals (days with data) + Sum of remaining daily forecasts. For days without actuals, the latest EOM forecast carries forward.
6. **Pacing %** = EOM Forecast / Monthly Goal

**1st-of-Month Multiplier (1.12x):**

The 1st of each month consistently runs ~12% above DOW-expected volume. Two reinforcing drivers:

1. **Demand side (user behavior):** Rent, utilities, and other recurring bills are due at the start of the month, making employees more cash-strapped and more likely to take an advance.
2. **Supply side (system mechanics):** Many users have repayment dates clustered around month-end/1st (CS frequently sets pay frequency to the 1st and 15th). Once repayment clears, CO access resets, enabling a new advance immediately — creating a burst of day-1 requests.

**Validation (out-of-sample backtest across 11 months):**
- Median ratio of actual vs. DOW-expected: **1.124** (range: 1.057–1.173, no drift over time)
- Without multiplier: 10.8% mean absolute error, always under-predicts
- With 1.12x multiplier: 3.6% mean absolute error, balanced bias
- See [1st-of-Month Multiplier Analysis](https://docs.google.com/document/d/1Tuq_3rOxGZV9jsqhY2BPiWGc37SJ6F3exZw0FzteRLQ/edit)

**Implementation:** Applied in the `CO Pacing 2026` sheet (column L, row for day 1). The excess (~762 advances for a typical month) is redistributed evenly across remaining days to keep the monthly total anchored. **Exceptions:** Do not apply on Jan 1 (New Year's) or Sep 1 when it falls on Labor Day — holiday effects suppress the spike on those dates.

**Notable data point:** 8/1/2025 set a CO single-day record at 13,953 advances (Kevin McDonough, #ee-bizops-priorities).

**Why Cumulative YoY is better:**
- Compares same ISO weeks YoY → no cross-month boundary distortion
- Captures macro growth/decline trend via the cumulative YoY rate
- Self-correcting — rate updates as more 2026 weeks complete
- Eliminates need for manual adjustments
- Early March 2026 results: avg daily prediction error dropped from **21.3% (LW) → 4.6% (Cum YoY)**

**ARR Calculation:**
```
ARR = EOM Forecast CO Volumes × Instant % × $4.99 (revenue per CO) × 12 months
```
- Instant % currently 95.7%; $4.99 flat fee per instant CO; ×12 to annualize

### WBR Output: Cash Out Slide

**Output:** [WBR Slide Deck — Cash Out slide](https://docs.google.com/presentation/d/1o9Z-kUMBkiLxneAoLnAtaiYIaB192QvjUa91KS9GXMQ/edit?slide=id.g3cc3fdf9e3a_3_121#slide=id.g3cc3fdf9e3a_3_121)

The WBR numbers flow into a Cash Out slide in the weekly WBR presentation deck.

**Workflow:**
1. **Strategic Finance** updates the slide numbers from the WBR Refresh sheet
2. **Janice (Analytics)** takes a first pass evaluating actuals vs PoR, looking for:
   - Seasonality trends (holidays, tax return season, etc.)
   - Known issues discussed in Slack that week/month (e.g., Capital One non-repayment rates, Indiana shutdown)
   - Any anomalies or deviations that need explanation
3. **Jon Blackwell (CO Product Manager)** also reviews and provides product context

**Slide structure:**
- Commentary bullets at top (key callouts, wins, risks)
- Metrics table: Eligible Base, Enrollment & Activation, Usage, Loss Rate
- Columns: recent months actuals, PoR target, Var (%), prior year comparison

**Example (Feb '26 slide):** Pacing to ~$12.5M ARR (-12% to PoR goal). Miss driven by larger-than-expected tax return impact on both # of employees receiving returns and avg return size. Also noted: KYC fix for ~65K users, 1.1K ConAccess users unblocked from enrollment bug, enrollment screen removal projected to add ~1.8K enrollments/month (~$226K ARR).

### 2026 Forecast Summary

| Metric | Jan '26 | Jun '26 | Dec '26 | FY 2026 (avg/mo) |
|--------|---------|---------|---------|-----------------|
| Total Revenue | $1.18M | $1.18M | $1.30M | ~$1.21M |
| Total COGS | $437K | $440K | $478K | ~$450K |
| Gross Margin | 63.0% | 62.8% | 63.1% | ~63% |
| Total Losses | $440K | $437K | $469K | ~$440K |
| Contribution Margin | $304K | $307K | $348K | ~$323K |
| Contribution Margin % | 25.7% | 25.9% | 26.8% | ~26.5% |
| Total CO Users | 47,075 | 48,506 | 51,609 | ~48,810 |
| New Enrollments | 17,678 | 21,283 | 24,264 | ~21,663 |
| First-Time CO Users | 7,385 | 8,493 | 9,560 | ~8,882 |
| Total # COs Taken | 247K | 263K | 282K | ~267K |
| Total $ Cashed Out | $20.1M | $20.2M | $22.4M | ~$20.9M |
| Blended Loss Rate | 2.07% | 2.04% | 1.98% | ~2.0% |
| Annualized Revenue | $14.2M | $14.2M | $15.5M | ~$14.5M |

### COGS Breakdown (2026 monthly averages)

| Cost Category | Avg Monthly | % of COGS |
|--------------|-------------|-----------|
| Money Movement (Checkout) | ~$368K | ~82% |
| User Setup (Plaid) | ~$68K | ~15% |
| Connection - Transaction API | ~$66K | ~15% |
| Connection - Balance Calls | ~$88K | ~20% |
| Support | ~$13K | ~3% |
| **Total COGS** | **~$450K** | **100%** |

*Note: Connection costs (Transaction API + Balance Calls) overlap with Money Movement in the total since they're subcategories of Plaid costs.*

---

## Experiments

### Hide Account Selection Screen (Feb 2026)

**What:** Removed the Bank Account Selection screen from the CO enrollment flow. After connecting a bank via Plaid, users previously saw a screen asking them to re-select the same account they just connected. Removing it simplified the flow from 6 steps to 5.

**Context:** The Account Selection screen originally existed to support Pay Any Day (PAD), Homebase's debit/banking product, where users need to select which bank account to link for ACH transfers and direct deposit routing. The screen was shared infrastructure across both CO and PAD enrollment. For CO, it was redundant — users typically connect a single account via Plaid, and the system can auto-select it. The experiment tested removing it from the CO flow only.

**Experiment name:** `cash_out_enrollment_hide_account_selection` (variant 0 = control, variant 1 = treatment)

**Timeline:** 50/50 split ran Feb 14–19. Rollout: 10% on 2/11 → 50% on 2/13 → 100% on 2/23.

**Result (domain data, full population):**

| Metric | Control | Treatment |
|--------|---------|-----------|
| Users in experiment | 4,825 | 4,825 |
| Successful enrollments | 713 | 773 |
| Enrollment rate | 14.8% | 16.0% |
| **Lift** | | **+1.2pp** |

**Revenue impact: $71K – ~$200K incremental ARR** (presented as a range)

| Framing | Denominator | Lift | Monthly initiators | ARR estimate |
|---------|-------------|------|--------------------|--------------|
| Intent-to-treat (conservative) | All who initiated enrollment | +1.2pp | ~48,250 | ~$71K |
| Post-Plaid (intervention point) | Users who connected a bank | +7.5pp | ~22–25K | ~$200K |

Both use domain data only. The post-Plaid framing is arguably more appropriate because the experiment only changed the flow *after* Plaid connection — users who never reached Plaid were never exposed to the treatment. The intent-to-treat framing dilutes the lift with users who dropped before the intervention point. The unexplained Plaid conversion gap (-7.9pp fewer treatment users reaching Plaid) was investigated: Jon hypothesized control users were re-initiating Plaid connections due to confusion from the Account Selection screen, but this was ruled out — domain "connected bank" counts are already unique users. The gap remains unexplained but does not indicate selection bias given the treatment only modifies the post-Plaid experience.

**Key learnings:**

1. **Removing friction works, even for "simple" screens.** The Account Selection screen asked users to confirm information they had just provided via Plaid. Even though it was a single tap, removing it lifted post-Plaid enrollment by +7.5pp — suggesting that any extra step in a high-drop-off flow has a measurable cost.

2. **Low-effort UX simplifications can drive meaningful revenue.** At $71K–$200K ARR for a one-week eng effort, this was a high-ROI change. There may be similar opportunities elsewhere in the enrollment funnel (e.g., auto-filling KYC fields, reducing debit card verification steps).

3. **No negative downstream effects observed.** Activation rates and CO usage patterns among treatment enrollees were consistent with control, indicating the removed screen was not providing value to users (e.g., helping them catch account errors).

4. **Shared infrastructure across products requires careful scoping.** The screen was originally built for PAD, where account selection is more meaningful. This experiment confirmed it could be safely removed from CO without affecting PAD. Future enrollment flow changes should evaluate product-specific impact rather than assuming shared screens serve all flows equally.

**Analytical note:** Revenue projections should be anchored on domain data, not Amplitude. Amplitude captured a subset of users with uneven counts across variants (2,431 vs 1,988, vs. domain's balanced 4,825/4,825), and within that subset treatment had *fewer* tracked enrollments than control — the apparent +3.8pp Amplitude lift was an artifact of the smaller denominator. Domain data reflects the true population. See [Amplitude vs Looker: Key Caveats](#amplitude-vs-looker-key-caveats) for broader guidance.

**People:** Jon Blackwell (PM), Abdullah Al-Omaisi (eng), Wilfried Penel (eng), Santiago Borjon (eng), Janice Lee (analytics)

**Links:** [Analysis spreadsheet](https://docs.google.com/spreadsheets/d/1sG8X66l0M5hByN_D8etSrDVQtn8b4Rje4K6eenMgte0/edit?gid=625738012#gid=625738012) | [Confluence tech design](https://joinhomebase.atlassian.net/wiki/spaces/EE/pages/4566351873/Bank+Account+Selection+Removal+Experiment) | [Results & Revenue Impact doc](/Users/jlee/Downloads/CO%20Removing%20Bank%20Acct%20Selection%20Screen_%20Results%20%26%20Revenue%20Impact.docx)

### Web-first Enrollment Experiment (ongoing)

**Objective:** De-risk Bet #1 (Web Enrollment for Cash Out) by testing whether non-mobile employees will engage with a web-first Cash Out value proposition and take a meaningful step toward enrollment — before investing in the full enrollment flow (Plaid, debit, eligibility).

**TAM opportunity:** ~375K shift-active employees reachable via SMS, email, or Clover POS who have never used the Homebase mobile app and have no prior Cash Out enrollment/usage. Converting 2–10% represents $2.2M–$10.8M ARR.

**Core hypothesis:** Employees who don't identify as Homebase users will still engage with a Cash Out value proposition when it is employer-anchored and delivered via mobile web. A meaningful subset will complete phone + OTP verification, signaling sufficient trust and intent to justify building the full enrollment flow.

**What is being tested:**
- Does the Cash Out value prop resonate in a web-first context?
- Does anchoring to the employer establish enough trust to proceed?
- Will users complete phone + OTP verification?
- How does engagement differ by entry context (QR vs. SMS vs. email)?

**What is NOT being tested:** Full enrollment (Plaid, debit, payday), eligibility/limits, app installs, revenue/attach rate.

**Entry points (mutually exclusive, priority-ordered):**
1. **QR – Clover** (highest context): QR code shown after clock-out on Clover POS. ~2,000 users sampled, ~960 expected reach.
2. **QR – Other Timeclock**: Same post-clock-out QR flow on non-Clover timeclocks. ~1,995 users sampled, ~958 expected reach.
3. **SMS** (semi-warm): Post-shift SMS referencing employer/earnings. ~2,997 users sampled.
4. **Email** (cold baseline): Post-shift email for users with email but no phone. ~1,499 users sampled.
- Total reachable eligible: ~45,969. Sampled: ~8,491 across ~3,738 locations.

**User experience funnel:** Entry Point → Employer-anchored landing page → Continue CTA → Phone number entry (pre-filled for SMS) → OTP verification → Success screen ("we'll notify you when Cash Out is available").

**Primary success metric:** Web Enrollment Throughput Rate = OTP verified / Landing viewed.

**Funnel metrics:** QR scan rate, SMS/email CTR, continue rate, phone submission rate, OTP completion rate.

**Experiment design:**
- Duration: 7 days
- One-time exposure per user, no repeated messaging
- Control group: all eligible users not sampled
- Enrollment method: manual enrollment by location (CSV upload to Admin Experiment Enroller)
- Non-promissory framing (no dollar amounts or guarantees)

**Guardrails:** Small exposure per segment, one-time exposure, no repeated messaging, no promise of immediate access to funds, clear next-steps copy.

**People:** Jon Blackwell (PM), Arvin Sabares (eng), Craig Wedseltoft (eng), Tim Cannady (eng), Jeff Gombos (design), Darin Thacker (LCM/Iterable), Darah Lee (LCM), Janice Lee (analytics)

**Slack channel:** `#proj-co-web-enrollment`

**Links:** [Experiment Proposal](https://docs.google.com/document/d/1TUfBN9zyRF5iED_oe5Lrn2V7Qj7C6r_qDl6GzFS4DqY/edit) | [Experiment Design](https://docs.google.com/document/d/1GqrTXHCwL2j1ebXtrKxZRMk6OpEgJNV2u72x17Zn3KE/edit)

**Launch status (as of 2026-03-10):**

*Email entry point — launched 2026-03-09 (metrics as of 2026-03-10, source: Amplitude):*

Iterable send → click funnel ([Amplitude chart](https://app.amplitude.com/analytics/homebaseone/chart/3z4m5gz5)):
- 1,559 emails sent (975 on 3/9, 584 on 3/10), 17 email clicks → **1.1% CTR**
- Emails deployed in batches based on user typical open time
- [Iterable campaign link](https://app.iterable.com/analytics/campaignPerformance?campaignId=17030787)

Landing → OTP full funnel ([Amplitude chart](https://app.amplitude.com/analytics/homebaseone/chart/tlqg1wcx)):
- Viewed Landing Page: 16
- Clicked Continue: 11
- Enter Phone Number: 11
- Clicked Send Code: 6
- OTP Sent: 5
- Viewed Verify Identity: 5
- Enter Code: 5
- Clicked Verify Code: 4
- OTP Confirmed: 4
- Viewed Success Page: 4
- **Overall conversion (Landing → Success): 25%** (4/16)
- Key takeaway: Strong throughput once users reach the landing page; primary bottleneck is upstream email CTR (1.1%)

*QR entry points — pre-launch:*
- Android Timeclock events confirmed working in staging (validated by Amorous Carpenter)
- Arvin syncing with Juan to verify `Modal Viewed` event on timeclock app side before launch

*Known issue — missing company_name in URL params:*
- Some email users land with empty `company_name` and `location_id` in URL, causing landing page to show literal `[Business Name]` placeholder
- Root cause: users uploaded to Iterable via old CSV (Feb 2024 campaign) didn't properly stitch to Homebase profile
- Fix: PR [#67199](https://github.com/pioneerworks/Homebase1/pull/67199) — landing page header fallback copy ("Access your earnings from your recent shifts" when company name is missing)
- Darin confirmed email body already had fallback logic built in prior to launch

*Full web enrollment flow design (ahead of experiment):*
- Jeff Gombos shared updated Figma designs: review step (desktop + mobile), greyed-out approval state, generic success/error modals, consistent branding
- Prod Design Eng meeting (3/9) decisions: errors show on blur or Continue click only; simple front-end validation; generic "something went wrong" toast for server errors in MVP; same two-step flow (edit → review) for desktop and mobile web; single generic enrollment-complete message; logout returns to landing page with phone+OTP re-login
- Open items: Tim investigating mobile state machine mapping to web; Arvin researching card type auto-detection and browser autofill for debit entry

### Debit Repayment Delay Experiment (ongoing)

**Objective:** Determine whether shifting debit repayment attempts 5–10 minutes past the top of the hour reduces Sidekiq queue contention during peak clock-in/out hours (6–9am ET) without degrading repayment success rates.

**Context:** Cash Out repayments are collected via a background worker called `shift_pay_enqueue_today_paybacks_debit`, which runs on a cron schedule at the top of every hour (`config/cron_schedule.yml`, line 276 of Homebase1). During the 6–9am ET window, this worker fires at the same time as clock-in/clock-out traffic spikes, and both compete for Sidekiq (background job processing) resources. This was identified as a cause of slow clock-in response times during morning peak hours. The proposal was to offset debit repayment pulls by a few minutes so they don't collide with clock-in/out jobs.

**Experiment name:** `shift_repayment_debit_delay`

**Design:**
- Control (experiment value 0): Top of the hour — current behavior (90% of users)
- Variant 1 (experiment value 1): 5 minutes after the hour (5% of users)
- Variant 2 (experiment value 2): 10 minutes after the hour (5% of users)
- Debit pulls only (not ACH)
- Split was finalized by Kevin McDonough on Dec 18, 2025. Jenakan Sivagnaanam confirmed 5 and 10 min offsets avoid other busy queue times at :15 and :30.

**Timeline:**
- Oct 2025: JIRA ticket EE-2395 created by Abdullah Al-Omaisi (parent epic: EE-2631, EE Q1 2026 Quality)
- Dec 15, 2025: Arvin Sabares identified the specific worker and cron entry causing contention
- Dec 18–19: Experiment parameters finalized in `#ee_dev_team`
- Jan 16, 2026: PR [#65154](https://github.com/pioneerworks/Homebase1/pull/65154) merged
- Jan 20, 2026: Experiment enabled on prod
- Feb 17, 2026: Kevin's initial analysis shared — recommended extending
- Mar 9, 2026: Jon Blackwell requested re-run of analysis to make final call

**Results (as of Feb 17, 2026):**

*Debit Returns:*

| Group | Paybacks | Returns | Debit Return Rate | NSF Rate |
|-------|----------|---------|-------------------|----------|
| Control (0) | 114,115 | 68,558 | 60.1% | 14.5% |
| Variant 1 (+5min) | 6,606 | 4,062 | 61.5% | 14.0% |
| Variant 2 (+10min) | 6,153 | 3,645 | 59.2% | 14.8% |

*Non-Repayment Rates:*

| Group | Advances | D1 Rate | D7 Rate | D14 Rate |
|-------|----------|---------|---------|----------|
| Control (0) | 151,495 | 18.11% | 8.05% | 4.81% |
| Variant 1 (+5min) | 8,600 | 18.71% | 8.82% | 2.51% |
| Variant 2 (+10min) | 8,301 | 19.24% | 9.01% | 6.27% |

**Key observations (Feb 17):**
1. Control has the lowest D1 and D7 non-repayment rate, but results are **NOT statistically significant** given the 90/5/5 split (~6K paybacks per variant vs 114K in control).
2. Variant 2 has the lowest debit return rate (59.2%) but paradoxically the highest D1/D7 non-repayment rate — hard to explain at this sample size.
3. Jon Blackwell's framing: "Separate the infra question from the repayment question. The original motivation was reducing clock-in/out latency, not improving repayment. If the performance benefit is clear, that might justify the change even if repayment rates are neutral."
4. Open ask: Arvin to share Sidekiq queue depth / clock-in response time data to quantify the infrastructure benefit independently.

**Status (as of 2026-03-11):** Awaiting re-run of analysis with ~7 additional weeks of data since Feb 17. Jon requested fresh numbers on Mar 9 to make the final ship/kill decision. Databricks notebook linked in analysis sheet needs access granted.

**People:** Jon Blackwell (PM), Kevin McDonough (analytics), Abdullah Al-Omaisi (eng), Arvin Sabares (eng), Craig Wedseltoft (eng), Jenakan Sivagnaanam (eng), Janice Lee (analytics)

**Links:** [Analysis spreadsheet](https://docs.google.com/spreadsheets/d/1bezfQnIFtewVFXl9XMUg0dhAAdp8F0Oy_3jzPyNzGYg/edit?gid=7784844#gid=7784844) | [JIRA: EE-2395](https://joinhomebase.atlassian.net/browse/EE-2395) | [PR #65154](https://github.com/pioneerworks/Homebase1/pull/65154)

---

## Active Projects
- CO Pacing Revamp
- CO Refit Model Design
- CO Web Enrollment
- Web-first Enrollment Experiment
- Debit Repayment Delay Experiment
- Cash Out User Research

---

## Key Links

| Resource | Link |
|----------|------|
| Figma: App flow overview | [Figma](https://www.figma.com/file/UyLuZPL1F9w4DMAKDxd1al/%5BResource%5D-Overview%3A-Source-of-Truth?node-id=0%3A1) |
| Experiments tracker | [Google Sheets](https://docs.google.com/spreadsheets/d/1Wr1We4GOZ9CMzQqkLO670JKA0kpi0nWBfAstXhRMt_8/edit) |
| UX tracking | [Google Sheets](https://docs.google.com/spreadsheets/d/1KTQlrAPCJEppR4fDMLw97CpalU_nlY3RNdBC4rekOcw/edit) |
| Jira Roadmap | [Jira](https://joinhomebase.atlassian.net/jira/software/c/projects/SP/boards/30/roadmap) |
| Personas | [Google Slides](https://docs.google.com/presentation/d/1C7iCR05A46DKBS0aLdQINX27VvyssKbEbsBxy4BCDAY/edit) |
| Employee FAQs | [Support](https://support.joinhomebase.com/hc/en-us/articles/4406779987725) |
| Employer FAQs | [Support](https://support.joinhomebase.com/hc/en-us/articles/4406780315021) |
| HB Money survey | [Google Slides](https://docs.google.com/presentation/d/1DvGfWWFl4mQEZhNP5OJesyG6u-ZANsFkFVAVD4RTYy0/edit) |
| Employer awareness survey | [Google Slides](https://docs.google.com/presentation/d/1K97c1S8VMAwNuinYsUnezqEdXQnBLZ1SwHHbBN6L0ug/edit) |
| Accrual example spreadsheet | [Google Sheets](https://docs.google.com/spreadsheets/d/1f87TaavQLhvFliwNGyTqoMX2kXd22_boWtSf9X6r8pc/edit) |
| Pay Any Day accrual explanation | [Confluence](https://joinhomebase.atlassian.net/wiki/spaces/CO/pages/2482601985) |
| Enrollment details & drop-off rates | [Google Slides](https://docs.google.com/presentation/d/11zc1gAD3OQlPmrOt7PasICe0NOVaIi2Wt6T-8w0Q5Ms/edit) |

---

## Changelog

| Date | Section | Change |
|------|---------|--------|
| 3/10/26 | KYC System | Updated Plaid field requirements (resolved — email/phone can be omitted). Added LCM retargeting actions for D4/D6/A1 users (LCM-1214, LCM-1234). Added Issue 2 resolution path (EE-2823). Added links to data sources and Databricks notebook. |
| 3/10/26 | Retention & Churn | Added new section with cohorted retention data from Looker #899 (CO retention, active user retention, eligible retention, bank/tenure/geo/biz type/billing source cuts) |
| 2/23/26 | Enrollment | Bank Account Selection screen removed (Hide Account Selection experiment: 10% on 2/11, 50% on 2/13, 100% on 2/23) |
| 9/18/24 | Eligibility | Changed eligible transaction window from 40 to 60 days |
| 9/12/24 | Eligibility | Changed eligible transaction window from 32 to 40 days |
| 9/4/24 | Eligibility | Allowing Transfer→Deposit→Check and Transfer→Deposit→ATM as acceptable income |
| 1/12/24 | Taking Cash Out | Changed standard delivery from 3 business days (free) to same day (free) |
| 11/13/23 | Taking Cash Out | Added bank-specific first CO limit for Chime ($50) |
| 5/1/23 | Paying back | Skip signup payday if estimate doesn't exist; more users go to Pave |
| 5/1/23 | User States | Removed E1 (Verifying debit card) and E2 (Debit card not verified) |
| 4/1/23 | User States | Removed D3 state |
| 2/20/23 | Taking Cash Out | Set transaction limit to $100; added DS model for pay period limits |
| 7/11/22 | Accrual | Net wage recalc → 1x/month; risk factor → 50%; min CO → $25 |
| 6/1/22 | Eligibility | Removed company experiment enrollment; all new companies auto-enrolled |
| 3/7/22 | Taking Cash Out | Instant CO fee changed from $3.99 to $4.99 |
| 3/16/22 | User States | Removed A2 state |
