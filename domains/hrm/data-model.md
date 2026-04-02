---
owner: sammy
last_updated: 2026-03-30
review_cadence: quarterly
next_review: 2026-07-01
source: stub
refs:
  - global/business-overview.md
---
# HRM Data Model

Load when you need to understand the key entities in the HRM domain, how they relate to each other, or when someone confuses concepts like "Team Member" vs. "Job."

## Key Entities

### Team Member

The user-company relationship. A person on a company's team, regardless of which location(s) they work at. This is the HRM-level concept — most HRM features (onboarding, documents, profile) operate at the Team Member level.

- One User can be a Team Member at multiple companies
- A Team Member has one or more Jobs (one per location)
- Onboarding (NHP) is tracked per Team Member, not per Job

### Job

The user-location relationship. One Team Member can hold multiple Jobs — one at each location they work. This is where role, pay rate, department, and schedule rules live.

- A Job belongs to exactly one Location
- Pay rate, role title, and the relationship dropdown value are Job-level attributes
- When a Team Member works at two locations, they have two separate Jobs with potentially different pay rates

### User

The person behind the account. A User is the identity layer — email, phone, login credentials. A single User can be a Team Member at multiple companies (e.g., someone who works at two different restaurants that both use Homebase).

- Users are global; Team Members and Jobs are company-scoped
- "User already exists" errors often mean the person has an account at another company

### Onboarding Record

Tracks NHP (New Hire Packet) completion state for a Team Member. Captures which documents have been completed, which are pending, and whether the packet was sent via email or SMS.

- Created when an OAM sends an NHP to a new team member
- Completion is binary per document but progressive overall (3 of 5 complete)
- Incomplete onboarding doesn't block the team member from working — it creates operational burden for the OAM

### Document

A compliance or custom document attached to a Team Member. Includes both system-required documents (W-4, I-9, direct deposit) and custom documents uploaded by the OAM.

- Documents belong to a Team Member, not a Job
- Some documents are federally required (W-4, I-9), others are state-specific
- Documents can be part of an NHP or uploaded independently

## Relationship Map

```
User (identity)
 └── Team Member (user + company)
      ├── Job (user + location)
      │    └── Location
      ├── Onboarding Record (NHP state)
      └── Document (compliance/custom)
```

**Key relationships:**
- User → has many Team Members (one per company)
- Team Member → has many Jobs (one per location)
- Team Member → has one Onboarding Record
- Team Member → has many Documents
- Job → belongs to one Location
- Location → belongs to one Company

## Common Confusion Points

| Confusion | Clarification |
|---|---|
| Team Member vs. Job | Team Member is who they are at the company. Job is their role at a specific location. An employee at two locations = one Team Member, two Jobs. |
| Team Member vs. User | Team Member is company-scoped. User is global. Same person at two companies = one User, two Team Members. |
| Where does pay rate live? | On the Job, not the Team Member. Different locations can have different pay rates for the same person. |
| Is onboarding per Job or per Team Member? | Per Team Member. You onboard someone onto the company, not onto a specific location. |
| What about the "relationship" field? | Lives on the Job. Describes the employment relationship (employee, contractor, etc.) at that location. |
