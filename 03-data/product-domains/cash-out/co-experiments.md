# Cash Out — Experiments

Strategic ledger of CO experiments: what we tested, results, business impact, and learnings.

## Hide Account Selection Screen (Feb 2026) — SHIPPED

**Strategic area:** Enrollment funnel optimization
**What:** Removed the Bank Account Selection screen from enrollment. After Plaid connection, users previously re-selected the same account — redundant for CO (originally built for Pay Any Day).

**Experiment:** `cash_out_enrollment_hide_account_selection` (v0 = control, v1 = treatment)
**Timeline:** 50/50 split Feb 14–19. Rollout: 10% → 50% → 100% on 2/23.

### Results (domain data)

| Metric | Control | Treatment |
|--------|---------|-----------|
| Users in experiment | 4,825 | 4,825 |
| Successful enrollments | 713 | 773 |
| Enrollment rate | 14.8% | 16.0% |
| **Lift** | | **+1.2pp** |

### Business Impact: $71K–$200K incremental ARR

| Framing | Denominator | Lift | Monthly initiators | ARR |
|---------|-------------|------|--------------------|-----|
| Intent-to-treat (conservative) | All who initiated enrollment | +1.2pp | ~48,250 | ~$71K |
| Post-Plaid (intervention point) | Users who connected a bank | +7.5pp | ~22–25K | ~$200K |

Post-Plaid framing is more appropriate — experiment only changed the flow after Plaid. ITT dilutes with users who never reached the intervention.

### Key Learnings

- **Even "simple" confirmation screens have measurable cost.** A single extra tap in a high-drop-off flow reduced post-Plaid enrollment by 7.5pp.
- **High ROI for low eng effort** — 1-week eng effort for $71K–$200K ARR. Similar opportunities likely exist elsewhere in the funnel (auto-filling KYC, reducing debit verification steps).
- **No negative downstream effects.** Activation rates and CO usage among treatment enrollees matched control.
- **Shared product infrastructure needs product-specific evaluation.** Screen was built for PAD where account selection matters; was redundant for CO.
- **Analytics caveat:** Anchor revenue projections on domain data, not Amplitude. Amplitude had uneven variant counts (2,431 vs 1,988 vs domain's balanced 4,825/4,825) and the apparent +3.8pp Amplitude lift was a denominator artifact.

**People:** Jon Blackwell (PM), Abdullah Al-Omaisi, Wilfried Penel, Santiago Borjon (eng), Janice Lee (analytics)
**Links:** [Analysis](https://docs.google.com/spreadsheets/d/1sG8X66l0M5hByN_D8etSrDVQtn8b4Rje4K6eenMgte0/edit?gid=625738012#gid=625738012) | [Tech design](https://joinhomebase.atlassian.net/wiki/spaces/EE/pages/4566351873) | [Results doc](/Users/jlee/Downloads/CO%20Removing%20Bank%20Acct%20Selection%20Screen_%20Results%20%26%20Revenue%20Impact.docx)

---

## Web-first Enrollment Experiment (ONGOING)

**Strategic area:** Bet #1 — Web Enrollment for Cash Out
**What:** Test whether non-mobile employees engage with a web-first CO value proposition and complete phone + OTP verification — before investing in full enrollment flow.

**TAM:** ~375K shift-active employees reachable via SMS/email/Clover POS with no mobile app usage and no prior CO enrollment. Converting 2–10% = $2.2M–$10.8M ARR.

**Hypothesis:** Employees who don't identify as Homebase users will engage with a CO value prop when employer-anchored and delivered via mobile web.

**Testing:** Value prop resonance in web context, employer trust anchoring, phone + OTP completion, engagement by entry context.
**NOT testing:** Full enrollment (Plaid, debit, payday), eligibility/limits, app installs, revenue.

### Entry Points (mutually exclusive, priority-ordered)

| Channel | Context | Sample | Expected Reach |
|---------|---------|--------|----------------|
| QR – Clover | Post-clock-out on Clover POS | ~2,000 | ~960 |
| QR – Other Timeclock | Post-clock-out on non-Clover | ~1,995 | ~958 |
| SMS | Post-shift, references employer/earnings | ~2,997 | — |
| Email | Post-shift, users with email but no phone | ~1,499 | — |

Total eligible: ~45,969. Sampled: ~8,491 across ~3,738 locations.

**Primary metric:** Web Enrollment Throughput Rate = OTP verified / Landing viewed.

### Email Launch Results (as of 2026-03-10)

**Iterable → click:**
- 1,559 emails sent (975 on 3/9, 584 on 3/10), 17 clicks → **1.1% CTR**
- [Iterable campaign](https://app.iterable.com/analytics/campaignPerformance?campaignId=17030787) | [Amplitude chart](https://app.amplitude.com/analytics/homebaseone/chart/3z4m5gz5)

**Landing → OTP funnel:**

| Step | Count |
|------|-------|
| Viewed Landing | 16 |
| Clicked Continue | 11 |
| Enter Phone | 11 |
| Clicked Send Code | 6 |
| OTP Sent | 5 |
| Viewed Verify Identity | 5 |
| Enter Code | 5 |
| Clicked Verify Code | 4 |
| OTP Confirmed | 4 |
| Viewed Success | 4 |

**Landing → Success: 25%** (4/16). Strong throughput once users reach landing; bottleneck is upstream email CTR.

[Amplitude funnel chart](https://app.amplitude.com/analytics/homebaseone/chart/tlqg1wcx)

### QR Launch Status (pre-launch)
- Android Timeclock events confirmed in staging
- Arvin syncing with Juan to verify `Modal Viewed` event before launch

### Known Issue — Missing company_name
- Some email users land with empty `company_name`/`location_id`, showing `[Business Name]` placeholder
- Root cause: old CSV upload (Feb 2024 campaign) didn't stitch to Homebase profile
- Fix: PR [#67199](https://github.com/pioneerworks/Homebase1/pull/67199) — fallback copy when company name missing

### Full Web Enrollment Design (ahead of experiment)
- Jeff Gombos Figma: review step, greyed-out approval state, generic modals, consistent branding
- Prod Design Eng decisions (3/9): errors on blur/Continue click, simple front-end validation, generic error toast for MVP, same two-step flow desktop+mobile, generic enrollment-complete message, logout → landing with phone+OTP re-login
- Open: Tim investigating mobile state machine → web mapping; Arvin researching card type auto-detection + browser autofill for debit

**People:** Jon Blackwell (PM), Arvin Sabares, Craig Wedseltoft, Tim Cannady (eng), Jeff Gombos (design), Darin Thacker, Darah Lee (LCM), Janice Lee (analytics)
**Slack:** `#proj-co-web-enrollment`
**Links:** [Proposal](https://docs.google.com/document/d/1TUfBN9zyRF5iED_oe5Lrn2V7Qj7C6r_qDl6GzFS4DqY/edit) | [Design](https://docs.google.com/document/d/1GqrTXHCwL2j1ebXtrKxZRMk6OpEgJNV2u72x17Zn3KE/edit)

---

## Debit Repayment Delay Experiment (ONGOING)

**Strategic area:** Infrastructure / quality
**What:** Test whether shifting debit repayment attempts 5–10 minutes past the top of the hour reduces Sidekiq queue contention during peak clock-in/out hours (6–9am ET) without degrading repayment success rates.

**Context:** `shift_pay_enqueue_today_paybacks_debit` worker runs hourly at :00, colliding with clock-in/out traffic spikes at 6–9am ET. Both compete for Sidekiq, causing slow clock-in response times.

**Experiment:** `shift_repayment_debit_delay`

| Variant | Offset | Split |
|---------|--------|-------|
| Control (0) | Top of hour | 90% |
| Variant 1 (1) | +5 min | 5% |
| Variant 2 (2) | +10 min | 5% |

Debit pulls only (not ACH). 5 and 10 min offsets avoid other busy queue times at :15 and :30.

### Results (as of Feb 17, 2026)

**Debit Returns:**

| Group | Paybacks | Returns | Return Rate | NSF Rate |
|-------|----------|---------|-------------|----------|
| Control | 114,115 | 68,558 | 60.1% | 14.5% |
| +5 min | 6,606 | 4,062 | 61.5% | 14.0% |
| +10 min | 6,153 | 3,645 | 59.2% | 14.8% |

**Non-Repayment Rates:**

| Group | Advances | D1 | D7 | D14 |
|-------|----------|-----|-----|-----|
| Control | 151,495 | 18.11% | 8.05% | 4.81% |
| +5 min | 8,600 | 18.71% | 8.82% | 2.51% |
| +10 min | 8,301 | 19.24% | 9.01% | 6.27% |

### Key Observations
- Results **not statistically significant** at 90/5/5 split (~6K per variant vs 114K control)
- Jon's framing: separate infra question from repayment question — if clock-in latency improves, that may justify the change even with neutral repayment
- Open: Arvin to share Sidekiq queue depth / clock-in response time data

**Status (2026-03-11):** Awaiting re-run with ~7 additional weeks of data. Jon requested fresh numbers 3/9 for ship/kill decision.

**People:** Jon Blackwell (PM), Kevin McDonough (analytics), Abdullah Al-Omaisi, Arvin Sabares, Craig Wedseltoft, Jenakan Sivagnaanam (eng), Janice Lee (analytics)
**Links:** [Analysis](https://docs.google.com/spreadsheets/d/1bezfQnIFtewVFXl9XMUg0dhAAdp8F0Oy_3jzPyNzGYg/edit?gid=7784844#gid=7784844) | [EE-2395](https://joinhomebase.atlassian.net/browse/EE-2395) | [PR #65154](https://github.com/pioneerworks/Homebase1/pull/65154)

---

## Active Projects

- CO Pacing Revamp
- CO Refit Model Design
- CO Web Enrollment
- Web-first Enrollment Experiment
- Debit Repayment Delay Experiment
- Cash Out User Research
