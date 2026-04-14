# Cash Out — Domain Overview

Cash Out (CO) lets hourly employees access earned wages before payday. Revenue comes from optional instant delivery fees ($4.99).

## Delivery Methods

| Method | Speed | Fee |
|--------|-------|-----|
| Standard (ACH) | Same-day | Free |
| Instant (Debit / Plaid RTP) | Within 1 hour | $4.99 flat (waived with referral) |

RTP only available at supported financial institutions.

## Eligibility

### Pre-Enrollment (gates enrollment)

- `user_id` must not be in `ShiftPay::BlockedUser` table
- Fraud indicators: reused bank/debit, PII on government watchlists, manual flag by risk/security
- Plaid rules: US valid account, 2 continuous paychecks, minimum account activity, minimum transaction days, low risk bank

### Post-Enrollment (gates usage)

- **User eligibility:** Accrued enough hours in current pay period (defaults: 1 week, $10/hour)
- **Bank eligibility:**
  - US checking account, activity >=30 days old
  - >=8 days with a transaction in last 30 days (live 1/16/23)
  - >=2 income transactions >=$150 in non-blocklisted categories in last 60 days
  - Not a blocked bank ([admin](https://app.joinhomebase.com/admin/bank_accounts_plaid_institutions?scope=blocked_banks))

**Dormant / Continued Access:** Must pass all bank eligibility checks above but exempt from user eligibility (accrual) since they have no active shifts.

### Transaction Category Blocklist

| Blocked | Exceptions |
|---------|------------|
| `[Transfer, ...]` — all | `[Transfer, Payroll]`, `[Transfer, Payroll, Benefits]`, `[Transfer, Deposit, Check]`, `[Transfer, Deposit, ATM]` |
| `[Tax, ...]` — all | None |
| `[Bank Fees, ...]` — all | None |
| `[Service, Financial, Loans and Mortgages]` | — |
| `[Service, Business Services]` | — |
| `[Service, Financial, Taxes]` | — |
| `[Service, Financial]` | — |
| `[Service, Insurance]` | — |
| `[Service, Financial, Financial Planning and Investments]` | — |
| `[Service, Financial, Stock Brokers]` | — |
| `[Service]` | — |

## Accrual

| Concept | Definition |
|---------|------------|
| Accrual rate | Net wage rate x hours worked x risk factor |
| Net wage rate | Estimated post-tax income from eligible Plaid income txns / hours worked. Recalculated 1x/month |
| Risk factor | 50% of earnings available |
| Accrual period | Time window user can access for a Cash Out |
| Accrual balance | Sum of (hours worked each day x accrual rate) for all days in period. Includes 5 days prior to previous payday |
| Minimum Cash Out | $25 |
| Max shift hours | 16 hrs/shift (capped) |

### Net Wage Rate by User Type

| Type | Service | Logic |
|------|---------|-------|
| Banking w/ payroll direct deposit | `ShiftPay::Accrual::BankingWithPayroll::CalculateNetWageRate` | Expected avg hourly wage from latest payroll data |
| Banking w/o payroll | `ShiftPay::Accrual::BankingWithoutPayroll::CalculateNetWageRate` | Income txns in last 62 days (same counterparty routing number or PPD_SEC_CODE) |

## Cash Out Limits

### Transaction limit
$100 per single Cash Out (all users).

### First-Time Users

- Data science model assigns limit after enrollment
- "Very high-risk criteria" (high risk bank) -> eligibility delayed until score assigned
- Limits by model score: [admin](https://app.joinhomebase.com/admin/shift_pay_first_cash_out_scores)
- Chime-specific: $50 limit ([admin](https://app.joinhomebase.com/admin/shift_pay_first_cash_out_bank_amount_thresholds))

### Returning Users

Dynamic limit via DS model based on: repayment history, avg bank income, days negative, bank used. Limits are tiered by risk level:

| Risk Level | Admin Link |
|------------|-----------|
| High Risk | [shift_pay_risk_scores (high_risk_level)](https://app.joinhomebase.com/admin/shift_pay_risk_scores?scope=high_risk_level) |
| Medium Risk | [shift_pay_risk_scores (medium_risk_level)](https://app.joinhomebase.com/admin/shift_pay_risk_scores?scope=medium_risk_level) |
| Low Risk | [shift_pay_risk_scores (low_risk_level)](https://app.joinhomebase.com/admin/shift_pay_risk_scores?scope=low_risk_level) |

### Dormant / Continued Access Users

Draw limits follow the same logic as **High Risk Level** returning users. See [admin](https://app.joinhomebase.com/admin/shift_pay_risk_scores?scope=high_risk_level).

Eligibility requirements:
- $100 minimum payback (all time)
- No outstanding CO balances

## Payback

### Payback Date Priority

| Priority | Source | Notes |
|----------|--------|-------|
| 1 | Homebase Payroll data | If active and provides a payday |
| 2 | User manual entry | 5-step flow, no monthly option. 90% completion rate |
| 3 | Pave ML model | Estimates income stream ([SP-6170](https://joinhomebase.atlassian.net/browse/SP-6170)) |
| 4 | First location pay period | ~8% of users |
| 5 | Internal Plaid-based model | Approximates pay frequency from income txns. ~2% of users |

Signup payday is skipped if estimate doesn't already exist -> more users go to Pave.

### Manual Payback
- Users with past due payback can attempt with card on file or different debit card
- Runs on debit network regardless of balance
- Max 3 different cards per week

### Automatic Payback Workers — Cash Out

| Worker | Days | Schedule | Conditions |
|--------|------|----------|------------|
| `EnqueueTodayPaybacksDebitWorker` | 1, 8, 15, 22, 29 (excl. Sun) | Every 1 hr from 12am local | No debit error, no Plaid error |
| `EnqueuePastDuePaybacksDebitWorker` | 2-90 (excl. 8,15,22,29 & Sun) | Every 30 min, 2-7am local | No debit error, no Plaid error |
| `CheckPaybacksDebitWithPlaidErrorWorker` | 1-90 (excl. Sun) | 10am UTC | No debit error, YES Plaid error |
| `CheckPaybacksSameDayAchWorker` | 1-90, Mon-Fri | 4pm UTC | YES debit error, no Plaid error |
| `CheckPaybacksAchWorker` | 1-90, Mon-Thu | 9pm UTC | YES debit error, no Plaid error |
| `shift_pay_payback_methods` (Same Day ACH) | 1-30, Mon-Thu | 1x per 28 days, 2pm UTC | YES debit error, YES Plaid error |
| `CheckWebhookNewTransactionsWorker` | 1-360 | On webhook | Checks if income txn > outstanding + buffer, then attempts debit |

Partial paybacks of >=$25 allowed after day 1 via debit rails.

### Automatic Payback — Pay Any Day

| Trigger | Worker | Logic |
|---------|--------|-------|
| Credit received to HB Money account | `ShiftPay::Payback::ProcessForBankingUserWorker` | Runs if due or past due |
| Daily cron (end of night) | `Scheduled::ShiftPay::Banking::EnqueueUsersForDueRepaymentWorker` | Due and past due users |

## Integrations

| Partner | Purpose |
|---------|---------|
| [Plaid](https://plaid.com/) | Secure bank account connection via pre-built mobile UI |
| [Synapse](https://synapsefi.com/) | Sending/receiving funds between user bank account and Homebase account |

Global kill switch available for critical P0 bugs when a quick fix isn't possible.
