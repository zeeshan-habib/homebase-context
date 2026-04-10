---
owner: sammy
last_updated: 2026-04-09
review_cadence: quarterly
next_review: 2026-07-01
source: manual
refs:
  - domains/hrm/data-model.md
  - global/product-suite.md
---
# HRM Onboarding

Load when answering questions about employee onboarding, NHP, invite flows, or onboarding failure points.

## New Hire Packet (NHP)

The NHP is the digital onboarding package sent to new employees. It collects the tax, payment, and compliance documents an employee needs before they can be fully set up — especially for Payroll. NHP is gated to the All-in-One (AiO) tier.

### Document Types in NHP

| Document | Category | Required | Who fills it out |
|---|---|---|---|
| W-4 (Federal tax withholding) | Tax | Federal requirement | Employee |
| State withholding form | Tax | Varies by state | Employee |
| I-9 (Employment eligibility) | Eligibility | Federal requirement | Employee + OAM |
| Direct deposit authorization | Payment | Required for payroll | Employee |
| Handbook acknowledgment | Compliance | If employer has handbook | Employee |
| Custom documents | Custom | OAM decides | Employee or OAM |

### NHP Flow

1. **OAM adds employee** — via team roster or Hiring conversion. Enters name, email/phone, role, pay rate, location.
2. **System sends invite** — employee receives an NHP link via email, SMS, or both. OAM chooses delivery channel.
3. **Employee opens NHP** — lands on a guided flow to complete each document in sequence.
4. **Employee completes documents** — fills out W-4, I-9, direct deposit, and any custom documents the OAM configured.
5. **Completion** — NHP is marked complete when all required documents are submitted. Completion is progressive (e.g., "3 of 5 complete").
6. **OAM reviews** — OAM can see completion status per employee. Completed docs are stored and accessible.

NHP completion is binary per document but progressive overall. An employee can start working before completing their NHP — incomplete onboarding doesn't block employment, it creates operational burden for the OAM.

## Invite Flow

When an OAM adds a new employee:
- **New to Homebase:** Employee receives an invite to create a Homebase account and complete their NHP.
- **Existing Homebase user:** If the email/phone matches an existing account, the employee joins the new location (Join Location flow) rather than creating a new account.

Delivery channels: email, SMS, or shareable link. OAM can resend invites if the employee doesn't act.

## Join Location

When an existing Homebase user is added to a new employer's location:
- The system detects the existing account and routes to Join Location instead of account creation.
- The user confirms their identity and accepts the invite.
- A new Job record is created linking them to the new location — their existing User and any other company relationships are unaffected.

## Failure Points

| Failure Mode | What happens | Impact |
|---|---|---|
| Identity collision | Employee already has a Homebase account — system may struggle to match or creates confusion | Employee stuck, OAM gets support tickets |
| Incomplete NHP | Employee starts but doesn't finish all documents | OAM must manually handle payroll for that employee outside Homebase |
| Invite delivery failure | Email bounces or SMS doesn't arrive | Employee never starts onboarding; OAM may not notice |
| Employee confusion | Employee doesn't understand what to do or why they received a link | NHP abandoned mid-flow; OAM must follow up manually |
| Wrong delivery channel | OAM sends email but employee only checks SMS (or vice versa) | Invite goes unseen |

## Impact of Incomplete Onboarding

When an employee doesn't complete their NHP:
- **OAM burden:** The OAM must process that employee's pay outside of Homebase (manual payroll entry, paper tax forms). This is the primary pain point.
- **Compliance risk:** Required federal/state documents may not be collected on time.
- **Not a payroll blocker per se:** The employee can still work and get paid — but the OAM has to do extra work to make it happen.

Incomplete onboarding is an *operational burden* problem, not a *revenue* problem. The OAM doesn't lose money — they lose time.
