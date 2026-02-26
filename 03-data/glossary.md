**Homebase**  
Analytics & Product Glossary

*Sources: WBR Q1 2026 (Google Slides)  •  Slack: \#data-desk, \#ee-bizops-priorities, \#cashout-data-science, \#ee-leads, \#finance-analytics  •  Compiled February 2026*

| Metric / Term | Definition | Data Location |
| :---- | :---- | :---- |
| **📋  WBR / MBR Definitions** |  |  |
| **WBR** | Weekly Business Review. A recurring meeting and shared Google Slides deck where key company metrics are reviewed every week. Tracks ARR, enrollment, non-repayment rates, pacing vs. PoR, and more across all product lines. | |
| **MBR** | Monthly Business Review. The monthly equivalent of the WBR. Includes OKR progress and is presented to the exec team. |  |
| **PoR** | Plan of Record. The official annual plan set at the start of the year (e.g., set in Jan '26). The primary variance benchmark throughout the WBR. |  |
| **PW Fcst** | Prior Week Forecast. The ARR forecast from the previous week's WBR, used to measure week-over-week forecast changes. |  |
| **T4 Wk** | Trailing 4-Week Average. The average of the past 4 weeks, excluding the current week. Used to smooth out weekly noise in metrics. |  |
| **DX (e.g. D30, D60)** | Metric on day X of that company's life — exactly 30 days after they sign up. Used for cohort analysis on monetization, activation, and loss rates. |  |
| **Unique Paying Companies** | Unique Team App, Payroll, and Hiring-paying companies. A single company paying for multiple products is counted only once. Primary top-line customer count metric. |dbt.fin_product_monthly_revenue or paying in public.fact_companies_by_day |
| **New Paying Companies** | First-time paying locations. Excludes reactivations. |  |
| **NRR excl. XS** | Net Revenue Retention, excluding expansion. Total revenue received today from companies that were paying 1 year ago for Team App, vs. the total revenue received 1 year ago from the same cohort. |  |
| **Avg. ASP / Paying Company** | Gross Annualized ARR divided by the number of unique paying companies. |  |
| **Avg. \# Products / Paying Company** | (Team App Paying Cos \+ Payroll Paying Cos \+ Hiring Cos) / Unique Paying Cos. Measures cross-sell depth. |  |
| **Blended ROAS** | Day 30 MRR of all products × 36 months (estimated 3-year LTV), divided by direct paid ad spend \+ Test \+ Adhoc \+ Direct Mail spend. |  |
| **CPA** | Cost Per Acquisition. Direct cost (via API pull from an ad vendor) divided by the acquisition metric (e.g., 1D1, Paying Location — see WBR footnotes for context). |  |
| **Net Churn $** | $ Existing Customer Upgrade (Reactivation \+ Tier Expansion \+ Location Expansion) minus $ Existing Customer Downgrade (Downgrade to Basic \+ Tier Contraction). |  |
| **Net Churn %** | ($ Existing Customer Upgrade − $ Existing Customer Downgrade) / Prior Month End-of-Period Total MRR. |  |
| **DRI** | Directly Responsible Individual. Each WBR slide has a named DRI for the metric and a separate Analytics DRI. |  |
| **💰  Revenue & Finance Metrics** |  |  |
| **ARR** | Annualized Run Rate. MRR × 12\. Primary top-line revenue metric. For Cash Out, derived from instant advance fees ($4.99 each). |  |
| **MRR** | Monthly Recurring Revenue. Total subscription and recurring revenue in a given month. Broken out by product (Team App, Payroll, Cash Out, Hiring, Clover Embedded, etc.). | Can be found in price column in public.fact_locations_by_day or at the company level in dbt.fin_product_monthly_revenue|
| **Gross Annualized Revenue** | Total ARR across all products. The headline top-line metric in the WBR Summary slide. |  |
| **ARR Growth (YoY %)** | Year-over-year percentage growth in Gross Annualized Revenue. |  |
| **New Location MRR $** | MRR added from brand-new paying locations in a given period. |  |
| **ASP** | Average Selling Price. Revenue per paying company or location. Tracked as ASP for new paying locations and as blended ASP across all paying locations. |  |
| **WoW** | Week over Week. Percentage or dollar change vs. the prior week. |  |
| **YoY** | Year over Year. Percentage or dollar change vs. the same period last year. |  |
| **MoM** | Month over Month. Percentage change vs. the prior month. |  |
| **MTD** | Month to Date. Accumulated metric value from the start of the current month. |  |
| **Fcst** | Forecast. Current month-end projection, updated weekly in the WBR. |  |
| **vtg % / Var (%)** | Variance to Goal / Variance to PoR. How actual or forecasted results differ from the Plan of Record. |  |
| **PY / Prior Year** | Prior Year actuals, used as a YoY comparison benchmark in WBR tables. |  |
| **EoP MRR** | End-of-Period MRR. The MRR balance at the end of a given month. |  |
| **📊  Activation & Conversion Metrics** |  |  |
| **1D1** | 1-Day 1-Action Activation. A user or location that completes at least one meaningful product action within the first 24 hours after sign-up. Core marketing acquisition metric uploaded to Google and Bing for conversion tracking. pLTV score is incorporated after day 8\. | signup\_1d1 \= ‘true’ in public.companies table  |
| **Signups** | New accounts or locations that registered on Homebase in a given period. The top of the acquisition funnel. Tracked weekly in the WBR alongside 1D1s. | public.companies |
| **1D1s % of Signups** | The percentage of signups that achieve a 1D1 activation. Typically around 19–20%. |  |
| **2D7** | Activity within the first 2 and 7 days after sign-up. Used in ad platform uploads (Google/Bing) alongside 1D1 for cohort quality tracking. | signup_2d7 column in public.companies |
| **24H / 7D** | Renamed Looker fields for first-24-hour and first-7-day activity, previously named \_24 and \_7. |  |
| **Wk1 2D7 Rate** | Percentage of signups from a given week that engage meaningfully within 7 days. An early signal of monetization potential tracked in the Team App funnel. |  |
| **D17 Engaged Rate** | Percentage of signups that are engaged (actively using the product) by day 17\. |  |
| **D17 Paying Rate** | Percentage of signups that become paying customers by day 17\. |  |
| **D30 Paying % of 1D1** | Percentage of 1D1 users who become a paying location by day 30 from signup. A key monetization efficiency metric. |  |
| **D30 MRR / 1D1** | Monthly Recurring Revenue generated per 1D1 user by day 30 from signup. Measures revenue yield of the acquisition funnel. |  |
| **D30 ROAS (Blended)** | Return on Ad Spend using D30 MRR as the revenue numerator. A lagged (1 month) efficiency metric. |  |
| **M1 Upgrades** | Locations that upgrade to a paid plan in their first month (Month 1\) after signup. |  |
| **M2 Upgrades** | Locations that upgrade in their second month. These graduate from the Early Life bucket into the Base. |  |
| **Pacing** | A daily/weekly process tracking CO volume, ARR, and non-repayment rates against the monthly PoR goal. Published regularly in \#ee-leads. |  |
| **🏢  Team App & Payroll Funnel** |  |  |
| **Team App** | Homebase's core HR SaaS product — scheduling, time tracking, team messaging, HR docs, team management. Also referred to as 'TA' or 'Core'. |  |
| **Early Life (EL)** | Locations or companies that signed up within the past \~60 days. Tracked separately from 'Base' to monitor new customer monetization. |  |
| **Base** | Locations or companies that signed up more than \~60 days ago. Tracked for upgrades, downgrades, and expansion revenue. |  |
| **Base Engaged Locations** | The number of Base (non-early-life) paying locations that are actively engaging with the Homebase product. |  |
| **Paying Locations** | Locations actively paying for one or more Homebase products. Primary unit of measurement for Team App, Clover Embedded, and Hiring. |  |
| **Payroll Opportunity (Opp)** | A qualified lead for Homebase Payroll. Tracked through Early Life, Base, and Clover segments. |  |
| **Transfer Start** | A Payroll prospect that has initiated payroll setup/migration (started transferring payroll data to Homebase). |  |
| **Ran Payroll** | A company that has successfully run at least one payroll on Homebase. Primary activation/conversion event for Payroll. |  |
| **D7 Opps \> TS CvR (%)** | 7-day conversion rate from Opportunity Created to Transfer Start. Key sales efficiency metric in the Payroll funnel. |  |
| **Win Rate** | Percentage of Payroll Opportunities that result in a Transfer Start. |  |
| **Payroll PQL %** | Payroll Product-Qualified Lead percentage. Share of new signups showing product behavior indicating payroll intent, used by the sales team as a lead signal. |  |
| **Employee MRR / EE MRR** | MRR from per-employee pricing in Payroll. Separate from company-level Payroll MRR. |  |
| **Employee Contraction** | Reduction in Employee MRR, typically due to companies reducing headcount or removing employees from payroll. |  |
| **Workers Comp** | Workers' Compensation insurance revenue, a component of Payroll ARR. |  |
| **Bundles (Team App \+ Payroll)** | A bundled pricing product where companies pay for both Team App and Payroll together. Reported with its own ARR line in the WBR. |  |
| **DIFOT %** | Delivered In Full, On Time. Payroll implementation/onboarding metric measuring whether new payroll setups are completed on schedule. |  |
| **💸  Cash Out (CO) Metrics** |  |  |
| **Cash Out (CO)** | Homebase's Earned Wage Access (EWA) product. Employees connect their bank account via Plaid and can take advances on earned wages during the pay period. Free advances take 1–3 business days; instant advances cost $4.99. |  |
| **EWA** | Earned Wage Access. The industry term for products like Cash Out, where employees access earned wages before payday. |  |
| **COs (count)** | The total number of Cash Out advances taken in a given period. |  |
| **CO ARR** | Annualized revenue from Cash Out instant advance fees. Primary revenue metric for the financial services team. | fee_in_dollars column in public.cashout_advances |
| **Instant Advance Rate %** | Percentage of CO advances taken as instant (paid) vs. free standard delivery. Typically \~95–97%. |  |
| **Avg. CO / User** | Average number of Cash Out advances per active user in a given period. A measure of engagement and repeat usage. |  |
| **Total CO Users** | Total active Cash Out users who have taken at least one advance in the measurement period. | user_id in public.cashout_advances |
| **New Enrollments** | New users who successfully completed CO enrollment (connected bank via Plaid, passed eligibility and risk checks). | users count from postgres.shift_pay_eligibilities where triggered_by = 'enrollment' |
| **New First Time Users** | Enrolled users who took their very first Cash Out advance in a given period. |  |
| **% First Time Activation** | New First Time Users as a percentage of New Enrollments. Measures how quickly newly enrolled users take their first advance. |  |
| **Eligible EEs (Mobile \+ Shift Active)** | The pool of employees currently eligible to enroll in CO: they use the mobile app and have recent shift activity. |  |
| **% Mobile Engagement** | Percentage of the eligible EE base actively using the Homebase mobile app. |  |
| **Portability Users** | CO users who have portability enabled — they can use Cash Out across different employers/companies. |  |
| **Enrollment (CO)** | The process of signing up for Cash Out: connecting a bank account via Plaid and passing eligibility and risk rules. |  |
| **Eligibility** | The set of rules a user must pass to take a CO advance (bank balance, hours worked, risk score). Checked via the Eligibility Engine after enrollment, on Plaid webhooks, and every 24 hours. |  |
| **Eligibility Pass Rate** | Percentage of users who pass all eligibility rules. Can be broken into rules-only, risk model, and combined pass rates. |  |
| **Activation Quality** | Rate at which enrolled CO users actually take advances. Measures users enrolled in the past 30 days who have taken at least one CO. |  |
| **Non-Repayment Rate** | Percentage of CO advances not repaid by a given number of days after the due date. Key risk metric tracked at D1, D7, D21, D28, D30, and D120. |  |
| **D28 Loss Rate %** | Non-repayment rate 28 days after the advance due date. Primary risk/loss metric in the WBR Cash Out slide. |  |
| **D1 / D7 / D21 / D30 / D120** | Non-repayment rate N days after the expected repayment date. D30 is the stabilized signal; D120 represents ultimate loss. E.g., D1 default \= not paid back as of 1 day past due. |  |
| **Non-Repayment Maturation Curve** | A curve showing how non-repayment rates evolve over time after an advance due date. Roughly stabilizes at D30. |  |
| **NSF (Non-Sufficient Funds)** | A bank return code indicating insufficient funds for the debit repayment. Return code 20051\. \~15–20% of NSF users repay within 10 days. |  |
| **Return Code 20051** | Checkout/ACH return code for a standard NSF decline. |  |
| **Return Code 20179** | 'Invalid card data' return code (Rec Code 02 \= try again later). Predominantly Capital One. Treated like NSF in rules, but only \~3% recovery rate vs. \~15–20% for NSF. |  |
| **Debit Return Rate** | Rate at which ACH debit repayment attempts are returned by the bank (NSF, 20179, or other codes). |  |
| **RTP Balance** | Real-Time Payments account balance. Homebase's Plaid-managed account used to fund instant Cash Out advances. Monitored daily for liquidity. |  |
| **Checkout Funds (Available \+ Operational)** | Funds in Homebase's Checkout (CKO) processor accounts, tracked daily for liquidity management. |  |
| **👤  Cash Out User States** |  |  |
| **A3** | User has $0 available balance — stuck in a zero-balance state. Often surfaces in accrual tracking. |  |
| **C2** | A pending advance has not yet settled. No repay button is shown because the advance hasn't been guaranteed via settlement. |  |
| **D4** | User is failing eligibility rules after enrollment. Common for Chime/neobank users. Team explored allowing users to 'self-heal' by re-connecting a bank account. |  |
| **D6** | A KYC failure state. Caused by invalid user data (bad phone, email, or address) preventing Plaid from creating a KYC record. |  |
| **🍀  Clover Embedded** |  |  |
| **Clover Embedded** | A distribution channel where Homebase timesheets are embedded directly in the Clover POS. Eligible merchants can use Homebase without signing up separately. A merchant is 'activated' once they access the Homebase timesheet on clover.com (via OAuth). |  |
| **Front Book (Clover)** | New Clover merchants who signed up after the embedded distribution agreement was in place. Expected to activate at higher rates. |  |
| **Back Book (Clover)** | Existing Clover merchants retroactively made eligible for embedded. Targeted via win-back campaigns. |  |
| **New Embedded Activation** | A Clover merchant that accesses the Homebase timesheet on clover.com for the first time. Tracked as Front Book and Back Book. |  |
| **Rev Share / Revenue Share** | Revenue shared with Clover based on activated embedded merchants. Qualification tracked via 'Rev Share Qualified Locs.' |  |
| **Dormant Eligible** | Clover segment: merchants who are embedded-eligible but have little/no engagement and haven't activated. Focus of win-back efforts. |  |
| **Activation-Ready** | Clover segment: merchants active on Homebase but not yet embedded-activated. Highest-probability pool to convert to embedded. |  |
| **Expansion-Ready** | Clover segment: embedded-activated merchants with sustained usage. Focus is driving incremental MRR via plan upgrades, payroll attach, and add-ons. |  |
| **2D30 Active / Inactive** | Clover segmentation: whether a merchant has been active within 30 days of their 2nd day. Used to classify embedded eligible locations. |  |
| **📋  Hiring** |  |  |
| **Hiring** | Homebase's job posting and applicant matching product. Tracks trial starts, trial-to-pay conversion, and paying location ARR. |  |
| **New Trials (Hiring)** | New locations that started a trial of the Hiring product. |  |
| **Trial : Pay % (D14)** | Percentage of Hiring trial starts that convert to a paying subscription by Day 14\. |  |
| **% Jobs Healthy by Day 5** | Percentage of new job postings with 20+ applicants and 5+ top matches by Day 5 of activation. Key job quality signal. |  |
| **📣  GTM & Marketing Metrics** |  |  |
| **GTM** | Go-to-Market. Covers marketing, sales, and partner channels. WBR has dedicated GTM – Marketing, GTM – PLG, and GTM – Sales slides. |  |
| **Paid (Incl. Test)** | Paid marketing spend covering core paid channels (Google, Bing, iOS, PMax) plus test/experimental channels (Affiliates, YouTube, Reddit, Direct Mail, Meta). |  |
| **Organic 1D1s** | 1D1 activations from non-paid channels (SEO, word of mouth, direct). |  |
| **Partner 1D1s** | 1D1 activations from partner channels (e.g., Clover non-embedded, other integrations). |  |
| **Paid Core Spend** | Spend on core Google, Bing, iOS, and PMax campaigns. Excludes test/experimental spend. |  |
| **Test Spend** | Spend on experimental channels: Affiliates, YouTube, Reddit, Direct Mail, Meta, and other tests. |  |
| **Blended 1D1 CPA** | Total paid \+ test spend divided by total 1D1 activations (including Clover Embedded). Primary paid marketing efficiency metric. |  |
| **Paid Core 1D1 CPA** | Core paid spend divided by 1D1 activations from those channels only. |  |
| **PLG** | Product-Led Growth. WBR tracks PLG metrics like 2D7 rate, schedule-engaged %, time-tracking-engaged %, and payroll PQL rate. |  |
| **Wk1 Schedule Engaged %** | Percentage of new signups that engage with the scheduling feature in their first week. |  |
| **Wk1 TT Engaged %** | Percentage of new signups that engage with Time Tracking in their first week. |  |
| **Channel Normalized Score** | A composite score normalizing performance across different acquisition channels for WoW comparison. |  |
| **💬  Customer Health & Support** |  |  |
| **NPS** | Net Promoter Score. Tracks customer satisfaction/loyalty on a rolling 30-day basis. Target is 40 |  |
| **iCSAT** | Interaction Customer Satisfaction score. Measured for human support interactions (phone, chat, email). Tracked weekly and monthly in the WBR. |  |
| **Engaged Locations (7-day)** | Number of locations that have actively used Homebase in the past 7 days. |  |
| **Engaged Locations (30-day)** | Number of locations that have actively used Homebase in the past 30 days. |  |
| **% of Paying Locs Engaged** | Percentage of total paying locations that are also 30-day active. A measure of product health and retention risk. |  |
| **Engaged 30d Retention** | Percentage of 30-day engaged locations that remain engaged in the following 30-day period. |  |
| **Interactions Initiated** | Total support calls, chats, and emails started by customers (across Team App, Payroll, and EE). |  |
| **% Escalated to Human** | Percentage of all support interactions that required a human agent. |  |
| **SLA: Phone (90s)** | Percentage of inbound calls answered within 90 seconds. Target is 80%. |  |
| **SLA: Chat (60s)** | Percentage of inbound chats responded to within 60 seconds. Target is 80%. |  |
| **Sierra** | Homebase's AI support bot/agent. Tracked via containment rate (tickets resolved without human transfer) and tickets per engaged location. |  |
| **Sierra Containment Rate** | Percentage of Sierra-handled tickets fully resolved without transfer to a human agent. |  |
| **🗄️  Data & Analytics Terms** |  |  |
| **pLTV** | Predicted Lifetime Value. An ML score predicting the long-term revenue value of a user or signup. Generated 6–8 days after sign-up. Used in Google/Bing ad platform uploads as a conversion value. |  |
| **APH (Active Paying History)** | Core Homebase data table tracking which locations are active and paying. Referenced in Looker as active\_paying\_history\_v2. |  |
| **OAM** | Owner, Admin, or Manager. The business-side user role in Homebase (vs. EE/employee). Used in engagement metrics like Engaged Locations and OAM message volume. |  |
| **EE** | Employee. An employee-level Homebase user. Heavily referenced in Cash Out context — EEs enroll in and take advances. |  |
| **NHP (New Hire Packet/Process)** | The new employee onboarding flow. Tracked as a completion rate (% of new hires completing NHP). |  |
| **FTUX** | First-Time User Experience. Onboarding UI shown the first time a user accesses a feature (e.g., first Cash Out modal). |  |
| **Cohort Analysis** | Analysis of user or location behavior grouped by when they signed up or first took an action. Used extensively for non-repayment maturation and degradation trend analysis. |  |
| **Looker** | Homebase's primary BI/dashboarding tool |  |
| **Amplitude** | Product analytics platform used for in-product event tracking and funnel analysis. |  |
| **Firehose** | The current mobile event data pipeline. Replaced the legacy mobile\_trackers table. |  |
| **🏦  Partners & Infrastructure** |  |  |
| **Plaid** | Bank data aggregation and identity verification provider. Used for bank account connection during CO enrollment, transaction history for eligibility, KYC verification, and RTP account management. |  |
| **Checkout / CKO** | Homebase's payment processor for ACH debits (repayments) and credits (advances). Source of return codes 20051 and 20179\. |  |
| **Synapse** | Former banking-as-a-service provider used in the Cash Out infrastructure. Still referenced as a source filter in Looker. |  |
| **Unit** | Platform previously used for Pay Any Day (PAD) money movement. Sunsetted along with PAD. |  |
| **Threadbank** | Bank partner previously used for PAD advance funding (Operating, Revenue, and Reserve accounts). |  |
| **Check** | Homebase's payroll processing infrastructure partner. |  |
| **KYC (Know Your Customer)** | Identity verification process run via Plaid during CO enrollment. Failures result in D6 user state. |  |
| **CommandAI** | In-product nudge/guidance platform used for Clover Embedded activation prompts and onboarding flows. |  |
| **📦  Products** |  |  |
| **Team App** | Homebase's core HR SaaS product suite: scheduling, time tracking, messaging, HR docs, team management. |  |
| **Payroll** | Homebase's payroll processing product. Billed per company \+ per employee. Includes Workers' Comp. |  |
| **Cash Out (CO)** | Homebase's Earned Wage Access product for employees. See Cash Out section above. |  |
| **Hiring** | Homebase's job posting and applicant matching product. Subscription-based with trial-to-pay conversion. |  |
| **PAD (Pay Any Day)** | Former Homebase product where employees at Homebase Payroll companies could create a checking account and take advances. Fully sunsetted. |  |
| **AI Assistant** | Homebase's AI-powered features suite: Predictive Scheduling, Shift Reassignment, Assisted Clock In/Out, Manager Log Assistance, Call Out Agent. Tracked via WAU (Weekly Active Locations). |  |
| **Sierra** | Homebase's AI support agent. Tracked via containment rate and tickets per engaged location. |  |
| **Clover Embedded** | Homebase timesheets embedded directly in the Clover POS. See Clover Embedded section above. |  |
| **Basic** | Homebase Freemium tier – includes basic scheduling and time tracking  | tier_id = 1 in public.fact_locations_by_day|
| **Essentials**  | Homebase cheapest paying tier – includes advanced scheduling, advanced time tracking, team communication. Costs $30 per month     | tier_id = 2 in public.fact_locations_by_day |
| **Plus**  | Homebase tier that costs $70 per month, includes everything in essentials \+ scheduling assistant, PTO, departments & permissions | tier_id = 3 in public.fact_locations_by_day |
| **AiO**  | Homebase tier that costs $120 per month, includes everything in plus as well as employee onboarding, labor cost management, HR & compliance  | tier_id = 4 in public.fact_locations_by_day |

*Homebase Internal — Confidential  •  Last updated February 2026*
