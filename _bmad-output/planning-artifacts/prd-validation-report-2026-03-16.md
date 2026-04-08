---
validationTarget: '_bmad-output/planning-artifacts/prd-ExpertflowInternalERP-2026-03-16.md'
validationDate: '2026-03-16'
inputDocuments:
  - _bmad-output/planning-artifacts/prd-ExpertflowInternalERP-2026-03-16.md
  - _bmad-output/planning-artifacts/product-brief-BMADMonorepoEFInternalTools-2026-03-15.md
  - _bmad-output/planning-artifacts/architecture-BMADMonorepoEFInternalTools-2026-03-15.md
validationStepsCompleted: [format-detection, density-validation, structure-analysis, fr-quality, nfr-quality, traceability, assumptions]
validationStatus: COMPLETE
---

> **Addendum — post-review PRD refresh:** User Journeys (**§3**) added; document renumbered (Functional **§5**, NFR **§6**, Data Model **§7**, Success **§8**, Assumptions **§9**). Finding 2 (A9), Finding 3 (FR order), Finding 5 (§6 cut) addressed in PRD. Finding 6 (NFR5 baseline), Finding 7 (NFR11 PII + FR5/NFR8 audit on `EmployeePersonalInfo`) addressed. Finding 4 (implementation leakage in FRs) **not** mass-rewritten — FRs remain implementation-explicit where needed for this brownfield Directus project.

# PRD Validation Report

**PRD Validated:** `prd-ExpertflowInternalERP-2026-03-16.md`
**Validation Date:** 2026-03-16
**Validator:** BMAD Validation Architect

---

## Format Detection

**Level 2 (##) Headers found:**

1. `## 1. Executive Summary`
2. `## 2. Scope & Boundaries`
3. `## 3. Target Users & Access Control Model`
4. `## 4. Functional Requirements`
5. `## 5. Non-Functional Requirements`
6. `## 6. Data Model Reference (Phase 1 Collections)`
7. `## 7. Success Metrics & Acceptance Criteria`
8. `## 8. Open Questions & Assumptions`

**BMAD Core Sections Check:**

| Section | Present | Notes |
|---|---|---|
| Executive Summary | ✅ Present | §1 |
| Success Criteria | ✅ Present | §7 — labeled "Success Metrics & Acceptance Criteria" |
| Product Scope | ✅ Present | §2 |
| **User Journeys** | ❌ **MISSING** | No dedicated User Journeys section |
| Functional Requirements | ✅ Present | §4 (FR1–FR41) |
| Non-Functional Requirements | ✅ Present | §5 (NFR1–NFR10) |

**Format Classification:** **BMAD Variant** — 5/6 core sections present.

**Impact:** The missing User Journeys section breaks the BMAD traceability chain (Vision → Success Criteria → User Journeys → FRs). FRs cannot be verified as complete without knowing which journeys they serve.

---

## Validation Findings

### FINDING 1 — CRITICAL: Missing User Journeys Section

**Severity:** 🔴 Critical
**Location:** Document structure — section absent

**Issue:** No User Journeys section exists. The BMAD PRD standard requires a User Journeys section to map each persona's end-to-end flow before defining FRs. Without it:
- It is impossible to verify FR completeness relative to user needs
- Downstream artifacts (Epics, Stories) have no journey-to-story traceability
- The Finance Manager reconciliation workflow, HR onboarding, time logging, and expense submission flows are only implicitly described inside individual FRs rather than as first-class journey narratives

**Recommendation:** Add a `## 4. User Journeys` section between Scope and Functional Requirements with at minimum:
- Finance Manager: Bank Statement Import → Reconciliation → P&L Review
- HR Manager: Employee Onboarding → Leave Approval → Payroll Period
- Employee (SPA): Daily Time Logging → Confirmation → Leave Request → Expense Submission
- Executive: P&L Dashboard Review

---

### FINDING 2 — CRITICAL: Assumption A9 Contradicts FR21 / FR40

**Severity:** 🔴 Critical
**Location:** §8 Open Questions, row A9

**Issue:** A9 states: *"executive role reads Invoice/Transaction only under FR21 (ProfitCenter and both legs Employee)"*. However FR21 now explicitly states the `executive` Directus role has **zero collection-level read** on `Invoice` and `Transaction`. The Executive's P&L is surfaced via the Insights dashboard only (FR20), not through direct collection access.

A9 was not updated when FR21 and FR40 were revised in the latest iteration. This stale text will mislead developers into configuring the wrong permissions.

**Recommendation:** Update A9 resolution text to match current FR21/FR40: `executive` role has ZERO direct read on amount-bearing financial collections; P&L via Insights dashboard only.

---

### FINDING 3 — HIGH: FR Numbers Out of Document Order

**Severity:** 🟡 High
**Location:** §4.12 RBAC Configuration and §4.13 Employee Self-Service

**Issue:** FR40 and FR41 appear inside §4.12 (lines after FR34) but are numbered 40/41, higher than FR35–FR39 which appear later in §4.13. This breaks sequential readability and will confuse agents parsing the document top-to-bottom.

**Document order vs. numeric order:**
- §4.12: FR31, FR32, FR33, FR34, **FR40, FR41** ← out of place
- §4.13: FR35, FR36, FR37, FR38, FR39 ← lower numbers appear after higher ones

**Recommendation:** Renumber FR40→FR35 and FR41→FR36, then renumber the current FR35–FR39 as FR37–FR41. Update all cross-references throughout PRD, Epics, and Architecture. Alternatively, move FR40 and FR41 to after FR39 in §4.13 and accept the non-sequential numbering with a note.

---

### FINDING 4 — HIGH: Implementation Leakage in Functional Requirements

**Severity:** 🟡 High
**Location:** Multiple FRs in §4

**Issue:** Per BMAD PRD standards, FRs must describe *capabilities*, not *implementation*. The following FRs leak implementation details that belong in the Architecture document:

| FR | Leakage |
|---|---|
| FR1 | "Cloud SQL Auth Proxy" — specific technology |
| FR1 | "v11.x" — version pinning belongs in Architecture |
| FR6 | "CSV/Excel upload or direct form entry" — UI implementation detail |
| FR7 | "collision-resistant composite uniqueness constraint" — implementation mechanism |
| FR9 | "PATCH /items/BankStatement/<id>" — API endpoint detail |
| FR10 | "items.create / items.update" — hook-level implementation |
| FR10 | "Deduplication runs at this step only (on items.create)" — mechanism, not capability |
| FR33 | Full JSON filter syntax — belongs in Architecture §5.3 |
| FR35 | "Lovable (React/Vite/Tailwind)" — specific technology stack |
| FR36 | "directus_users" — platform implementation detail |

**Recommendation:** Separate the *what* (capability) from the *how* (implementation) across these FRs. The architecture and epics already contain the implementation specifics. FRs should be tool-agnostic capability statements. Acceptable to retain a reference such as "(implementation detail in Architecture §X.Y)" where needed.

---

### FINDING 5 — HIGH: §6 Data Model Reference — Architecture Scope in PRD

**Severity:** 🟡 High
**Location:** §6 Data Model Reference

**Issue:** A detailed data model reference (field lists, relationship types, nullable notes, FK patterns) belongs in the Architecture document, not the PRD. Including it in the PRD:
- Doubles maintenance effort when schema changes
- Blurs the boundary between requirements and technical design
- Adds ~200 lines to the PRD with content already present in the Architecture document

**Recommendation:** Replace §6 with a one-paragraph reference: *"The complete data model — including field lists, relationships, and Directus mapping notes — is maintained in the Architecture document (§4 Relationship Mapping)."* Alternatively, retain a condensed summary table with only collection names and primary purpose.

---

### FINDING 6 — MEDIUM: NFR5 Missing Measurement Context

**Severity:** 🟠 Medium
**Location:** §5, NFR5

**Issue:** NFR5 states: *"Directus Insights dashboards MUST return results within 5 seconds for a typical monthly dataset."* "Typical monthly dataset" is undefined — how many Transaction records? What aggregation depth? Without this, the NFR is not testable.

**Recommendation:** Quantify the baseline: e.g., *"…for a dataset of up to 10,000 Transaction records per month, queried via Directus Insights aggregation panels, as measured by browser network timing."*

---

### FINDING 7 — MEDIUM: Missing Data Privacy Requirements for EmployeePersonalInfo

**Severity:** 🟠 Medium
**Location:** §4.8, FR23

**Issue:** `EmployeePersonalInfo` contains highly sensitive PII fields: `cnic` (national ID), `ntn` (tax ID), `date_of_birth`, `emergency_contact_phone/name`. The PRD has no requirements covering:
- Data retention / deletion policy for ex-employees
- Encryption-at-rest requirements for the sensitive PII fields
- Access logging beyond the general audit trail (NFR8 targets finance collections only)

This is a gap even for an internal tool — employee PII has regulatory implications in most jurisdictions.

**Recommendation:** Add a requirement (FR or NFR) for: (a) `EmployeePersonalInfo` included in Directus Activity/Revisions logging, (b) a stated retention policy decision or deferral to Phase 2, (c) note that `cnic`/`ntn` fields are sensitive and should be masked in display unless explicitly needed.

---

### FINDING 8 — LOW: §3.1 Executive Role Cell is Excessively Verbose

**Severity:** ⚪ Low
**Location:** §3.1 Administrative Roles table, Executive row

**Issue:** The Restrictions cell for the Executive role spans multiple sentences with parenthetical policy citations (FR20, FR21, FR40). For a table, this makes scanning difficult. The policy substance is fully covered in FR20, FR21, and FR40.

**Recommendation:** Shorten the Restrictions cell to: *"No direct read on amount-bearing financial collections. P&L via Insights dashboard only (FR20). Blocked from Accruals, Allocation, Journal, CurrencyExchange."* Full rationale lives in the FRs.

---

### FINDING 9 — LOW: §8 Assumptions — Resolved Items Are Verbose

**Severity:** ⚪ Low
**Location:** §8 Open Questions & Assumptions

**Issue:** Assumptions A1, A3, A7, A8, A9 all have "Resolved" status but contain multi-sentence explanations that duplicate content already in the FRs. This adds noise for downstream LLM consumption.

**Recommendation:** Trim resolved assumption bodies to 1–2 sentences max, citing the FR that contains the full definition. E.g., A7 can become: *"Resolved — ±3 business days, ±5%, same currency. See FR9."*

---

## Traceability Assessment

| Chain Link | Status | Notes |
|---|---|---|
| Strategic Objectives → Success Metrics | ✅ Covered | §1 maps to §7 |
| Success Metrics → User Journeys | ❌ Gap | No User Journeys section to trace against |
| User Journeys → Functional Requirements | ❌ Gap | Cannot verify FR completeness without journeys |
| Functional Requirements → NFRs | ✅ Covered | NFRs independently justified |
| FRs → Architecture | ✅ Covered | Architecture references FR numbers |
| FRs → Epics | ✅ Covered | Epics coverage matrix present |

---

## FR Quality Summary

| Check | Result |
|---|---|
| All FRs use "SHALL" / testable verb | ✅ Pass |
| FR numbering consistent and sequential | ❌ Fail — FR40/41 out of order |
| No subjective adjectives | ✅ Pass |
| FRs are capability-focused (no implementation leakage) | ❌ Fail — ~10 FRs have leakage |
| All FRs traceable to business objectives | ⚠️ Partial — missing journey traceability |

## NFR Quality Summary

| Check | Result |
|---|---|
| All NFRs measurable | ⚠️ Partial — NFR5 lacks baseline definition |
| All NFRs have test criteria | ⚠️ Partial — NFR5, NFR7 could be more precise |
| No subjective NFRs | ✅ Pass |

---

## Summary

| Severity | Count | Must Fix Before Implementation |
|---|---|---|
| 🔴 Critical | 2 | Yes — Finding 1 (User Journeys), Finding 2 (A9 contradiction) |
| 🟡 High | 3 | Recommended — Findings 3, 4, 5 |
| 🟠 Medium | 2 | Optional before Sprint Planning |
| ⚪ Low | 2 | Post-sprint or ignored |

**Overall verdict:** PRD is **implementation-ready with caveats**. The A9 contradiction (Finding 2) is an outright error that must be corrected before stories are written — it will cause the wrong Executive permissions to be implemented. The missing User Journeys (Finding 1) is a structural gap but all FRs are sufficiently detailed to proceed. FR renumbering (Finding 3) and implementation leakage (Finding 4) are quality issues that do not block implementation but reduce LLM accuracy in downstream agents.
