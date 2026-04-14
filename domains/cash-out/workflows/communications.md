# Cash Out — Communications Cadence

## Unenrolled Users

| Timing | Channel | Trigger / Event | Frequency Cap |
|--------|---------|----------------|---------------|
| First 14 days | Push | Day 1 & day 7 | Max 2 ever |
| First 14 days | Pop-up (`info_screen`) | >$25 available, A1 state | 1x ever |
| First 14 days | Dashboard card (`advance_card`) | Always present | "X" hides 7 days |
| First 14 days | Email drip | Day 1 clock-out & +7 days | Max 2 ever, excludes owners |
| Anytime | Push (`push_a1`) | Clock out | 1x / 7 days |
| Anytime | Clock out screen (`clock_out_4.3_enroll`) | A1, >$25 available | 1x / 21 days |
| Anytime | Push (drop-off) | 24 hrs after pre-Plaid or post-Plaid drop-off | Max 2 ever |
| Anytime | Email (Iterable, drop-off) | 1 day after drop-off | Max 1 ever, 14-day cooldown |
| After 14 days | Email/push (Iterable) | Drip | 1x / 6 months, >=60 days after EE creation, 14-day cooldown |

## Enrolled Users

| Channel | Trigger / Event | Frequency Cap |
|---------|----------------|---------------|
| Dashboard card (`enrollment_card`) | B/B2 state | Always |
| Push (`push_b`) | Clock out | 1x / 2 days |
| Clock out screen (`clock_out_4.3_cash_out`) | Clock out | 1x / 21 days |
| Email (Plaid relink) | Plaid disconnected | Max 3 / 30 days (immediately, +3d, +3d) |
| Push (Plaid relink) | Plaid disconnected | Every 7 days, max 2 / 30 days |
| Email/push (1st CO, Iterable) | 24 hrs after enrollment if no CO | 2nd at +14 days |
| Push (immediate eligibility) | Enrollment complete + low-risk + immediate CO limit | 1x at enrollment |

### Immediate Eligibility Push Notification

Low-risk users who complete enrollment and receive an immediate CO limit get a push notification: *"Good news! You are eligible to take a Cash Out. Click here to access your wages today."* Deep-links into the advance flow (Enter Amount screen).

| Detail | Value |
|--------|-------|
| JIRA | [EE-2698](https://joinhomebase.atlassian.net/browse/EE-2698) (feature), [EE-2739](https://joinhomebase.atlassian.net/browse/EE-2739) (BE analytics), [IOS-5657](https://joinhomebase.atlassian.net/browse/IOS-5657) (iOS analytics) |
| Amplitude dashboard | [Push Notification for Newly Enrolled CO Users](https://app.amplitude.com/analytics/homebaseone/dashboard/sv4lraln) |

**Eventing (push -> first CO funnel):**

| Step | Event | Event Category | Instrumented? |
|------|-------|---------------|---------------|
| Push sent | `Push Notification Sent` | `enrollments_immediate_eligibility` | BE (no sampling) |
| Push clicked | `Push Notification Clicked` | `enrollments_immediate_eligibility` | Amplitude |
| Enter Amount | `Screen Viewed` | `select_amount_and_delivery` | Yes |
| Next (amount) | `Button Clicked` (element: `confirm_amount`) | `select_amount_and_delivery` | Yes |
| Delivery modal | `Modal Viewed` | `select_amount_and_delivery` | Yes |
| Next (delivery) | `Button Clicked` (element: `confirm_delivery`, result: `instant\|standard`) | `select_amount_and_delivery` | Yes |
| Confirm CO | `Screen Viewed` | `confirm_cash_out` | Yes |
| Confirm button | `Button Clicked` (button_text: `confirm_cash_out`) | `confirm_cash_out` | Yes |
| Success | `Screen Viewed` | `cash_out_success` | Yes |

All events use `product_area: cash_out_cash_out`.

## Transactional Messages (enrolled)

| Message | Trigger |
|---------|---------|
| CO initiated / Auto CO initiated | Cash Out created |
| Enrollment success | Enrollment complete |
| Overdraft / Low balance alert | Opted in, <$100 balance |
| Upcoming payment | 24 hrs before payback day |
| Repayment reminder | Payback fails, 5pm local, max 3 |
| Defaulted payback | Day 1, 3, 7 after due date |
| Debit card expired / verification / error | Card issue detected |

## Employer Communications

- Drip campaign mentioning CO (employee happiness & onboarding)
- Web app: Cash Out info under `Team` tab ([link](https://app.joinhomebase.com/cash_out))
- Marketing: [joinhomebase.com/employee-pay-advances](https://joinhomebase.com/employee-pay-advances/)

Source docs: [UX events & Jira](https://docs.google.com/spreadsheets/d/1KTQlrAPCJEppR4fDMLw97CpalU_nlY3RNdBC4rekOcw/edit) | [Engagement data](https://docs.google.com/spreadsheets/d/1x2iFfxaVmRAMUudyyu_xrSpkKFsfwITKqM8jNUTUNdE/edit)
