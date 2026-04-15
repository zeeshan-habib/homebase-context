---
last_updated: 2026-04-07
review_cadence: quarterly
next_review: 2026-07-01
source: vault
refs:
  - data/glossary.md
---
# Product Glossary

Load when encountering an unfamiliar Homebase product term. For metric definitions (how we measure things), see `data/glossary.md` instead.

## People & Roles

| Term | Meaning |
|---|---|
| OAM | Owner, Admin, or Manager — the person running the business |
| EE | Employee — hourly workers on the team |
| DRI | Directly Responsible Individual — named owner of a metric or initiative |

## Products & Plans

| Term | Meaning |
|---|---|
| Team App | Homebase's core HR SaaS product suite: scheduling, time tracking, messaging, HR docs, team management. Also called "TA" or "Core". |
| Payroll | Homebase's payroll processing product. Billed per company + per employee. Includes Workers' Comp. |
| Cash Out | Earned wage access — employees access earned pay before payday. Instant advances cost $4.99. |
| EWA | Earned Wage Access — industry term for Cash Out-type products. |
| Hiring | Homebase's job posting and applicant matching product. Subscription-based with trial-to-pay conversion. |
| PAD (Pay Any Day) | Former product where employees at Payroll companies could create a checking account and take advances. Fully sunsetted. |
| Basic | Free tier (tier 1) — basic scheduling and time tracking. |
| Essentials | Cheapest paying tier (tier 2) — advanced scheduling, advanced time tracking, team communication. $30/month. |
| Plus | Tier 3 at $70/month — includes Essentials + scheduling assistant, PTO, departments & permissions. |
| AiO | All-in-One tier (tier 4) at $120/month — includes Plus + employee onboarding, labor cost management, HR & compliance. |
| Bundles | Bundled pricing product where companies pay for both Team App and Payroll together. Has its own ARR line in the WBR. |
| Workers Comp | Workers' Compensation insurance revenue, a component of Payroll ARR. |

## Product Concepts

| Term | Meaning |
|---|---|
| NHP | New Hire Packet — digital onboarding documents (W4, I9, direct deposit, etc.) sent to new employees |
| Manager Log | Shift handoff tool — managers post notes about what happened during their shift |
| Join Location | The flow an existing Homebase user follows to join a new employer's location |
| Eligibility | The set of rules a Cash Out user must pass to take an advance (bank balance, hours worked, risk score). Checked on enrollment, Plaid webhooks, and every 24 hours. |
| Portability Users | Cash Out users who are cashing out but no longer work at a Homebase company. |

## Business & Planning

| Term | Meaning |
|---|---|
| Tier 1-4 | Customer segments by plan level (1=Basic/Free, 2=Essentials, 3=Plus, 4=All-in-One) |
| ICP | Ideal Customer Profile — SMBs with 1-50 hourly employees |
| WBR | Weekly Business Review — recurring exec meeting reviewing key metrics |
| MBR | Monthly Business Review — monthly equivalent of WBR, includes OKR progress, presented to exec team |
| PoR | Plan of Record — the official annual plan set at year start |
| PW Fcst | Prior Week Forecast — the ARR forecast from the previous week's WBR |
| T4 Wk | Trailing 4-Week Average — average of the past 4 weeks excluding the current week, used to smooth noise |
| DX (e.g. D30, D60) | Metric on day X of a company's life — exactly X days after signup. Used for cohort analysis. |
| EPD | Engineering, Product, and Design — the cross-functional team structure |
| EPDD | EPD Directory — Confluence page mapping domains to teams |
| GTM | Go-to-Market — covers marketing, sales, and partner channels |
| WoW | Week over Week |
| YoY | Year over Year |
| MoM | Month over Month |
| MTD | Month to Date |
| Fcst | Forecast — current month-end projection, updated weekly in the WBR |
| vtg % / Var (%) | Variance to Goal / Variance to PoR |
| PY / Prior Year | Prior Year actuals, used as a YoY comparison benchmark |
| EoP MRR | End-of-Period MRR — the MRR balance at the end of a given month |

## Activation & Growth

| Term | Meaning |
|---|---|
| 1D1 | 1-Day 1-Action — company completes one meaningful action within 24 hours of signup |
| 2D7 | Two employee logins in the first 7 days — early engagement signal |
| PLG | Product-Led Growth — conversion driven by in-product experience vs. sales |
| PQL | Product-Qualified Lead — user showing product behavior indicating upgrade/payroll intent |
| NSF | Non-Sufficient Funds — bank return code indicating insufficient funds in a user account |

## Channels & Partners

| Term | Meaning |
|---|---|
| Clover Embedded | Homebase timesheets embedded in Clover's Dashboard |
| Front Book | New Clover merchants signed up after embedded distribution agreement |
| Back Book | Existing Clover merchants retroactively made eligible for embedded |
| Activation-Ready | Clover segment: merchants active on Homebase but not yet embedded-activated. Highest-probability conversion pool. |
| Expansion-Ready | Clover segment: embedded-activated merchants with sustained usage. Focus on upgrades, payroll attach, add-ons. |
| Sierra | Homebase's AI support bot |

## Partners & Infrastructure

| Term | Meaning |
|---|---|
| Plaid | Bank data aggregation and identity verification provider. Used for bank connection, transaction history, KYC, and RTP in Cash Out. |
| Checkout / CKO | Homebase's payment processor for ACH debits (repayments) and credits (advances). |
| RTP | Real-Time Payments — method of advancing cash outs via Plaid (~66% of advances). |
| Synapse | Former banking-as-a-service provider used in Cash Out infrastructure. Still referenced in Looker. |
| Unit | Platform previously used for PAD money movement. Sunsetted. |
| Threadbank | Bank partner previously used for PAD advance funding. |
| Check | Homebase's payroll processing infrastructure partner. |
| KYC | Know Your Customer — identity verification process run via Plaid during Cash Out enrollment. |
| CommandAI | In-product nudge/guidance platform used for Clover activation prompts and onboarding flows. |
