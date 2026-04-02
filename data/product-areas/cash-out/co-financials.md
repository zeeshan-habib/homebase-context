# Cash Out — Financials & Pacing

## P&L Structure

| Line | Definition |
|------|-----------|
| Revenue | Instant delivery fees ($4.99) × # instant COs. Segmented: Core Banks (~60–70%), Neobanks, ConAccess, Dormant |
| COGS | Setup + transaction + connection + platform + support costs |
| Gross Margin | ~63% |
| Losses | Total $ advanced × D120 default rate ($ not paid back after 120 days) |
| Contribution Margin | Revenue − COGS − Losses (~26.5%) |

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
| Transaction (~$0.10) | Checks user txns for payroll detection | CO enrollments with active Plaid connection. 2026: ~630K–786K calls/mo |
| Balance (~$0.02) | Detects sufficient funds for payback collection | Sent frequently D1–D7 (~50 calls/user), then decreasing to D90. 2026: ~4.2M–5.2M calls/mo |

Zobair working on archiving unused Plaid asset reports to reduce unnecessary webhook-driven fetches (as of Mar 2026).

## 2026 Forecast Summary

| Metric | Jan '26 | Jun '26 | Dec '26 | FY Avg/Mo |
|--------|---------|---------|---------|-----------|
| Revenue | $1.18M | $1.18M | $1.30M | ~$1.21M |
| COGS | $437K | $440K | $478K | ~$450K |
| Gross Margin | 63.0% | 62.8% | 63.1% | ~63% |
| Losses | $440K | $437K | $469K | ~$440K |
| Contribution Margin | $304K | $307K | $348K | ~$323K |
| Contribution Margin % | 25.7% | 25.9% | 26.8% | ~26.5% |
| CO Users | 47,075 | 48,506 | 51,609 | ~48,810 |
| New Enrollments | 17,678 | 21,283 | 24,264 | ~21,663 |
| First-Time CO Users | 7,385 | 8,493 | 9,560 | ~8,882 |
| Total COs Taken | 247K | 263K | 282K | ~267K |
| Total $ Cashed Out | $20.1M | $20.2M | $22.4M | ~$20.9M |
| Blended Loss Rate | 2.07% | 2.04% | 1.98% | ~2.0% |
| Annualized Revenue | $14.2M | $14.2M | $15.5M | ~$14.5M |

Source: [FinServ Forecast Model — Cash Out sheet](https://docs.google.com/spreadsheets/d/1OryVpdyJyrNc6fevFoX5tNj5EUUOJiZhGPwKdGHSQ0k/edit?gid=728486487#gid=728486487)

## ARR Calculation

```
ARR = EOM Forecast CO Volumes × Instant % × $4.99 × 12
```

Instant % currently 95.7%.

## Pacing Methodology — Cumulative YoY (primary, introduced Mar 2026)

1. Track weekly CO volumes by ISO week (Mon–Sun) from Looker. Historical data in `Reference_Tables` sheet (2023–2026).
2. Calculate cumulative YoY growth rate:
   ```
   Cumulative YoY % = (Sum of all complete 2026 weeks) / (Sum of same 2025 weeks) − 1
   ```
   As of Week 9 (ending 3/1/2026): **+3.77%**. Self-corrects as more weeks complete.
3. Forecast future weeks:
   ```
   2026 Week N Forecast = 2025 Week N Actual × (1 + Cumulative YoY %)
   ```
4. Distribute weekly → daily using DOW weights (from 2025 full-year):

   | Mon | Tue | Wed | Thu | Fri | Sat | Sun |
   |-----|-----|-----|-----|-----|-----|-----|
   | 12.99% | 13.25% | 13.28% | 13.82% | 20.82% | 14.14% | 11.69% |

5. EOM Forecast = Cumulative Actuals + Sum of remaining daily forecasts.
6. Pacing % = EOM Forecast / Monthly Goal.

### 1st-of-Month Multiplier (1.12x)

The 1st of each month runs ~12% above DOW-expected volume.

- Demand side: Rent/bills due at month start → more advances
- Supply side: Repayment dates cluster around month-end/1st → CO access resets → burst of day-1 requests

Validation (11-month backtest): Median ratio 1.124, range 1.057–1.173. Without: 10.8% MAE. With: 3.6% MAE.

**Exceptions:** Do not apply on Jan 1 (New Year's) or Sep 1 when it falls on Labor Day.

Implementation: `CO Pacing 2026` sheet column L. Excess (~762 advances) redistributed evenly across remaining days.

Notable: 8/1/2025 set CO single-day record at 13,953 advances.

### Legacy Method (LW) — deprecated

Daily Predicted = (7-days-ago actual) × (W1%/W4% ratio) × (manual adj). Known issues: single data point = high variance, cross-month boundary distortion (17–28% errors in Mar 2026), W1/W4 ratio set to 1.0 (no effect).

Cum YoY avg daily error: **4.6%** vs LW: **21.3%**.

## WBR

Source: [WBR Refresh - 2026](https://docs.google.com/spreadsheets/d/1zWO8QiOC2rrj_QUIAnqCEDhMNIzS2PVASmQwxnD8D-s/edit?gid=350728135#gid=350728135) — Sheets: `8. Cash Out`, `Cash Out Data`, `Cash Out Pacing`

Updated by Strategic Finance. Analytics (Janice) supports pacing questions and number validation.

### WBR Data Feeds

| Data Feed | Looker Source | Frequency |
|-----------|--------------|-----------|
| Eligible Base (Shift Active + Mobile Active) | [Look #3136](https://homebase.looker.com/looks/3136) | Weekly |
| Monthly Eligible Base | — | Monthly |
| Weekly Enrollments | [Look #3151](https://homebase.looker.com/looks/3151) | Weekly |
| Monthly Enrollments | [Look #3147](https://homebase.looker.com/looks/3147) | Monthly |
| Weekly Advances (by CO bucket) | [Look #3176](https://homebase.looker.com/looks/3176) | Weekly |
| Monthly Advances | [Look #3148](https://homebase.looker.com/looks/3148) | Monthly |

### WBR Slide

Output: [WBR Slide Deck](https://docs.google.com/presentation/d/1o9Z-kUMBkiLxneAoLnAtaiYIaB192QvjUa91KS9GXMQ/edit?slide=id.g3cc3fdf9e3a_3_121)

Slide structure: Commentary bullets (key callouts, wins, risks) → Metrics table (Eligible Base, Enrollment & Activation, Usage, Loss Rate) → PoR variance + prior year comparison.

Pacing sheet: [CO Pacing Model](https://docs.google.com/spreadsheets/d/188uNT9pGntmUsgqqXX0A-HNCru4ZyP4YdTZ02uuLYeQ/edit?gid=174548655#gid=174548655)
