# Sprint Change Proposal — Bank statement scope (Story 3-1 expansion)

**Date:** 2026-03-24  
**Project:** BMADMonorepoEFInternalTools  
**Authoring workflow:** `bmad-correct-course` (Correct Course) + `bmad-architect` (architecture amendment)  
**Config:** `_bmad/bmm/config.yaml` — **Andreas**, English, intermediate.

---

## 1. Issue summary

**Trigger:** Story **`3-1-bank-statement-import-deduplication`** was expanded beyond the original epic slice (dedup hook only) to include:

1. **Finance-only** visibility for **`BankStatement`** (no HR / line-manager read).
2. **Operator import UX:** file upload → select **`Account`** (~12 house banks) → **Import**.
3. **Per-account Python** parsers (CSV/spreadsheet layouts) that emit **`BankStatement`** rows, then the **generic dedup hook** on **`items.create`**.

**Context:** Stakeholder requirement for controlled bank file ingestion and stricter confidentiality of bank lines. Discovered during Epic 3 planning / story refinement (not a production outage).

**Evidence:** `_bmad-output/implementation-artifacts/3-1-bank-statement-import-deduplication.md` (sub-stories **3-1a–d**); conflict note vs current Architecture permission matrix and §8.2 **`BankStatement`** RLS row.

---

## 2. Impact analysis

### Epic impact

| Epic | Impact |
|------|--------|
| **Epic 3** | **Scope increase** for **3-1**; effort and sequencing (**3-1a** SQL/RBAC → **3-1b/c** import → **3-1d** hook). **3-2** reconciliation still follows; **3.2b** (multi-bank FR46) remains stub — partial overlap with Python parsers but **3-1c** is house-bank specific, not full FR46. |
| **Epic 2** | Must align **Directus** collection visibility: **`BankStatement`** hidden / no read for non-Finance roles when permissions exist. |
| **Epic 6 / reporting** | **Low** — cash flow (**6-3**) uses **`Transaction`/`Invoice`**, not **`BankStatement`**. **6-1** completeness uses **`Journal` ↔ `Transaction`** — unchanged. |
| **Epic 4 / HR narratives** | **Training/docs** only: HR no longer sees bank lines for “payroll proof” in Admin if Finance-only stands — payroll narrative may reference **`Invoice`/`Transaction`** only unless PM restores a different evidence path. |

### Story impact

- **`3-1-*`:** Primary; already amended in implementation artifact.
- **Future:** Optional split into separate **`sprint-status.yaml`** keys (**3-1a** …) — **moderate** backlog hygiene; SM discretion.

### Artifact conflicts

| Artifact | Conflict |
|----------|----------|
| **Architecture** §5.2 | **`BankStatement`**: was **R** for **hr-manager** / **line-manager** — **must change** to **—** (or explicit **no access**). |
| **Architecture** §8.2 | **`BankStatement`** RLS row listed HR + line manager **SELECT** — **must change** to **Finance-only** for app roles (break-glass **`bs4_dev`** unchanged). |
| **Architecture** §4.2 | Bullet said **`BankStatement.Transaction` NOT NULL** on create — **contradicts FR6 / ADR-05** (nullable at import). **Correct** to **MAY NULL** until reconciliation. |
| **PRD** | **FR33 / FR40** implications if HR relied on **`BankStatement`** read for Employee-ledger — **PM must confirm** Finance-only override (see §3). |
| **UX** | New **import** surface (module / flow / endpoint) — not previously wireframed; acceptable as **Story 3-1b** deliverable. |

### Technical impact

- New **SQL migration** (`docs/sql/`) for **`BankStatement`** policies.
- **Directus extension** or **endpoint** + **Python** subprocess or **sidecar** — security review (path, args, temp files, upload limits).
- **Registry** (`Account` id → importer module) in repo config.

---

## 3. Recommended approach

**Classification:** **Moderate** — backlog + architecture + PM confirmation on PRD alignment; not a full epic replan.

**Path:** **Direct adjustment**

1. **PM / PO:** Confirm **Finance-only `BankStatement`** overrides prior HR/manager read (or document exception).
2. **Architect:** **ADR-16** recorded; **Architecture** §4.2 / §5.2 / §8.2 updated (**this change set**).
3. **SM:** Keep **3-1** as umbrella story or split keys in a later sprint planning pass.
4. **Dev:** Implement **3-1a → 3-1d** per story file.

**Risks:** HR/legal question if payroll audit **required** bank visibility — mitigate with **`Journal`** / **`Transaction`** evidence only, or **read-only aggregate** outside `BankStatement` (future story).

**Rollback:** Revert RLS SQL + Directus permissions to prior matrix; remove import endpoint.

---

## 4. Detailed change proposals (applied or specified)

### Architecture (Winston — executed in repo)

- **ADR-16** added to decision summary.
- **§4.2** — **`BankStatement.Transaction`**: **MAY NULL** on import; reconciliation sets FK; dedup/cap unchanged.
- **§5.2** — **`BankStatement`**: **finance-manager** **CRUD**; **hr-manager** / **line-manager** / **executive** / **employee**: **—** (no access). *Supersedes prior **R** cells for HR/line on this collection.*
- **§8.2** — **`BankStatement`**: **Finance `UserToRole` / role 115** full app access; **no** HR or line-manager **`SELECT`** for Phase 1 bank import track. *(Align SQL with `auth()` predicates.)*
- **New §4.2.1** (or appended bullets) — **Import pipeline:** registry; Python parsers; Directus-authenticated **`POST`**; subprocess hardening.

### PRD (PM — **done** 2026-03-24+)

- **`prd-ExpertflowInternalERP-2026-03-16.md`** updated: **FR40.1** (`BankStatement` Finance-only, dual-layer RLS/RBAC, ADR-16 cross-ref); **FR46.6** (mandatory **`Account`** selection + registry-bound import + same authenticated **`POST`** path as manual entry); **FR46.2** / **FR6** / **FR33** / **FR40** / §3–§4.4 aligned (HR journey, role matrix, payroll terminology table, “who sees what”).

### Story (already done)

- **`3-1-bank-statement-import-deduplication.md`** — sub-stories **3-1a–d**, AC 7–10, BMAD routing table.

---

## 5. Implementation handoff

| Role | Action |
|------|--------|
| **PM** | Confirm PRD note (optional formal `bmad-edit-prd`). |
| **Architect** | ✅ ADR-16 + doc patches in **`architecture-BMADMonorepoEFInternalTools-2026-03-15.md`**. |
| **SM** | Optional: **`sprint-status.yaml`** keys for **3-1a**… or keep single **3-1**. |
| **Dev** | **`bmad-dev-story`** on **`3-1`**. |

**Success criteria**

- Non-Finance users: **zero** `BankStatement` rows via API and **no** nav entry.
- Finance: import UX + at least **one** parser E2E; dedup hook rejects duplicates.
- Architecture + PRD (if updated) **agree** on visibility.

---

## 6. Checklist (Correct Course — batch mode)

| Section | Item | Status |
|---------|------|--------|
| 1 | Trigger story **3-1** | Done |
| 1 | Type: **New stakeholder requirement** | Done |
| 1 | Evidence: story file + arch matrix | Done |
| 2 | Epic 3 scope enlarged | Done |
| 2 | No epic removal | N/A |
| 2 | Epic 2 touched (permissions) | Done |
| 3 | Architecture update required | Done |
| 3 | PRD confirmation recommended | Action-needed (PM) |
| 4 | Implementation handoff to Dev | Done |

---

**Correct Course workflow complete, Andreas.** Next: **PM** signs PRD line (optional) → **Dev** executes **3-1**. Invoke **`bmad-architect`** **[CH]** for follow-up questions on ADR-16.
