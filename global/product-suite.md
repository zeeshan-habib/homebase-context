---
owner: sammy
last_updated: 2026-03-30
review_cadence: quarterly
next_review: 2026-07-01
source: vault
refs:
  - data/glossary.md
---
# Product Suite

Load when answering questions about Homebase product areas, how they connect, or what's gated by tier.

## Product Areas

| Product | What it does | Who uses it |
|---|---|---|
| Scheduling | Shift planning, availability management, time-off requests | OAM creates schedules; EE views shifts and requests changes |
| Time Tracking | Clock in/out, timesheets, labor cost tracking | EE clocks in; OAM reviews and approves timesheets |
| Payroll | Integrated payroll processing, tax filing, Workers' Comp | OAM runs payroll; EE receives pay stubs |
| Hiring | Job postings, applicant tracking, candidate messaging | OAM posts jobs and reviews applicants |
| Team Management (HRM) | Onboarding, employee profiles, documents, compliance, Manager Log | OAM onboards new hires; EE completes onboarding docs |
| Cash Out | Earned wage access — employees access earned pay early | EE takes advances; no OAM involvement required |
| Messaging | Team communication within Homebase | OAM and EE communicate about shifts, updates |

## How Products Connect

Scheduling and Time Tracking are the entry point — nearly every customer uses one or both. They generate the labor data that makes Payroll valuable (hours, wages, overtime are already in the system).

Team Management (HRM) activates when a new employee is added — the onboarding flow (NHP) collects tax forms, direct deposit, and compliance docs needed for Payroll.

Cash Out requires an active employment relationship (job) and bank account connection. It operates on earned wages calculated from time tracking data.

Hiring feeds into Team Management — a hired applicant becomes a new employee who enters the onboarding flow.

## Tier Gating

| Feature | Basic (Free) | Essentials | Plus | All-in-One |
|---|---|---|---|---|
| Basic scheduling | Y | Y | Y | Y |
| Basic time tracking | Y | Y | Y | Y |
| Advanced scheduling | - | Y | Y | Y |
| Team communication | - | Y | Y | Y |
| Scheduling assistant | - | - | Y | Y |
| PTO management | - | - | Y | Y |
| Departments & permissions | - | - | Y | Y |
| Employee onboarding (NHP) | - | - | - | Y |
| Labor cost management | - | - | - | Y |
| HR & compliance | - | - | - | Y |

Payroll, Cash Out, and Hiring are separate products with their own pricing, available at any tier.

## Distribution Channels

| Channel | How it works |
|---|---|
| Direct web signup | homebase.com → freemium conversion funnel |
| Clover Embedded | Homebase timesheets embedded in Clover POS; merchants activate via OAuth |
| Square / Toast | POS integrations; data sync for time tracking |
| Mobile app | iOS/Android; primary interface for EEs |
