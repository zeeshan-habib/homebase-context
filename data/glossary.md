# Metrics Glossary

Canonical index of all analytics-approved metric definitions at Homebase. For product terms and acronyms, see `global/glossary.md` instead.

| Metric | Definition | Data Source | Details | Domain | Category |
|---|---|---|---|---|---|
| ARR | Annualized Run Rate. MRR x 12. Primary top-line revenue metric. | `price` in `public.fact_locations_by_day`; company-level in `dbt.fin_product_monthly_revenue` | | Company-wide | Revenue |
| MRR | Monthly Recurring Revenue. Total subscription and recurring revenue in a given month. | `price` in `public.fact_locations_by_day`; `dbt.fin_product_monthly_revenue` | | Company-wide | Revenue |
| Gross Annualized Revenue | Total ARR across all products. Headline top-line metric in the WBR Summary slide. | | | Company-wide | Revenue |
| ARR Growth (YoY %) | Year-over-year percentage growth in Gross Annualized Revenue. | | | Company-wide | Revenue |
| New Location MRR $ | MRR added from brand-new paying locations in a given period. | | | Company-wide | Revenue |
| ASP | Average Selling Price. Revenue per paying company or location. Tracked for new and blended. | | | Company-wide | Revenue |
| Net Churn $ | $ Existing Customer Upgrade (Reactivation + Tier Expansion + Location Expansion) minus $ Existing Customer Downgrade (Downgrade to Basic + Tier Contraction). | | | Company-wide | Revenue |
| Net Churn % | ($ Upgrade - $ Downgrade) / Prior Month End-of-Period Total MRR. | | | Company-wide | Revenue |
| Unique Paying Companies | Unique Team App, Payroll, and Hiring-paying companies. A single company paying for multiple products counted once. | `dbt.fin_product_monthly_revenue` or `public.fact_companies_by_day` | | Company-wide | Revenue |
| New Paying Companies | First-time paying locations. Excludes reactivations. | | | Company-wide | Revenue |
| NRR excl. XS | Net Revenue Retention excluding expansion. Revenue today from companies paying 1 year ago vs. revenue from the same cohort 1 year ago. | | | Company-wide | Revenue |
| Avg. ASP / Paying Company | Gross Annualized ARR divided by the number of unique paying companies. | | | Company-wide | Revenue |
| Avg. # Products / Paying Company | (TA Paying Cos + Payroll Paying Cos + Hiring Cos) / Unique Paying Cos. Measures cross-sell depth. | | | Company-wide | Revenue |
| Engaged (Core) | Location with (TT OR scheduling engaged, 7d) AND OAM activity (30d). Default meaning of "active." | `engagement_boolean` in `bizops.product_location_engagement_metrics` | [engagement-metrics.md](engagement-metrics.md) | Company-wide | Engagement |
| Engaged Locations (7-day) | Locations actively using Homebase in the past 7 days. | `engagement_boolean` in `bizops.product_location_engagement_metrics` | [engagement-metrics.md](engagement-metrics.md) | Company-wide | Engagement |
| Engaged Locations (30-day) | Locations actively using Homebase in the past 30 days. | `engagement_boolean` in `bizops.product_location_engagement_metrics` | [engagement-metrics.md](engagement-metrics.md) | Company-wide | Engagement |
| % of Paying Locs Engaged | Percentage of paying locations that are also 30-day active. Product health and retention risk measure. | | [engagement-metrics.md](engagement-metrics.md) | Company-wide | Engagement |
| Engaged 30d Retention | Percentage of 30-day engaged locations that remain engaged in the following 30-day period. | | [engagement-metrics.md](engagement-metrics.md) | Company-wide | Engagement |
| OAM Activity Engaged | Any Owner, Admin, or Manager activity in the product. 30-day lookback. | `oam_activity_boolean` in `bizops.product_location_engagement_metrics` | [engagement-metrics.md](engagement-metrics.md) | Company-wide | Engagement |
| HR Docs Engaged | Use of digital onboarding/document management. Threshold: any of three most recent hires has an onboarding doc. Company-level. | `hrdocs_engaged_boolean` in `bizops.product_company_engagement_metrics` | [engagement-metrics.md](engagement-metrics.md) | Company-wide | Feature Engagement |
| Messaging Engaged | Use of team communication. 7d lookback. 10+ messages OR 20%+ of roster sent a message. Company-level. | `messaging_engaged_boolean` in `bizops.product_company_engagement_metrics` | [engagement-metrics.md](engagement-metrics.md) | Company-wide | Feature Engagement |
| Signups | New companies created on Homebase in a given period. Top of the acquisition funnel. | `public.companies` | [activation-metrics.md](activation-metrics.md) | Company-wide | Activation |
| 1D1 | 1-Day 1-Action. Company completes at least one meaningful action (invite + employee login) within 24h of signup. Core acquisition metric. | `signup_1d1` in `public.companies` | [activation-metrics.md](activation-metrics.md) | Company-wide | Activation |
| 1D1s % of Signups | Percentage of signups that achieve a 1D1 activation. Typically ~19-20%. | | [activation-metrics.md](activation-metrics.md) | Company-wide | Activation |
| 2D7 | Active on 2 different days within 7-day window, with at least one employee activity each day. | `signup_2d7` in `public.companies`; `twod7_active_today_location` in `dbt.active_paying_history_for_looker` | [activation-metrics.md](activation-metrics.md) | Company-wide | Activation |
| 2D30 | Same as 2D7 but within a 30-day window. | `signup_2d30` in `public.companies`; `two_d_thirty_active_this_month_location` in `dbt.active_paying_history_for_looker` | [activation-metrics.md](activation-metrics.md) | Company-wide | Activation |
| Activated | Location that first published a schedule OR created a timecard. | | [activation-metrics.md](activation-metrics.md) | Company-wide | Activation |
| Wk1 2D7 Rate | Percentage of signups from a given week that engage meaningfully within 7 days. Early monetization signal. | | [activation-metrics.md](activation-metrics.md) | Company-wide | Activation |
| D17 Engaged Rate | Percentage of signups that are engaged by day 17. | | [activation-metrics.md](activation-metrics.md) | Company-wide | Activation |
| D17 Paying Rate | Percentage of signups that become paying customers by day 17. | | [activation-metrics.md](activation-metrics.md) | Company-wide | Activation |
| D30 Paying % of 1D1 | Percentage of 1D1 users who become paying by day 30. Key monetization efficiency metric. | | [activation-metrics.md](activation-metrics.md) | Company-wide | Activation |
| D30 MRR / 1D1 | MRR generated per 1D1 user by day 30. Revenue yield of the acquisition funnel. | | [activation-metrics.md](activation-metrics.md) | Company-wide | Activation |
| M1 Upgrades | Locations that upgrade to a paid plan in their first month after signup. | | [activation-metrics.md](activation-metrics.md) | Company-wide | Activation |
| M2 Upgrades | Locations that upgrade in their second month. Graduate from Early Life into the Base. | | [activation-metrics.md](activation-metrics.md) | Company-wide | Activation |
| Time Tracking Engaged | 3+ timecards OR 20%+ of roster with a timecard in 7d. At least one must belong to an employee. | `time_tracking_engaged_boolean` in `bizops.product_location_engagement_metrics` | [engagement-metrics.md](engagement-metrics.md) | Time Tracking | Feature Engagement |
| Mobile Time Tracking Engaged | 3+ mobile timecards OR 20%+ of roster with a mobile timecard in 7d. | `mobile_time_tracking_engaged_boolean` in `bizops.product_location_engagement_metrics` | [engagement-metrics.md](engagement-metrics.md) | Time Tracking | Feature Engagement |
| Overtime Preferences Engaged | Overtime settings enabled, Essentials+ plan, and TT engaged. 7d lookback. | `overtime_preferences_engaged_boolean` in `bizops.product_location_engagement_metrics` | [engagement-metrics.md](engagement-metrics.md) | Time Tracking | Feature Engagement |
| Break Preferences Engaged | 1+ mandatory break type enabled and TT engaged. 7d lookback. | `break_preferences_engaged_boolean` in `bizops.product_location_engagement_metrics` | [engagement-metrics.md](engagement-metrics.md) | Time Tracking | Feature Engagement |
| Geofencing Engaged | Proximity enforcement enabled, Essentials+ plan, and mobile TT engaged. 7d lookback. | `geofencing_engaged_boolean` in `bizops.product_location_engagement_metrics` | [engagement-metrics.md](engagement-metrics.md) | Time Tracking | Feature Engagement |
| Wk1 TT Engaged % | Percentage of new signups engaging with Time Tracking in their first week. | | | Time Tracking | WBR |
| Scheduling Engaged | Active use of scheduling features. 7d lookback. | `scheduling_engaged_boolean` in `bizops.product_location_engagement_metrics` | [engagement-metrics.md](engagement-metrics.md) | Scheduling | Feature Engagement |
| Shift Trades Engaged | Active use of shift trades. 7d lookback. | `shift_trades_engaged_boolean` in `bizops.product_location_engagement_metrics` | [engagement-metrics.md](engagement-metrics.md) | Scheduling | Feature Engagement |
| Time Offs Engaged | 2+ time off requests OR 10%+ of roster with a request. 7d lookback. | `time_offs_engaged_boolean` in `bizops.product_location_engagement_metrics` | [engagement-metrics.md](engagement-metrics.md) | Scheduling | Feature Engagement |
| Shift Notes Engaged | Active use of shift notes. 7d lookback. | `shift_notes_engaged_boolean` in `bizops.product_location_engagement_metrics` | [engagement-metrics.md](engagement-metrics.md) | Scheduling | Feature Engagement |
| Department Management Engaged | Dept scheduling/permissions usage. 8d lookback. Plus+ with dept pageview OR dept permissions enabled with manager and scheduling engaged. | `department_management_engaged_boolean` in `bizops.product_location_engagement_metrics` | [engagement-metrics.md](engagement-metrics.md) | Scheduling | Feature Engagement |
| Manager Log Engaged | 2+ manager log posts OR 20%+ of managers posted. 7d lookback. | `manager_log_engaged_boolean` in `bizops.product_location_engagement_metrics` | [engagement-metrics.md](engagement-metrics.md) | Scheduling | Feature Engagement |
| CO ARR | Annualized revenue from Cash Out instant advance fees ($4.99 each). Primary FinServ revenue metric. | `fee_in_dollars` in `public.cashout_advances` | [cash-out/](product-areas/cash-out/) | Cash Out | Revenue |
| Instant Advance Rate % | Percentage of Cash Out advances taken as instant (paid) vs. free. Typically ~95-97%. | | [cash-out/](product-areas/cash-out/) | Cash Out | Feature Engagement |
| Avg. CO / User | Average Cash Out advances per active user in a period. Engagement/repeat usage measure. | | [cash-out/](product-areas/cash-out/) | Cash Out | Feature Engagement |
| % Mobile Engagement (CO) | Percentage of the eligible employee base actively using the Homebase mobile app. | | [cash-out/](product-areas/cash-out/) | Cash Out | Feature Engagement |
| Non-Repayment Rate / Loss Rate | Percentage of Cash Out advances not repaid by X days after due date. Tracked at D1, D7, D21, D28, D30, D120. | `public.cashout_advances` | [cash-out/](product-areas/cash-out/) | Cash Out | Risk |
| Debit Return Rate | Rate at which ACH debit repayment attempts are returned by the bank. Typically ~45-50%. | | [cash-out/](product-areas/cash-out/) | Cash Out | Risk |
| Payroll Opportunity (Opp) | A qualified lead for Homebase Payroll. Tracked through Early Life, Base, and Clover segments. | | | Payroll | Funnel |
| Transfer Start | Payroll prospect that has initiated payroll setup/migration. | | | Payroll | Funnel |
| Ran Payroll | Company that has run at least one payroll on Homebase. Primary Payroll activation event. | | | Payroll | Activation |
| D7 Opps > TS CvR (%) | 7-day conversion rate from Payroll Opportunity Created to Transfer Start. | | | Payroll | Funnel |
| Win Rate (Payroll) | Percentage of Payroll Opportunities that result in a Transfer Start. | | | Payroll | Funnel |
| Payroll PQL % | Product-Qualified Lead percentage. Share of new signups showing behavior indicating payroll intent. | | | Payroll | Funnel |
| Hiring Engaged | 10+ hiring events (job posts, applicant views, etc.). 30d lookback. | `hiring_engaged_boolean` in `bizops.product_location_engagement_metrics` | [engagement-metrics.md](engagement-metrics.md) | Hiring | Feature Engagement |
| New Trials (Hiring) | New locations that started a Hiring product trial. | | | Hiring | Funnel |
| Trial : Pay % (D14) | Percentage of Hiring trial starts that convert to paying by Day 14. | | | Hiring | Funnel |
| % Jobs Healthy by Day 5 | Percentage of new job postings with 20+ applicants and 5+ top matches by Day 5. | | | Hiring | Activation |
| New Embedded Activation | Clover merchant accessing Homebase timesheet on clover.com for the first time. Tracked as Front Book and Back Book. | | | Clover | Activation |
| Blended ROAS | D30 MRR x 36 months (est. 3-year LTV) / (direct paid + test + adhoc + direct mail spend). | | | Marketing/GTM | Revenue |
| D30 ROAS (Blended) | Return on Ad Spend using D30 MRR as revenue numerator. Lagged 1-month efficiency metric. | | | Marketing/GTM | Revenue |
| CPA | Cost Per Acquisition. Direct cost (via API from ad vendor) / acquisition metric. | | | Marketing/GTM | Revenue |
| Blended 1D1 CPA | Total paid + test spend / total 1D1 activations (including Clover Embedded). Primary paid marketing efficiency metric. | | | Marketing/GTM | Revenue |
| Paid Core 1D1 CPA | Core paid spend / 1D1 activations from those channels only. | | | Marketing/GTM | Revenue |
| Channel Normalized Score | Composite score normalizing performance across acquisition channels for WoW comparison. | | | Marketing/GTM | WBR |
