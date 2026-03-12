# Cash Out — Metrics & Dashboards

## Key Metric Definitions

| Metric | Definition |
|--------|-----------|
| CO ARR | EOM forecast CO volumes × instant % (95.7%) × $4.99 × 12 |
| CO Users | Unique users who took ≥1 CO in a given month |
| MAU | Monthly active user (took ≥1 CO) |
| First-time CO User | User whose first-ever CO occurred in that month |
| Returning CO User | User with prior CO history who took a CO in that month |
| Activation Rate (first-time) | % of new enrollees who take first CO within period (~42%) |
| D1 / D7 / D28 / D120 Non-Repayment Rate | % of $ advanced not paid back by day N after advance |
| Instant Advance Rate | % of COs taken via instant delivery (~96%) |
| Eligible Base | Shift-active + mobile-active employees eligible for CO |
| Mobile Engagement Rate | % of eligible base engaged on mobile (~69%) |
| Enrollment Completion Rate | Started enrollment → enrolled |
| Eligibility Pass Rate | Enrolled → eligible (passed all rules) |
| CO Retention (MX) | % taking a CO X months after first CO |
| Active User Retention (MX) | % still MAU X months after first CO |

## Looker Dashboards (Source of Truth)

| Dashboard | Use For | Link |
|-----------|---------|------|
| CO Core Output Metrics (#748) | Daily monitoring: volume, users, enrollments, repayments, user states, D7 activation, neobank %, dormant/continued access | [Looker #748](https://homebase.looker.com/dashboards/748) |
| Non Repayments (#970) | Non-repayment rates, loss rates, maturation (require ≥25% cohort maturity) | [Looker #970](https://homebase.looker.com/dashboards/970) |
| CO Enrollment Funnel (#1171) | Enrollment funnel by entry point & platform, completion rates, 3-step funnel, D7 activation by entry point, eligible base | [Looker #1171](https://homebase.looker.com/dashboards/1171) |
| CO Key Input & Output Metrics (#1494) | Business health: revenue by month, MAUs as % of TAM, non-repayment vs benchmarks (FDIC/Dave), enrollment→eligible→active funnel. Filterable by source (Plaid, Synapse, Checkout) | [Looker #1494](https://homebase.looker.com/dashboards/1494?Source=plaid%2Csynapse%2Ccheckout) |
| Finserv Retention & Activation (#899) | Cohorted retention by first CO month, cuts by bank/tenure/geo/biz type/billing source | [Looker #899](https://homebase.looker.com/dashboards/899?First+Cash+Out+Date+Month=6+month+ago+for+6+month) |

## Amplitude Dashboard

| Dashboard | Use For | Link |
|-----------|---------|------|
| CO Enrollment Funnel | Screen-level enrollment funnel conversion (directional only) | [Amplitude](https://app.amplitude.com/analytics/homebaseone/dashboard/mkdo3i8v) |

Owners: Janice Lee, Jon Blackwell. 16 charts covering funnel steps, conversion rates, breakdowns.

## Amplitude vs Looker: Key Caveats

| Rule | Detail |
|------|--------|
| Looker = source of truth for absolute counts | Snapshot-based; doesn't require users to complete every prior step |
| Amplitude = directional trends only | Strict sequential funnel; users who skip/misfire a step drop out entirely |
| Amplitude samples user journeys | Combined with misfiring events, materially undercounts funnel completion |
| UX events are fragile | Jan 2026 re-instrumentation broke DBT models and Looker metrics. Not suitable as sole source of truth |
| Known Amplitude quirk | Full funnel shows ~4.3% conversion; simplified 2-step (intro→success) shows ~11%, close to Looker |
| IF Amplitude shows a material funnel decline but Looker is flat → likely an Amplitude issue | Example: Feb 11 2026 enrollment decline was Amplitude artifact, not real |

Sources: [Investigation (2/20/26)](https://pioneerworks.slack.com/archives/C0AG5RM0G8M/p1771621239431059) | [Summary (2/23/26)](https://pioneerworks.slack.com/archives/C0AG5RM0G8M/p1771864995688289)

### Known Data Quirks

- ~4.5K users/month skip PII screen after bank connection, landing directly on Add Debit Card ([Slack 2/10/26](https://pioneerworks.slack.com/archives/C092VCS8GP6/p1770765892029319))
- Amplitude sometimes doesn't record session events at all (reported by QA, 2/13/26)

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
| Accrual example | [Google Sheets](https://docs.google.com/spreadsheets/d/1f87TaavQLhvFliwNGyTqoMX2kXd22_boWtSf9X6r8pc/edit) |
| Pay Any Day accrual | [Confluence](https://joinhomebase.atlassian.net/wiki/spaces/CO/pages/2482601985) |
| Enrollment details & drop-off | [Google Slides](https://docs.google.com/presentation/d/11zc1gAD3OQlPmrOt7PasICe0NOVaIi2Wt6T-8w0Q5Ms/edit) |
