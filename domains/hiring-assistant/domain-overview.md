---
owner: ntang
last_updated: 2026-04-22
review_cadence: quarterly
next_review: 2026-07-01
source: manual
---
# Hiring Assistant — Domain Overview

Load when answering questions about what Hiring Assistant is, how the product works, or lifecycle concepts.

## What Hiring Assistant Is

Hiring Assistant is Homebase's recruitment solution that helps small businesses post jobs, receive applications, screen candidates, and manage the hiring process. **Version 2 (V2)** launched on **2025-06-18** as the current product. V1 was a legacy experiment and is not relevant for current analysis. When someone says "Hiring Assistant," they mean V2.

## Product Journey

A typical company's journey through Hiring Assistant:

1. **Zero State Page (ZSP) visit** — Company discovers the product inside Homebase
2. **Draft created** — Company starts writing a job post
3. **Job posted** — Job is activated and syndicated to job boards; triggers the free trial
4. **Applications received** — Candidates apply from Indeed, ZipRecruiter, Google Jobs, etc.
5. **Screeners completed** — Applicants answer automated screening questions
6. **Top matches identified** — ML model flags the best-fit candidates
7. **Interview scheduled** — Manager selects and schedules a candidate
8. **Subscription converted** — Company pays for continued access after trial expires

## Lifecycle Concepts

### Job Post Lifecycle
1. **Created** (`created_at`) — Draft exists in the system
2. **Activated** (`activated_at`) — Job is live and accepting applications; primary "job posted" event
3. **Flagged** (`flagged_at`) — Job under review; also counts as "posted" for metrics
4. **Draft** — Not yet activated; always excluded from metrics (`status != 'draft'`)
5. **Expired / Archived** — Job is no longer active

A job counts as "posted" when `activated_at IS NOT NULL OR flagged_at IS NOT NULL`.

### Application Lifecycle
1. **Application received** — Candidate applies (`hja.created_at`)
2. **Screener opened** — Candidate starts the screener questionnaire
3. **Screener completed** — Candidate finishes the screener
4. **Top match flagged** — ML model scores candidate as high-quality (`is_top_match = TRUE`)
5. **Interview scheduled** — Manager schedules an interview via the platform

### Subscription Lifecycle
1. **Trial started** — Triggered automatically when the company posts their first V2 job
2. **Trial active** — Company uses Hiring Assistant during the free trial window
3. **Subscription created** — Company converts to paid (`bps.created_at`)
4. **Active** — Paying subscriber (`archived_at IS NULL`)
5. **Churned** — Subscription cancelled (`archived_at IS NOT NULL`)

## Key Product Concepts

**Hiring Version**
The `hiring_version` field distinguishes V2 (Hiring Assistant, current) from V1 (legacy). Always filter `hiring_version = 2` unless explicitly analyzing V1 behavior.

**Billing Plan**
`billing_plan` on a job post indicates whether it was posted during `trial` or `subscription`. Subscriptions are per location — a multi-location company can have separate subscriptions per location.

**Syndication**
Jobs posted via Hiring Assistant are syndicated to external job boards (Indeed, ZipRecruiter, Google Jobs). Syndication is controlled at company level via `hiring_settings`. Craigslist is boosted manually, not through standard syndication.

**Trial Behavior**
The free trial begins when a company posts their first V2 job — posting the job creates the trial record. Companies with a trial record but zero jobs are fraud-blocked anomalies and should be excluded from trial engagement analysis.

## Domain Boundaries

| Hiring Assistant Owns | Does NOT Own |
|---|---|
| Job posting and syndication | Employee profile management (HRM) |
| Application management | Onboarding (HRM) |
| Screener / screening questionnaires | Scheduling (Scheduling) |
| Top match ML scoring | Time tracking (Time Tracking) |
| Trial and subscription lifecycle | Payroll processing (Payroll) |
| Hiring attribution (applicant → hire) | Cash out / EWA (Cash Out) |
