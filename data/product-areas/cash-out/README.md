# Cash Out Knowledge Repository

## When to Load Each File

| File | Load when the question involves… |
|------|----------------------------------|
| `co-how-it-works.md` | Product mechanics, eligibility rules, accrual calculation, Cash Out limits, payback logic, delivery methods |
| `co-funnel.md` | Enrollment flow, user states, KYC, comms/messaging cadence, activation, dormant/ConAccess users, retention, segmentation |
| `co-financials.md` | P&L, revenue, COGS, loss rates, pacing methodology, ARR, WBR, forecast |
| `co-metrics.md` | Metric definitions, where to find a number, which dashboard to use, Looker vs Amplitude caveats |
| `co-experiments.md` | Experiment status, results, business impact, strategic bets, what we've tried and learned |

## Rules

- Looker is source of truth for absolute counts. Amplitude is for directional trends only.
- IF user says "active" → ask: paying, engaged, shift active, or payroll active?
- IF question spans multiple files → load all relevant files before answering.

## Source

Originally derived from [Cash Out Key Systems Non-Engineers](https://joinhomebase.atlassian.net/wiki/spaces/EE/pages/2029879340/Cash+Out+Key+Systems+Non-Engineers) (Confluence).
