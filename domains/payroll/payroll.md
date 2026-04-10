# Payroll

Homebase Payroll lets small businesses run payroll directly from their Homebase account. It uses timecards from Time Tracking as input, so the two products are tightly connected — but Payroll is a separate paid product with its own funnel, revenue, and metrics.

The underlying payroll processing is powered by **Check** (third-party provider). Homebase is the interface; Check handles tax filing, direct deposits, and compliance.

---

## How It Works

1. Employees clock in/out via Time Tracking → timecards are created
2. Manager reviews and approves timecards
3. Manager runs payroll — Homebase sends approved hours + earnings to Check
4. Check processes payments (direct deposit or check), withholds taxes, files tax forms

Payroll can be run manually (web or mobile) or via **Auto Payroll**, which submits automatically on a schedule.

---

## The Payroll Acquisition Funnel

| Stage | What it means |
|---|---|
| **Opportunity (Opp)** | A qualified lead — company shows payroll intent. Tracked in Zoho CRM |
| **Transfer Start** | Prospect has initiated payroll setup/migration in the self-serve portal |
| **Implementation** | Company is going through guided setup (Check entity creation, bank verification, signatory verification) |
| **Ran Payroll** | Company has run at least one payroll. Primary activation event |
| **Active Customer** | Company actively running payroll (people paid in month > 0) |

Opportunities are sourced from multiple paths: self-serve signups, sales outreach, Clover embedded, and product-qualified leads (PQLs).

---

## Active vs. Paying vs. Churned

"Using payroll" means the company **ran payroll within the month** (people paid > 0), not just that they're paying for it. A company can be paying for payroll but not actively running it.

| Status | Meaning |
|---|---|
| **Active** | Ran payroll in the current month (people paid > 0) |
| **Deactivated** | Ran payroll one month but did not run it the following month. Still may be paying |
| **Churned** | No longer paying for payroll. This is a revenue event, not a usage event |

When someone asks "who is using payroll," default to active (ran payroll) rather than paying. Deactivation is a usage signal; churn is a revenue signal. A deactivated company is at risk of churning but hasn't yet.

---

## Pay Frequency

Companies configure a pay period cadence when setting up payroll:

| Pay frequency | Cycle |
|---|---|
| `week` | Weekly (7-day cycle) |
| `twice_week` | Bi-weekly (14-day cycle) |
| Other frequencies exist but these are the most common |

**Gotcha:** If the pay period start day doesn't match the scheduling start day on the location, overtime can calculate incorrectly. See `data/product-areas/payroll/payroll-data.md` for details.

---

## Promo Periods

New payroll customers may receive promotional pricing (1–6 months free). MRR calculations account for this — a company in a promo period is a customer but contributes $0 MRR until promo ends. There is also a legacy `2021_free` promo bucket.

---

## Relationship to Time Tracking

- Payroll pulls hours from timecards. A location must be using Time Tracking for Payroll to work.
- Payroll runs connect to locations, not directly to timecards. For join details, see `data/product-areas/payroll/payroll-data.md`.
- Payroll Assistants (ACO/ACI) live in the Time Tracking domain, not Payroll — they clean up timecards *before* payroll is run. See `domains/time-tracking/`.

---

## Key Concepts

| Term | Meaning |
|---|---|
| **Check** | Third-party payroll processor. Homebase creates a "Check entity" for each payroll company. Check handles tax, deposits, compliance |
| **Check requirements** | Verification steps Check requires before payroll can run: federal EIN, bank account, signatory identity, company identity. Each has a status (open/pending/failed/closed) |
| **Contractor payments** | Tracked separately from employee payroll items. Contractors are paid through payroll but don't have timecards |
| **Auto Payroll** | Payroll submitted automatically on schedule |
| **Multi-location payroll** | Companies running payroll across multiple locations. Tracked with a `multi_location_start_date` |
| **Inception vs. Switcher** | "Inception" = company new to payroll. "Switcher" = migrating from another provider. Derived from `previous_payroll_provider_from_opp` |
