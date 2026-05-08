---
owner: ntang
last_updated: 2026-04-22
review_cadence: quarterly
next_review: 2026-07-01
source: manual
---
# Hiring Assistant — Customers

Load when answering questions about who uses Hiring Assistant, what makes a good fit, or how to segment the customer base.

## Who Uses Hiring Assistant

Hiring Assistant targets SMBs in high-frequency hourly hiring industries — primarily Food & Beverage, Hospitality, and Retail. These businesses:
- Hire repeatedly for the same roles (server, cashier, line cook, etc.)
- Need fast time-to-hire for hourly workers
- Are typically already Homebase time-tracking or payroll customers

## ICP (Ideal Customer Profile)

ICP targets high-frequency hourly hirers who hire consistently across multiple months, at moderate volume per location, with fewer than a handful of locations — and are already actively engaged with Homebase core products (payroll or Plus+, time tracking or scheduling, OAM).

For exact criteria and column definitions, see `data/product-areas/hiring-assistant/hiring-assistant.md`. Precomputed flag: `business_users.hiring.aggregate_hiring_profile.is_icp`.

## Target Segment (H1 2026)

A more focused cut than ICP, specifically for H1 2026 sales outreach. Targets high-volume F&B and Hospitality businesses with a meaningful headcount, already engaged with Homebase, hiring regularly, and OAM-active.

For exact criteria, see `data/product-areas/hiring-assistant/hiring-assistant.md`. Precomputed flag: `business_users.hiring.aggregate_hiring_profile.is_target_segment`.

## 4-Bucket Segmentation

Companies can be segmented by whether they meet ICP, Target Segment, both, or neither. Use the `is_icp` and `is_target_segment` columns in `business_users.hiring.aggregate_hiring_profile` to assign buckets.

## Sales vs PLG Channels

**Sales** — Company subscribed after a Closed Won Salesforce opportunity where `hiring_connected_rep__c IS NOT NULL`. The first subscription at a location after a qualifying opp is Sales-attributed. If a company churns and resubscribes without a new opp, it's PLG.

**PLG (Product-Led Growth)** — Company discovered and converted without a sales rep involved.

For SQL attribution logic, see `data/product-areas/hiring-assistant/hiring-assistant.md`.
