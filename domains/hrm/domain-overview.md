---
owner: sammy
last_updated: 2026-04-09
review_cadence: quarterly
next_review: 2026-07-01
source: manual
---
# HRM Domain Overview

Load when answering questions about what the HRM (Team Management) domain covers, its workflows, or strategic framing.

## What HRM Is

HRM (Team Management) owns the employee lifecycle at Homebase — from the moment an OAM adds someone to their team through onboarding, profile management, and eventual offboarding. HRM is the system of record for who works where, in what role, and with what documentation.

## The 5-Stage Team Management Journey

HRM covers the full employee lifecycle:

1. **Adding someone new to the team** — OAM adds an employee via the team roster or through Hiring. The employee receives an invite (email or SMS) to join Homebase and complete their New Hire Packet (NHP).

2. **Managing team organization + profile** — OAMs assign roles, departments, pay rates, and permissions. Employee profiles store contact info, employment details, and documents. Each employee has one or more Jobs (one per location they work at).

3. **Understanding team performance** — OAMs have visibility into team roster, onboarding completion status, and document collection. Manager Log enables shift handoff notes between managers.

4. **Managing team performance** — Coaching tools for managers. Manager Log captures performance observations and shift notes for documentation.

5. **Terminating a team member** — OAM deactivates an employee. Employment records and documents are preserved for compliance. The employee's Jobs are ended but their User account persists.

## Key Workflows

| Workflow | Who initiates | Trigger | Outcome |
|---|---|---|---|
| Onboarding (NHP) | OAM | New employee added to team | Employee completes tax forms, direct deposit, compliance docs |
| Invite / Join Location | OAM | Employee added or existing user joining new location | Employee gets access to the location in Homebase |
| Document management | OAM or EE | NHP completion, OAM uploads, or compliance need | Documents collected, stored, and accessible |
| Profile management | OAM or EE | Role change, pay rate update, contact info change | Employee record updated |
| Job history | OAM | Role change, location transfer, pay rate change | Employment record tracks changes over time |
| Termination | OAM | Employee departure | Employee deactivated, records preserved |

## Domain Boundaries

| HRM Owns | HRM Does NOT Own |
|---|---|
| Employee profiles and records | Schedule creation (Scheduling) |
| Onboarding / NHP | Timesheet approval (Time Tracking) |
| Document collection and storage | Pay processing (Payroll) |
| Job records (role, pay rate, location) | Job posting and applicant tracking (Hiring) |
| Team roster management | Earned wage access (Cash Out) |
| Termination flow | User identity / authentication (Identity) |

**Key handoff:** HRM onboarding collects the tax forms and direct deposit info that Payroll needs to run payroll. An incomplete NHP means the OAM must process that employee's pay outside of Homebase — creating operational burden, not lost revenue.
