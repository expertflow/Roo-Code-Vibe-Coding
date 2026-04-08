# Editorial Review — Structure
**Document:** `prd-ExpertflowInternalERP-2026-03-16.md`
**Date:** 2026-03-16
**Reviewer:** BMAD Structural Editor

## Execution status — completed

All nine recommendations were applied to the PRD and downstream artifacts were synced:

| # | Recommendation | Status |
|---|----------------|--------|
| 1 | User Journeys (`## 3`) | ✅ Added; PRD renumbered §3–§9 (Target Users §4, Functional §5, … Open Questions §9) |
| 2 | Cut §6 data model tables | ✅ Prior pass — §7 stub defers to Architecture |
| 3 | Condense Executive restrictions cell | ✅ |
| 4 | Condense resolved assumptions (A1–A3, A7–A9); A4–A6 kept | ✅ |
| 5 | FR9 Option C — drop redundant credit/debit parentheticals | ✅ |
| 6 | Move FR34 into ledger policy subsection with FR40/FR41 | ✅ Now opens **§5.14** |
| 7 | FR22 → bullet policy list | ✅ |
| 8–9 | Preserve NFR prose + §8 success table | ✅ (unchanged) |

**Also applied (from PRD validation findings):** NFR5 measurable baseline; **NFR11** Employee PII; **NFR8** / **FR5** include `EmployeePersonalInfo` audit; **Epics** (Story 1.6, Epic 1/4 NFR lines, Epic 2 goal) and **implementation-readiness-report** updated for FR21/NFR changes.

---

## Document Summary

- **Purpose:** Define Phase 1 requirements for the Expertflow Internal ERP (Directus backend + HR/Finance modules) for use by human stakeholders and downstream LLM agents (architecture, epics, development)
- **Audience:** Andreas (owner/developer), future AI development agents
- **Reader type:** Dual — humans (approval, orientation) + LLMs (precision, density)
- **Structure model:** Strategic/Context (Pyramid) — conclusion-first, grouped supporting context
- **Current length:** ~1,450 words in §4 (FRs), ~900 words in §6, ~700 words in §8; estimated total ~3,800 words across 8 sections

---

## Recommendations

### 1. QUESTION — Missing `## User Journeys` Section

**Rationale:** BMAD PRD standard requires a User Journeys section to establish the traceability chain between success criteria and FRs; currently absent, breaking downstream story traceability.
**Impact:** ~0 words saved (addition required, ~200–300 words). This is a gap, not a cut.
**Action:** Author to decide: add a minimal journey section (4–5 journeys, 2–3 sentences each) or formally waive and document why (e.g., "internal tool, journeys implicit in FRs").

---

### 2. CUT — §6 Data Model Reference (entire section)

**Rationale:** Field lists, relationship types, and nullable notes are architecture territory, duplicated in `architecture-BMADMonorepoEFInternalTools-2026-03-15.md §4`. Maintaining two copies creates drift risk.
**Impact:** ~900 words (~24% of document)
**Proposed replacement:**

> **§6 Data Model Reference** — Full field lists, relationship types, and Directus mapping notes are maintained in the Architecture document (§4 Relationship Mapping and §6 Project Structure). This PRD defers to that document as the single source of truth for schema detail.

**Comprehension note:** PRD retains the Scope table (§2.1) which lists collection names — sufficient for requirements context without full data model detail.

---

### 3. CONDENSE — §3.1 Executive Role Restrictions Cell

**Rationale:** The Restrictions cell for the Executive role spans ~5 lines of inline parenthetical citations inside a table. Tables are for scanning; policy depth belongs in the FRs.
**Impact:** ~80 words

**Proposed:**
> No direct read on any amount-bearing financial collection. P&L via Insights dashboard only (FR20). Blocked from Accruals, Allocation, Journal, CurrencyExchange.

---

### 4. CONDENSE — §8 Resolved Assumption Bodies

**Rationale:** A1, A3, A7, A8, A9 are fully resolved but each contains 3–6 sentences re-explaining policy that is already in FRs. For LLM consumption this is pure duplication; for human scanning the full text obscures the still-open items (A5, A6).
**Impact:** ~350 words

**Proposed pattern for resolved assumptions:**
> **A1 — Resolved.** `BankStatement.Transaction` nullable by design; see FR6, FR10.
> **A7 — Resolved.** ±3 business days, ±5%, same currency; see FR9.
> **A8 — Resolved.** `DefaultProjectId` = time default only; financial RBAC = `LegalEntity.Type` via `Account`; see FR22, FR40.

Open items (A5, A6) remain full entries since they need author action.

---

### 5. CONDENSE — FR9 Option C and Sign Logic Prose

**Rationale:** FR9 Option C explanation is clear but could remove the parenthetical restatement of "credit/debit" which is common knowledge and adds 30 words of no additional precision.
**Impact:** ~30 words

---

### 6. MOVE — FR34, FR40, FR41 Form a Natural Group

**Rationale:** FR40 and FR41 were correctly moved to §4.14 (Financial Ledger Visibility Policy). FR34 (Accruals/Allocation invisible to non-Finance) is thematically the same policy cluster. Consider moving FR34 into §4.14 alongside FR40/FR41 for cohesion. FR34 currently sits alone at the end of §4.12.
**Impact:** 0 words (reorganization only)
**Comprehension note:** PRESERVE the cross-references in FR32 and FR33 to FR34 — don't remove those links.

---

### 7. CONDENSE — FR22 (Employee CRUD)

**Rationale:** FR22 contains three separate policy sub-points (DefaultProjectId purpose, ProfitCenter hiding, visibility rule) in one paragraph. These are all sound but create a very long FR sentence. Each sub-point already has its own Assumption (A2, A8) for context.
**Impact:** ~60 words; clarity gain
**Proposed split:** Break FR22 into FR22a (CRUD capability) and FR22b (ProfitCenter hiding policy), or use a bullet list within the FR.

---

### 8. PRESERVE — §5 NFR Enumeration Style

**Rationale:** NFRs use consistent "NFR# — Label: text" format. Do not collapse into a table — the prose format allows for the specific measurable details required by BMAD and is already optimal for LLM parsing.
**Impact:** 0 words

---

### 9. PRESERVE — §7 Success Metrics Table

**Rationale:** The acceptance criteria table provides clear, testable pass/fail rows — exactly what development agents need. Do not cut or merge rows despite the table being long.
**Impact:** 0 words

---

## Summary

- **Total recommendations:** 9
- **Actionable cuts/condenses:** 6 (Findings 2, 3, 4, 5, 6, 7)
- **Additions required:** 1 (Finding 1 — User Journeys)
- **Estimated reduction if all cuts accepted:** ~1,420 words (~37% of document)
- **Meets length target:** No target specified
- **Comprehension trade-offs:** Finding 2 (cut §6) removes convenience reference — acceptable since Architecture doc is the single source of truth. Finding 4 (condense resolved assumptions) may slightly reduce standalone readability of §8 but greatly improves LLM scan efficiency.

**Priority order:** Finding 1 (User Journeys gap — author decision required) → Finding 2 (§6 cut — highest word savings) → Finding 4 (§8 condense — noise reduction) → Findings 3, 5, 7 (polish).
