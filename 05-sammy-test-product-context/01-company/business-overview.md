---
owner: sammy
last_updated: 2026-03-30
review_cadence: quarterly
next_review: 2026-07-01
source: vault
refs:
  - 02-business/business-overview.md
---
# Business Overview

Load when answering questions about what Homebase is, its business model, entity relationships, or customer profile.

## What Homebase Is

Workforce management platform for small and medium businesses with hourly workers. Core verticals: restaurants, retail stores, home services, and similar businesses with shift-based labor.

## Customer Profile

- ~100K+ businesses
- Primarily Food & Dining, Retail, and Services
- Most have 1-50 employees across 1-3 locations
- Channels: web signup, POS integrations (Clover, Square, Toast), mobile app

## Business Model

Freemium SaaS. Free tier provides basic scheduling and time tracking. Paid tiers unlock advanced features. Payroll is a premium add-on and major revenue driver.

| Tier | Name | Price/mo | Includes |
|---|---|---|---|
| 1 | Basic | Free | Basic scheduling, time tracking |
| 2 | Essentials | $30 | Advanced scheduling, advanced time tracking, team communication |
| 3 | Plus | $70 | Everything in Essentials + scheduling assistant, PTO, departments & permissions |
| 4 | All-in-One | $120 | Everything in Plus + employee onboarding, labor cost management, HR & compliance |

Payroll is billed per company + per employee, separate from tier pricing.

## Entity Model

| Entity | What it is | Relationship |
|---|---|---|
| Company | The business (e.g., "Joe's Pizza LLC") | Top-level entity. Owns one or more locations. |
| Location | A physical site (e.g., "Joe's Pizza - Downtown") | Belongs to one company. Employees are hired at a location. |
| User | A person with a Homebase account | Can have roles at multiple locations. |
| Job | An employment record linking a user to a location | One user can have multiple jobs (one per location). |

Key distinction: a **company** decides to pay for Homebase (billing entity). A **location** is where employees work and schedules are built (operational entity). Most metrics are reported at the location level.

## Revenue Lines

| Product | Revenue Model |
|---|---|
| Team App (Core) | Monthly subscription per location, tiered |
| Payroll | Per company + per employee per pay period |
| Cash Out | $4.99 per instant advance (employee-paid) |
| Hiring | Subscription per location |
| Workers' Comp | Bundled with Payroll |
