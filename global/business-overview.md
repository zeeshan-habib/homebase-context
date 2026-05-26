---
owner: Zee
last_updated: 2026-05-15
review_cadence: quarterly
next_review: 2026-08-15
source: manual
refs:
  - homebase/homebase-context-structure.md
---

Homebase business-level context. Load when asked about what Homebase is, its products, customer model, or company structure.

<!-- STUB: Populate from pioneerworks/homebase-context/global/ once access is established -->

## Quick Reference

- **What:** SMB workforce management SaaS — scheduling, time tracking, payroll, hiring
- **Entity model:** Company → Location → User/Job. Most metrics are location-level.
- **Tiers:** 1=Basic (free), 2=Essentials ($30), 3=Plus ($70), 4=All-in-One ($120)
- **OAM** = Owner, Admin, or Manager. **EE** = Employee.
- **NHP** = New Hire Packet (digital onboarding: W-4, I-9, direct deposit)
- **Payroll** = separate product, billed per company + per employee
- **Clover Embedded** = Homebase timesheets inside Clover POS (Front Book = new merchants, Back Book = existing)
- **Engaged location** = TT or scheduling engaged (7d) AND OAM activity (30d). Source: `bizops.product_location_engagement_metrics.engagement_boolean`

See `homebase-context-structure.md` for full repo architecture details.
