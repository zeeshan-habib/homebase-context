# Cash Out — Experiments

Strategic ledger of CO experiments: what we tested, decisions, and learnings.

> **What belongs here:** Shipped/killed experiments only — final results, key learnings, links. Ongoing experiments get a one-liner with links.
> **What doesn't:** Interim statistics, point-in-time funnel counts, p-values before a ship/kill decision. Link to the live source instead.

## Experiment Ledger

| Experiment | Area | Dates | Decision | Shipped | ARR Impact | Key Learning |
|---|---|---|---|---|---|---|
| Hide Account Selection | Enrollment funnel | Feb 14–19, 2026 | Ship | Feb 23, 2026 | $71K–$200K | Even "simple" confirmation screens have measurable cost. One extra tap reduced post-Plaid enrollment by 7.5pp. |
| Web-first Enrollment | Channel expansion | Mar 9 – Apr 2026 | Ship (full build) | Apr 2026 | $934K (floor) | Post-landing conversion is strong (41–43% QR/SMS). Bottleneck is upstream reach, not intent. QR/timeclock is dominant channel (88% of ARR). |
| Debit Repayment Delay | Infrastructure | Jan 20 – Mar 2026 | Kill | — | — | 5/10 min offset to debit repayment timing showed no meaningful improvement. Top-of-hour timing is fine. |

## Results Detail

| Experiment | Metric | Control | Treatment | Lift |
|---|---|---|---|---|
| Hide Account Selection | Enrollment rate (ITT) | 14.8% | 16.0% | +1.2pp |
| Hide Account Selection | Enrollment rate (post-Plaid) | — | — | +7.5pp |
| Web-first (QR) | Sampled -> OTP confirmed | — | 1.37% | — |
| Web-first (SMS) | Sampled -> OTP confirmed | — | 0.20% | — |
| Web-first (Email R2) | Sampled -> OTP confirmed | — | 0.45% | — |
| Web-first (QR) | Landing -> OTP confirmed | — | 40.6% | — |
| Web-first (SMS) | Landing -> OTP confirmed | — | 42.9% | — |

---

## Hide Account Selection (Feb 2026) — SHIPPED

**What:** Removed the Bank Account Selection screen from enrollment. After Plaid connection, users previously re-selected the same account — redundant for CO (originally built for Pay Any Day).

**Experiment:** `cash_out_enrollment_hide_account_selection` (v0 = control, v1 = treatment). 50/50 split Feb 14–19. Rollout: 10% -> 50% -> 100% on 2/23.

**Business Impact:** $71K–$200K incremental ARR. Post-Plaid framing (+7.5pp lift) is more appropriate than ITT (+1.2pp) — experiment only changed the flow after Plaid. No negative downstream effects on activation or CO usage.

**Key Learnings:**
- High ROI for low eng effort — 1-week eng effort for $71K–$200K ARR
- Shared product infrastructure needs product-specific evaluation (screen was built for PAD where account selection matters; was redundant for CO)
- Analytics caveat: Anchor revenue projections on domain data, not Amplitude. Amplitude had uneven variant counts and inflated apparent lift due to denominator artifact.

**People:** Jon Blackwell (PM), Abdullah Al-Omaisi, Wilfried Penel, Santiago Borjon (eng), Janice Lee (analytics)
**Links:** [Analysis](https://docs.google.com/spreadsheets/d/1sG8X66l0M5hByN_D8etSrDVQtn8b4Rje4K6eenMgte0/edit?gid=625738012#gid=625738012) | [Tech design](https://joinhomebase.atlassian.net/wiki/spaces/EE/pages/4566351873)

---

## Web-first Enrollment (Mar–Apr 2026) — SHIPPED (full build)

**What:** Tested whether non-mobile employees engage with a CO value prop via mobile web and complete phone + OTP verification. Three entry points: QR/timeclock, SMS post-shift, email post-shift.

**TAM:** ~343K shift-active employees reachable via timeclocks, SMS, or email with no mobile app usage and no prior CO enrollment. 61% reachable only via QR (no phone or email on file).

**Experiment results:**

| Step | Email R1 | Email R2 | SMS | QR |
|------|----------|----------|-----|-----|
| Sampled | 2,000 | 2,000 | 2,997 | 3,998 |
| Reached | 1.3% CTR | 3.0% CTR | 258 (8.6%) | 1,955 (48.9%) |
| Viewed Landing | 26 | 43 | 14 (5.4%) | 101 (5.2%) |
| OTP Confirmed | 5 (19.2%) | 9 (20.9%) | 6 (42.9%) | 41 (40.6%) |
| Sampled -> OTP | 0.25% | 0.45% | 0.20% | 1.37% |

**Projected ARR:** $934K (conservative floor). QR/timeclock: $826K, SMS: $55K, Email: $53K.

**Key Learnings:**
- Post-landing conversion is strong (41–43% for QR/SMS). The bottleneck is upstream: getting users to the landing page (5.2% QR, 5.4% SMS, 1.3–3.0% email)
- QR/timeclock is the dominant channel (~88% of projected ARR) and the only channel reaching majority TAM (61% have no phone or email)
- Employer branding doubles email CTR (3.0% vs 1.3%)
- SMS reach was underestimated — only 18.6% of sampled users worked a shift during the experiment window

**Caveats:** $934K assumes OTP confirmed = CO user. Mobile enrollment shows ~7% start-to-eligible conversion, but web flow is different (OTP-verified, demonstrated intent). iPad timeclock was excluded from experiment but included in TAM.

**People:** Jon Blackwell (PM), Arvin Sabares, Craig Wedseltoft, Tim Cannady (eng), Jeff Gombos (design), Darin Thacker, Darah Lee (LCM), Janice Lee (analytics)
**Links:** [Projection doc](https://docs.google.com/document/d/1EMhy_CnDCRRM0ImNDDkWalTwVfRQ5fLd-VpkHKgijHY/edit) | [Proposal](https://docs.google.com/document/d/1TUfBN9zyRF5iED_oe5Lrn2V7Qj7C6r_qDl6GzFS4DqY/edit) | [Design](https://docs.google.com/document/d/1GqrTXHCwL2j1ebXtrKxZRMk6OpEgJNV2u72x17Zn3KE/edit) | [Amplitude funnel](https://app.amplitude.com/analytics/homebaseone/chart/tlqg1wcx)

---

## Debit Repayment Delay (Jan–Mar 2026) — KILLED

**What:** Tested whether shifting debit repayment attempts 5–10 minutes past the top of the hour reduces Sidekiq queue contention during peak clock-in/out hours without degrading repayment success rates.

**Experiment:** `shift_repayment_debit_delay`. 90% control / 5% +5min / 5% +10min.

**Result:** No meaningful improvement in repayment rates or infrastructure metrics. Decision: revert to control (top of hour).

**People:** Jon Blackwell (PM), Kevin McDonough (analytics), Abdullah Al-Omaisi, Arvin Sabares, Craig Wedseltoft, Jenakan Sivagnaanam (eng), Janice Lee (analytics)
**Links:** [Analysis](https://docs.google.com/spreadsheets/d/1bezfQnIFtewVFXl9XMUg0dhAAdp8F0Oy_3jzPyNzGYg/edit?gid=7784844#gid=7784844) | [EE-2395](https://joinhomebase.atlassian.net/browse/EE-2395)
