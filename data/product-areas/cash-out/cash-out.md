# Cash Out — Data & Computation Details

Tables, joins, dashboards, pacing methodology, and data gotchas for Cash Out metrics. For metric definitions, see `data/glossary.md`.

## Key Joins

| Left Table | Right Table | Join Key | Use Case |
|---|---|---|---|
| `prod_redshift_replica.public.cashout_advances` | `prod_redshift_replica.postgres.shift_pay_eligibilities` | `user_id` | Activation rate, enrollment-to-advance conversion |
| `prod_redshift_replica.public.cashout_advances` | `prod_redshift_replica.firehose.shift_pay_advance_events` | `advance_id` | Location, risk score, returning_limit_rank per advance |
| `prod_redshift_replica.public.fact_users_by_day` | `prod_redshift_replica.ext_firehose.shift_pay_user_state_events` | `user_id` + `date` | Retention metrics requiring `user_state` (not native to `fact_users_by_day`) |
| `prod_redshift_replica.postgres.shift_pay_paybacks` | `prod_redshift_replica.postgres.shift_pay_transaction_events` | `transaction_id = synapse_transaction_id` | Debit return rate, NSF return rate |
| `prod_redshift_replica.postgres.shifts` | `prod_redshift_replica.postgres.jobs` | `owner_id = jobs.id` where `owner_type = 'Job'` | Shift-active user counts for mobile engagement |

## Metric Computation Details

Detailed query logic and usage guidance for CO metrics defined in `data/glossary.md`.

### First-time vs Returning CO User

Two approaches to classify:
1. **Advance-level:** Compute `first_payback_date` as `MIN(payback_date)` per `user_id` (not a raw column in `cashout_advances`). New = `payback_date = first_payback_date`. Returning = `payback_date <> first_payback_date`. Use for volume reporting and loss rate segmentation by new/returning.
2. **Point-in-time:** Use `fact_users_by_day.cashed_out_before` (`false` = first-time, `true` = returning). Best when you need user status on a given date rather than per-advance classification.

### CO Activation Rate

Numerator: distinct `user_id` with at least one `status = 'SETTLED'` advance in `cashout_advances`. Denominator: distinct `user_id` with enrollment in `shift_pay_eligibilities` (`triggered_by = 'enrollment'`). Measures enrollment-to-usage conversion.

### CO Enrollment Completion Rate

Numerator: distinct `user_id` reaching `user_state IN ('B', 'B2')` in `shift_pay_user_state_events`. Denominator: distinct `user_id` with any enrollment-triggered event.

### CO Eligibility Pass Rate

`COUNT(DISTINCT CASE WHEN eligible = true THEN user_id END) / COUNT(DISTINCT user_id)` in `shift_pay_eligibilities` where `triggered_by = 'enrollment'` and `rules_version_number = 5`.

### Retention Metrics

All four retention metrics are cohorted by `first_cash_out_date` month in `fact_users_by_day`. Month X = `DATEDIFF('month', DATE_TRUNC('month', first_cash_out_date), DATE_TRUNC('month', date)) = X`.

| Metric | Numerator | Denominator | When to use |
|---|---|---|---|
| CO Retention (MX) | `cashed_out_this_month = true` | Total cohort users | Are users continuing to take advances? |
| Active User Retention (MX) | `is_mau = true` | Total cohort users | Are users still on the platform? High Active + low CO Retention = behavioral drop-off, not platform churn. |
| Eligible User Retention (MX) | `user_state IN ('B', 'B2')` (requires join to `shift_pay_user_state_events`) | Active users (`is_mau = true`) | Is drop-off due to lost eligibility (bank issues, employment changes) or behavioral choice? |
| % Active+Eligible with CO (MX) | `cashed_out_this_month = true` | Active + eligible users (`user_state IN ('B', 'B2') AND is_mau = true`) | Of those who *could* take a CO, how many *do*? Sizes the re-engagement opportunity. |

Note: `user_state` is not a native column in `fact_users_by_day` — requires joining to `ext_firehose.shift_pay_user_state_events` on `user_id` + `date`.

### % Mobile Engagement (CO)

Shift active: distinct `user_id` with `shifts > 0` per month from `postgres.shifts` (join to `postgres.jobs` on `owner_id = jobs.id` where `owner_type = 'Job'`). Mobile active: distinct `user_id` with `days_using_the_app > 1` per month from `dbt.fin_ux_events_agg`. Rate = mobile active / shift active.

### Non-Repayment Rate / Loss Rate

Also referred to interchangeably as default rate. Tracked at DX windows: D1, D7, D21, D28, D30, D120. Use D30 for early warning; D120 for final loss rate.

Formula: `1 - COUNT(CASE WHEN paid_back = 1 AND DATEDIFF('day', payback_date, paid_back_date) <= X THEN 1 END) / COUNT(*)` on settled advances. Only include advances where `DATEDIFF('day', payback_date, GETDATE()) > X` (matured past the window).

### Debit Return Rate & NSF Return Rate

Both use `postgres.shift_pay_paybacks` where `delivery_method = 'debit'`.

- **Debit Return Rate:** `COUNT(DISTINCT CASE WHEN status = 'RETURNED' THEN id END) / COUNT(DISTINCT id)`. Captures all bank-side payment failures.
- **NSF Return Rate:** Join to `postgres.shift_pay_transaction_events` on `transaction_id = synapse_transaction_id`. `COUNT(DISTINCT CASE WHEN note LIKE '%20051%' THEN id END) / COUNT(DISTINCT id)`. Isolates insufficient-funds failures (ACH return code R51) from other return reasons.

## P&L Structure

| Line | Definition |
|------|-----------|
| Revenue | Instant delivery fees ($4.99) x # instant COs. Segmented: Core Banks (~60-70%), Neobanks, ConAccess, Dormant |
| COGS | Setup + transaction + connection + platform + support costs |
| Gross Margin | ~63% |
| Losses | Total $ advanced x D120 default rate ($ not paid back after 120 days) |
| Contribution Margin | Revenue - COGS - Losses (~26.5%) |

## Loss Rates by Segment

| Segment | D120 Rate |
|---------|-----------|
| First-time CO users (blended) | ~6.5% |
| Returning CO users (blended) | ~1.9% |
| Neobanks | ~3.8% |
| Overall blended | ~2.0% |

## COGS Breakdown (2026 monthly avg)

| Category | Avg Monthly | % of COGS |
|----------|-------------|-----------|
| Money Movement (Checkout: RTP send, Payouts send, Payments payback) | ~$368K | ~82% |
| User Setup (Plaid) | ~$68K | ~15% |
| Connection — Transaction API (~$0.10/call) | ~$66K | ~15% |
| Connection — Balance Calls (~$0.02/call) | ~$88K | ~20% |
| Support | ~$13K | ~3% |
| **Total COGS** | **~$450K** | |

### Plaid API Cost Drivers

| API | What it does | Volume driver |
|-----|-------------|---------------|
| Auth | Fetches account/routing numbers on bank link/relink | CO enrollments + payroll link events |
| Assets | Fetches asset reports (balances, txns, identity) for underwriting | Eligibility checks + Plaid webhooks + advance creation |
| Transaction (~$0.10) | Checks user txns for payroll detection | CO enrollments with active Plaid connection. 2026: ~630K-786K calls/mo |
| Balance (~$0.02) | Detects sufficient funds for payback collection | Sent frequently D1-D7 (~50 calls/user), then decreasing to D90. 2026: ~4.2M-5.2M calls/mo |

## ARR Calculation

```
ARR = EOM Forecast CO Volumes x Instant % x $4.99 x 12
```

Instant % currently 95.7%.

## Pacing Methodology — Cumulative YoY

1. Track weekly CO volumes by ISO week (Mon-Sun) from Looker. Historical data in `Reference_Tables` sheet (2023-2026).
2. Calculate cumulative YoY growth rate:
   ```
   Cumulative YoY % = (Sum of all complete 2026 weeks) / (Sum of same 2025 weeks) - 1
   ```
3. Forecast future weeks:
   ```
   2026 Week N Forecast = 2025 Week N Actual x (1 + Cumulative YoY %)
   ```
4. Distribute weekly -> daily using DOW weights (from 2025 full-year):

   | Mon | Tue | Wed | Thu | Fri | Sat | Sun |
   |-----|-----|-----|-----|-----|-----|-----|
   | 12.99% | 13.25% | 13.28% | 13.82% | 20.82% | 14.14% | 11.69% |

5. EOM Forecast = Cumulative Actuals + Sum of remaining daily forecasts.
6. Pacing % = EOM Forecast / Monthly Goal.

### 1st-of-Month Multiplier (1.12x)

The 1st of each month runs ~12% above DOW-expected volume.

- Demand side: Rent/bills due at month start -> more advances
- Supply side: Repayment dates cluster around month-end/1st -> CO access resets -> burst of day-1 requests

Validation (11-month backtest): Median ratio 1.124, range 1.057-1.173. Without: 10.8% MAE. With: 3.6% MAE.

**Exceptions:** Do not apply on Jan 1 (New Year's) or Sep 1 when it falls on Labor Day.

## Dashboards (Source of Truth)

### Looker

| Dashboard | Use For | Link |
|-----------|---------|------|
| CO Core Output Metrics (#748) | Daily monitoring: volume, users, enrollments, repayments, user states, D7 activation, neobank %, dormant/continued access | [Looker #748](https://homebase.looker.com/dashboards/748) |
| Non Repayments (#970) | Non-repayment rates, loss rates, maturation (require >=25% cohort maturity) | [Looker #970](https://homebase.looker.com/dashboards/970) |
| CO Enrollment Funnel (#1171) | Enrollment funnel by entry point & platform, completion rates, 3-step funnel, D7 activation by entry point, eligible base | [Looker #1171](https://homebase.looker.com/dashboards/1171) |
| CO Key Input & Output Metrics (#1494) | Business health: revenue by month, MAUs as % of TAM, non-repayment vs benchmarks (FDIC/Dave), enrollment->eligible->active funnel | [Looker #1494](https://homebase.looker.com/dashboards/1494?Source=plaid%2Csynapse%2Ccheckout) |
| Finserv Retention & Activation (#899) | Cohorted retention by first CO month, cuts by bank/tenure/geo/biz type/billing source | [Looker #899](https://homebase.looker.com/dashboards/899?First+Cash+Out+Date+Month=6+month+ago+for+6+month) |

### Amplitude

| Dashboard | Use For | Link |
|-----------|---------|------|
| CO Enrollment Funnel | Screen-level enrollment funnel conversion (directional only) | [Amplitude](https://app.amplitude.com/analytics/homebaseone/dashboard/mkdo3i8v) |

## Amplitude vs Looker Caveats

| Rule | Detail |
|------|--------|
| Looker = source of truth for absolute counts | Snapshot-based; doesn't require users to complete every prior step |
| Amplitude = directional trends only | Strict sequential funnel; users who skip/misfire a step drop out entirely |
| Amplitude samples user journeys | Combined with misfiring events, materially undercounts funnel completion |
| UX events are fragile | Jan 2026 re-instrumentation broke DBT models and Looker metrics. Not suitable as sole source of truth |
| Known Amplitude quirk | Full funnel shows ~4.3% conversion; simplified 2-step (intro->success) shows ~11%, close to Looker |
| IF Amplitude shows a material funnel decline but Looker is flat -> likely an Amplitude issue | Example: Feb 11 2026 enrollment decline was Amplitude artifact, not real |

### Known Data Quirks

- ~4.5K users/month skip PII screen after bank connection, landing directly on Add Debit Card
- Amplitude sometimes doesn't record session events at all (reported by QA, 2/13/26)

## Retention Benchmarks

### Typical Curves (cohorted by first CO month)

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
| D15-D30 | 49.4% | 19.9% | 7.9% | 2.9% |
| D31-D60 | 49.4% | 20.5% | 6.7% | 2.4% |
| D61-D90 | 54.6% | 22.5% | 7.9% | 3.0% |
| D91-D180 | 53.6% | 23.6% | 8.6% | 2.7% |
| D181+ | 53.3% | 23.2% | 8.8% | 2.9% |
| Year+ | 52.3% | 21.8% | 7.7% | 3.3% |

First-week enrollees retain worst. Longer tenure modestly better but converges by M6.

### Other Retention Cuts

| Dimension | Notable |
|-----------|---------|
| Geography | Fairly flat; Far West slightly better (M2: 33.3%), Southeast slightly worse (M2: 27.0%) |
| Business Type | Retail (50.7% M1), Medical (53.3% M1) slightly better; Transportation, Hospitality slightly worse |
| Billing Source | Shopify (M2: 32.1%, M3: 25.6%) and Clover (M2: 30.1%, M3: 19.8%) retain better than HB direct (M2: 29.2%, M3: 18.5%) |

## WBR Data Feeds

| Data Feed | Looker Source | Frequency |
|-----------|--------------|-----------|
| Eligible Base (Shift Active + Mobile Active) | [Look #3136](https://homebase.looker.com/looks/3136) | Weekly |
| Monthly Eligible Base | — | Monthly |
| Weekly Enrollments | [Look #3151](https://homebase.looker.com/looks/3151) | Weekly |
| Monthly Enrollments | [Look #3147](https://homebase.looker.com/looks/3147) | Monthly |
| Weekly Advances (by CO bucket) | [Look #3176](https://homebase.looker.com/looks/3176) | Weekly |
| Monthly Advances | [Look #3148](https://homebase.looker.com/looks/3148) | Monthly |

WBR Source: [WBR Refresh - 2026](https://docs.google.com/spreadsheets/d/1zWO8QiOC2rrj_QUIAnqCEDhMNIzS2PVASmQwxnD8D-s/edit?gid=350728135#gid=350728135) — Sheets: `8. Cash Out`, `Cash Out Data`, `Cash Out Pacing`.
Updated by Strategic Finance. Analytics (Janice) supports pacing questions and number validation.

Pacing sheet: [CO Pacing Model](https://docs.google.com/spreadsheets/d/188uNT9pGntmUsgqqXX0A-HNCru4ZyP4YdTZ02uuLYeQ/edit?gid=174548655#gid=174548655)

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
| Accrual example | [Google Sheets](https://docs.google.com/spreadsheets/d/1f87TaavQLhvFliwNGyTqoMX2kXd22_boWtSf9X6r8pc/edit) |
| Pay Any Day accrual | [Confluence](https://joinhomebase.atlassian.net/wiki/spaces/CO/pages/2482601985) |
| Forecast Model | [FinServ Forecast Model — Cash Out sheet](https://docs.google.com/spreadsheets/d/1OryVpdyJyrNc6fevFoX5tNj5EUUOJiZhGPwKdGHSQ0k/edit?gid=728486487#gid=728486487) |
