---
stepsCompleted: [1, 2, 3, 4, 5, 6]
documentsAssessed:
  - _bmad-output/planning-artifacts/prd-ExpertflowInternalERP-2026-03-16.md
  - _bmad-output/planning-artifacts/architecture-BMADMonorepoEFInternalTools-2026-03-15.md
  - _bmad-output/planning-artifacts/epics-ExpertflowInternalERP-2026-03-16.md
project_name: ExpertflowInternalERP
assessor: Winston (Architect) — BMAD Implementation Readiness Workflow
date: 2026-03-16
scope: Phase 4 readiness for Directus backend (Epics 1–6). Lovable SPA (Epic 7) intentionally deferred.
---

# Implementation Readiness Assessment Report

**Date:** 2026-03-16
**Project:** ExpertflowInternalERP
**Assessed by:** Winston (Architect)
**Scope:** Phase 4 readiness — Directus backend configuration (Epics 1–6). Lovable UX (Epic 7) deferred by design.

---

## Document Inventory

| Document | File | Status |
|---|---|---|
| PRD | `prd-ExpertflowInternalERP-2026-03-16.md` | ✅ Present |
| Architecture | `architecture-BMADMonorepoEFInternalTools-2026-03-15.md` | ✅ Present |
| Epics & Stories | `epics-ExpertflowInternalERP-2026-03-16.md` | ✅ Present |
| UX Design | *(none)* | ⚠️ Intentionally deferred (Epic 7) |

No duplicate documents detected. No sharded documents. Deferral of UX acknowledged.

---

## PRD Analysis

### Functional Requirements Extracted

FR1: Dockerized Directus v11 instance connecting to `bidstruct4` via Cloud SQL Auth Proxy.
FR2: All 42 tables registered as Directus collections with field metadata (labels, interfaces, display templates).
FR3: All FK relationships configured as Directus relational fields (M2O, O2M, M2M).
FR4: Directus REST API as sole communication layer; no direct DB access from frontend.
FR5: Directus Activity and Revisions logging for Finance-domain collections and `EmployeePersonalInfo` (per NFR8).
FR6: BankStatement import via Admin UI, each row atomic; `Transaction` FK null at import.
FR7: Zero-duplication on `BankStatement` via composite key `Account + BankTransactionID`; duplicates rejected with error.
FR8: Fallback dedup hash from `Date + Amount + Description + AccountID` when `BankTransactionID` unavailable.
FR9: Finance Manager reconciliation workflow: 3 options (match existing Transaction, spawn from Invoice, create new Transaction) to link `BankStatement.Transaction`.
FR10: Two-step BankStatement ↔ Transaction workflow; Transaction may link 0–2 BankStatements; third link rejected.
FR11: Full CRUD on `Transaction` for Finance Manager only.
FR12: `Journal` for polymorphic per-object attachments (`JournalLink.collection` + `JournalLink.item`); `LegalEntity.DocumentFolder` = canonical default org storage folder URL (not a substitute for `Journal` on other collections).
FR13: `Journal` does not enforce exclusive FK to any single table.
FR14: Directus Insights "Completeness Score" widget: % of Transactions with ≥1 linked Journal entry.
FR15: Full CRUD for `Invoice` to Finance Manager.
FR16: Full CRUD for `Allocation` exclusively to Finance Manager.
FR17: Full CRUD for `Accruals` exclusively to Finance Manager; invisible to all other roles.
FR18: `Currency` as reference lookup; Finance Manager editable.
FR19: `CurrencyExchange` CRUD for Finance Manager; historical rate management.
FR20: Directus Insights — **no** RLS bypass; P&L panels respect **FR21**/**FR40**.
FR21: **`executive`** = **`employee`** for sensitive reads; **no** special RLS tier.
FR22: HR Manager full CRUD on **all** `Employee` records; `DefaultProjectId` = default time/cost project only; `Employee.ProfitCenter` hidden from product.
FR23: `EmployeePersonalInfo` manageable by HR Manager and Employee (own record only).
FR24: `Seniority`, `Designation`, `department` as HR Manager CRUD reference tables.
FR25: `TimeEntry`: Employees own records; Line Managers read team; HR Manager reads all.
FR26: `Leaves` workflow: Employees submit; Line Managers approve/reject; HR Manager full CRUD.
FR27: `Task`: Employees update own status; Line Managers full CRUD team tasks; HR Manager reads all.
FR28: `Expense`: Employees create own; HR/Finance read all and update approval status.
FR29: File upload for expense receipts via Directus Files API.
FR30: `InternalCost` CRUD for Finance Manager; inter-ProfitCenter cost allocation.
FR31: Five Directus roles: `finance-manager`, `executive`, `hr-manager`, `line-manager`, `employee`.
FR32: Collection-level permissions per role per Access Control Matrix.
FR33: Four RLS tiers; HR Employee-ledger only (no Executive leg); line manager subordinate **payroll recurring `Invoice`** (+ linked rows).
FR34: `Accruals` and `Allocation` invisible (no read) to all roles except Finance Manager.
FR40: Four tiers — Finance / HR / line-manager comp. / baseline; **no** `executive` bypass.
FR41: `Journal` nuanced RBAC; **`Accruals` Finance-only (no HR/line/employee/executive read)**; `Allocation`/`InternalCost` Finance CRUD for others; **`CurrencyExchange`** per **FR19**.
FR35–FR39: Lovable SPA (employee self-service portal) — **intentionally deferred**.

**Total FRs: 41 | Directus backend FRs (FR1–FR34, FR40–FR41): 36 | Deferred (FR35–FR39): 5**

### Non-Functional Requirements Extracted

NFR1: All RBAC/RLS logic at Directus API layer. No security rule relies solely on frontend.
NFR2: DB credentials in local `.env` files only; production via Google Cloud Secret Manager.
NFR3: Zero per-user licensing fees; Directus OSS within BSL free tier.
NFR4: BankStatement dedup uses composite hash; rejected at API layer before DB write.
NFR5: Insights dashboards return aggregated results within 5s for baseline up to ~10k `Transaction` rows/month per ProfitCenter slice (PRD).
NFR6: All backend services in `docker-compose.yml`; reproducible with single `docker compose up`.
NFR7: All schema modifications during AI-assisted dev go through Directus API; no direct DDL/DML.
NFR8: Directus Activity/Revisions for Finance collections **and** `EmployeePersonalInfo`; role access per PRD.
NFR9: Directus Docker image deployable to Google Cloud Run; Cloud SQL Auth Proxy connectivity.
NFR10: All collection configs, field metadata, permissions exportable as `schema.json` in VCS.
NFR11: Employee PII sensitivity (`cnic`, `ntn`, etc.); retention/erasure Phase 2 unless compliance mandates earlier.

**Total NFRs: 11**

### PRD Completeness Assessment

The PRD is well-formed and implementation-ready. **§3 User Journeys** links personas to §5 FRs. Resolved assumptions (A1–A3, A7–A9) are condensed in §9; A5/A6 remain story TBD. **NFR11** covers PII handling gap. No critical omissions detected for backend Phase 4 gate.

---

## Epic Coverage Validation

### FR Coverage Matrix

| FR | PRD Summary | Epic Coverage | Status |
|---|---|---|---|
| FR1 | Dockerized Directus + Cloud SQL Auth Proxy | Epic 1 / Story 1.1 | ✅ Covered |
| FR2 | Register all 42 collections with field metadata | Epic 1 / Stories 1.2, 1.3, 1.4 | ✅ Covered |
| FR3 | Configure all FK relationships as relational fields | Epic 1 / Story 1.5 | ✅ Covered |
| FR4 | REST API as sole communication layer | Epic 1 / Story 7.1 (arch principle) | ✅ Covered |
| FR5 | Activity/Revisions for Finance + `EmployeePersonalInfo` | Epic 1 / Story 1.6 | ✅ Covered |
| FR6 | BankStatement import via Admin UI | Epic 3 / Story 3.1 | ✅ Covered |
| FR7 | Dedup via Account + BankTransactionID | Epic 3 / Story 3.1 | ✅ Covered |
| FR8 | Fallback hash dedup | Epic 3 / Story 3.1 | ✅ Covered |
| FR9 | 3-option reconciliation workflow | Epic 3 / Story 3.2 | ✅ Covered |
| FR10 | Two-step workflow + 0–2 cap enforcement | Epic 3 / Story 3.2 | ✅ Covered |
| FR11 | Transaction CRUD for Finance Manager | Epic 3 / Story 3.2 | ✅ Covered |
| FR12 | Journal per-object evidence; `LegalEntity.DocumentFolder` default storage | Epic 3 / Story 3.3; Epic 1 / Story 1.3 | ✅ Covered |
| FR13 | Journal non-exclusive FK design | Epic 3 / Story 3.3 | ✅ Covered |
| FR14 | Completeness Score Insights widget | Epic 6 / Story 6.1 | ✅ Covered |
| FR15 | Invoice CRUD for Finance Manager | Epic 3 / Story 3.4 | ✅ Covered |
| FR16 | Allocation CRUD for Finance Manager | Epic 3 / Story 3.4 | ✅ Covered |
| FR17 | Accruals Finance-only CRUD | Epic 3 / Story 3.5 | ✅ Covered |
| FR18 | Currency reference lookup | Epic 3 / Story 3.6 | ✅ Covered |
| FR19 | CurrencyExchange rate management | Epic 3 / Story 3.6 | ✅ Covered |
| FR20 | Insights — **no** RLS bypass; Executive P&L UX only where rows allowed | Epic 6 / Story 6.2 | ✅ Covered |
| FR21 | **`executive`** = **`employee`** on sensitive reads; no write on Finance/HR ops | Epic 2 / Story 2.4 | ✅ Covered |
| FR22 | HR Manager Employee CRUD (full roster; DefaultProject = time default) | Epic 4 / Story 4.1 | ✅ Covered |
| FR23 | EmployeePersonalInfo management | Epic 4 / Story 4.2 | ✅ Covered |
| FR24 | Seniority/Designation/department reference tables | Epic 4 / Story 4.3 | ✅ Covered |
| FR25 | TimeEntry logging and visibility | Epic 5 / Story 5.1 | ✅ Covered |
| FR26 | Leaves request and approval workflow | Epic 5 / Story 5.2 | ✅ Covered |
| FR27 | Task assignment and status tracking | Epic 5 / Story 5.3 | ✅ Covered |
| FR28 | Expense submission and approval | Epic 5 / Story 5.4 | ✅ Covered |
| FR29 | Receipt file upload via Directus Files API | Epic 5 / Story 5.4 | ✅ Covered |
| FR30 | InternalCost inter-ProfitCenter transfers | Epic 4 / Story 4.4 | ✅ Covered |
| FR31 | Create 5 Directus roles | Epic 2 / Story 2.1 | ✅ Covered |
| FR32 | Collection-level permissions per role | Epic 2 / Stories 2.2–2.5 | ✅ Covered |
| FR33 | Four RLS tiers + item-level filters; line-manager subordinate payroll **`Invoice`** | Epic 2 / Stories 2.3–2.5 | ✅ Covered |
| FR34 | Hide Accruals/Allocation from non-Finance | Epic 2 / Story 2.6 | ✅ Covered |
| FR40 | Four tiers: Finance / HR / line-manager comp. / baseline; **no** `executive` bypass | Epic 2 / Stories 2.3–2.6; Architecture §5.3, §8.4 | ✅ Covered |
| FR41 | Journal nuanced RBAC; **`Accruals` strict Finance-only**; Allocation/InternalCost Finance; **CurrencyExchange** FR19 | Epic 2 / Stories 2.3, 2.4, 2.6 | ✅ Covered |
| FR35 | Lovable SPA scaffold + Directus auth | Epic 7 / Story 7.1 | ⏸️ Deferred |
| FR36 | Active project list for time logging | Epic 7 / Story 7.2 | ⏸️ Deferred |
| FR37 | Daily Confirmation sparkline | Epic 7 / Story 7.3 | ⏸️ Deferred |
| FR38 | Leave request form | Epic 7 / Story 7.4 | ⏸️ Deferred |
| FR39 | Expense submission with receipt upload (SPA) | Epic 7 / Story 7.5 | ⏸️ Deferred |

### Coverage Statistics

- Total PRD FRs: 41 (FR1–FR34, FR40–FR41, plus FR35–FR39 deferred SPA)
- Directus backend FRs covered in epics: 36/36 — **100%**
- Lovable SPA FRs: 5/5 — **100%** (deferred to Epic 7, not blocking)
- NFRs addressed across epics: 11/11 — **100%**

---

## UX Alignment Assessment

### UX Document Status

Not found — intentional deferral confirmed by project owner.

The PRD's UX needs fall into two tiers:
1. **Admin roles (Finance Manager, HR Manager, Executive, Line Manager)**: Served by the standard Directus Admin UI. No custom UX spec required for Phase 1.
2. **Employee role (Lovable SPA)**: FR35–FR39 define SPA requirements captured in Epic 7. These are intentionally deferred.

### Alignment Issues

None — the architecture (ADR-09) explicitly calls out the Lovable SPA as a separate tier that communicates via Directus REST API. The deferral is structurally clean.

### Warnings

⚠️ **Epic 7 Pre-requisite**: When Lovable UX work resumes, a UX design document should be authored **before** Epic 7 story implementation begins. Story 7.3 also introduces a schema change (`confirmed` boolean on `TimeEntry`) — this should be coordinated against Directus's existing configuration from Epics 1–5 to avoid re-work.

---

## Architecture Alignment Assessment

### PRD ↔ Architecture Mapping

| PRD Requirement | Architecture Decision | Status |
|---|---|---|
| FR1 — Dockerized Directus + Cloud SQL Proxy | ADR-01 (Directus v11 OSS Docker), ADR-02 (Cloud SQL Auth Proxy) | ✅ Aligned |
| FR2 — All 42 collections with field metadata | Section 4.1, Field Interface Mapping table | ✅ Aligned |
| FR3 — FK relationships as relational fields | Section 4.2, Relationship Configuration | ✅ Aligned |
| FR5 / NFR8 — Audit logging Finance + `EmployeePersonalInfo` | Section 5.2; HR/Finance Activity access per story 1.6 | ✅ Aligned |
| FR7/FR8/FR10 — BankStatement dedup + 0–2 cap Hook | ADR-05, Section 4.2 (two-step workflow, Hook extensions) | ✅ Aligned |
| FR12/FR13 — Journal polymorphic pattern; `LegalEntity.DocumentFolder` default storage | ADR-06, Section 4.2 (Custom Interface + **`DocumentFolder`** note) | ✅ Aligned |
| NFR1 — Zero-Trust API layer | ADR-07, Section 5 (RBAC Architecture) | ✅ Aligned |
| NFR2 — Secret Management | ADR-03, Section 3.1 | ✅ Aligned |
| NFR6 — Containerization | Section 7.1 (docker-compose), Story 1.1 | ✅ Aligned |
| NFR9 — Cloud Run deployment | ADR-10, Section 7.2 | ✅ Aligned |
| NFR10 — Schema Snapshot in VCS | ADR-04, Story 1.7 | ✅ Aligned |
| FR20/FR21/FR33/FR40 — Four RLS tiers; **`executive`** = baseline; Insights **no** bypass | ADR-08 (revised), ADR-11, Section 5.3 | ✅ Aligned |
| NFR11 — Employee PII | Epic 4, Story 4.2 (field permissions); PRD NFR11 | ✅ Aligned |

### Architecture Gaps Identified

**GAP-1 (Major):** `directus_users` custom fields design is unresolved.
The permission filters for **optional** Executive **UX** (`$CURRENT_USER.profitCenter` for Insights defaults) and Employee/Line Manager (`$CURRENT_USER.employee_id`) depend on custom fields on `directus_users`. **RLS** for **line-manager** subordinate **payroll `Invoice`** rows may require **`UserToRole`** role **118** (or equivalent) per Architecture §8.4. Stories 2.4–2.5 mention these; capture in ADR or a dedicated story if missing.

**GAP-2 (Major):** Extension folder structure is incomplete in Architecture Section 6.1.
The project structure shows only `extensions/hooks/bank-statement-limit/` but Story 3.1 (FR7/FR8) requires a separate `extensions/hooks/bank-statement-dedup/` extension. Both are referenced in ADR-05 and Story 3.2 technical notes, but the canonical folder structure in Architecture Section 6.1 needs updating.

**GAP-3 (Major):** Google Cloud Storage configuration for file uploads has no story or ADR.
Architecture Section 7.2 lists GCS as the Directus file uploads bucket. However, no story covers configuring the Directus GCS storage adapter (`STORAGE_LOCATIONS=gcs`, `STORAGE_GCS_KEY_FILENAME`, bucket name). Story 5.4 assumes file upload works but only tests local behavior. If the first file upload story runs against a GCS-unconfigured production instance, it will fail silently.

**GAP-4 (Minor):** Story 3.2 Option B atomicity is not achievable via Directus Flows alone.
The technical note says "both operations are wrapped in a database transaction to ensure atomicity." Directus Flows do not support database transactions natively. This likely requires a custom API endpoint extension (`extensions/endpoints/`) rather than a Flow. The architecture does not anticipate a custom endpoint extension; this needs clarification before Epic 3 starts.

---

## Epic Quality Review

### Epic 1: Directus Platform Foundation

**User Value:** ⚠️ Borderline — this is an infrastructure/configuration epic. However, for a Directus-over-existing-schema project (brownfield), this is the correct foundation epic. The goal statement ("Admins can access a running, secured Directus instance") expresses user value. **Acceptable.**

**Story Quality:**
- Stories 1.1–1.7 follow a logical sequence: Docker → Financial Collections → Org/HR Collections → HR Ops + RBAC tables → Relationships → Audit Logging → Snapshot.
- Each story is independently completable and builds on prior story output correctly.
- ACs are in BDD (Given/When/Then) format throughout. ✅
- Story 1.7 (Schema Snapshot) is the correct integration point — ensures the entire epic's output is captured reproducibly.

**Issues:**
- 🟡 Story 1.4 Technical Notes: "Confirm enum values against DB before configuring dropdown" for `Expense.category` — this is a discovery task embedded in a configuration story. If DB confirms unexpected values, the story may need revision.

---

### Epic 2: Secure Role-Based Access Control

**User Value:** ✅ Clear user value — "Each persona sees only their permitted data from first login."

**Story Quality:**
- Stories 2.1 → 2.2 → 2.3 → 2.4 → 2.5 → 2.6 are correctly sequenced (create roles → configure each role's permissions → final navigation lockdown). ✅
- Story 2.6 (finalise navigation + regression test) is an excellent integration gate. ✅

**Issues:**
- 🟠 Story 2.4 Technical Note: "add a `profitCenter` field to `directus_users` or use a junction table" — this is an unresolved architectural decision deferred into story implementation. This is a **BLOCKER** for Story 2.4 if not decided first. Recommend adding a half-story or ADR addendum before Story 2.4 starts.
- 🟠 Story 2.5 Technical Note: "Requires mapping `currentUser` to their `Employee.id` — add `employee_id` as a custom field on `directus_users`." Same issue as 2.4. Both stories 2.4 and 2.5 should be preceded by a resolved mechanism for user attribute binding.

---

### Epic 3: Financial Ledger & Bank Management

**User Value:** ✅ Strong — Finance Manager can import, reconcile, invoice, journal-link, and currency-manage.

**Story Quality:**
- Story 3.1 (import + dedup Hook) is well-sized and cleanly separated from Story 3.2 (reconciliation + 0–2 cap Hook). ✅
- Story 3.3 (Journal) AC4 confirms file upload — this depends on Directus file storage configured properly (links to GAP-3). ⚠️

**Issues:**
- 🟠 Story 3.2 Option B atomicity: "Flow creates Transaction + patches BankStatement; wrapped in DB transaction." As noted in GAP-4, this is not achievable via native Directus Flows. The story's technical notes need to be updated to clarify that Option B requires a custom endpoint extension, not a Flow. This should be resolved before Story 3.2 starts.
- 🟡 Story 3.3 Technical Note: "Directus M2A or a custom approach" for Journal reverse panels is vague. ADR-06 specifies a Custom Interface extension. The story should reference ADR-06 explicitly and not leave "M2A vs custom" open.

---

### Epic 4: HR Administration & Employee Lifecycle

**User Value:** ✅ Clear HR Manager value.

**Story Quality:** Stories 4.1–4.4 are well-structured and independently completable. ✅

**Issues:**
- 🟡 Story 4.4 (InternalCost) is placed in the HR epic but is a Finance Manager operation. While FR30 is correctly placed here (it's an HR-lifecycle-adjacent cost collection), the story correctly scopes it to Finance Manager. The epic title could mislead — minor documentation concern only.

---

### Epic 5: Operational HR Tracking

**User Value:** ✅ Closes the employee operational loop.

**Story Quality:** Generally good BDD ACs.

**Issues:**
- 🔴 Story 5.2 (Leaves) schema gap: `Leaves.status` field does not exist in `bidstruct4`. The technical note flags this: "Confirm whether this requires a schema migration or Directus virtual field." This is unresolved and blocks Epic 5 Story 5.2. A concrete decision must be made and captured **before** Story 5.2 is implemented. Options:
  - (a) Directus virtual field (no DB migration needed — Directus stores it in its own metadata) — NOT possible; Directus can add fields to the DB but they must be real columns for item-level operations.
  - (b) Add a real `status` column to `Leaves` table in `bidstruct4` via a Directus field creation (which adds the column via the Admin UI) — this is the correct path but must be explicitly decided.
- 🔴 Story 5.4 (Expense) same issue: `Expense.status` field does not exist. Same resolution path required.
- 🟠 Story 5.3 (Task) field-level restriction gap: AC4 states "Employees can only update `Status`" but Directus item-level permissions work at the record level, not the field level. To prevent an Employee from updating `Employee` or `Project` fields on a Task, either (a) a custom validation Hook is needed, or (b) Directus field-level write permissions (available in Directus v11 via field presets / permissions) are used. This implementation path is not specified in the story. This needs clarification.

---

### Epic 6: Executive & Finance Insights Dashboards

**User Value:** ✅ Clear — eliminates manual reporting for Finance and Executives.

**Story Quality:**
- Story 6.1 (Completeness Score): The SQL query is correct but requires the Journal `JournalLink.collection` field to consistently contain the exact string `'Transaction'`. If future data uses different casing, the count breaks. Consider a future enum validation note.
- Story 6.2 (P&L Dashboard) correctly notes that Executive item-level filters (from Epic 2) automatically scope the underlying query data.

**Issues:**
- 🟡 NFR5 compliance: Both dashboards must respond within 5 seconds. This depends on `bidstruct4` having appropriate indexes on `Transaction.id`, `JournalLink.collection`, and `JournalLink.item`. No indexing story exists. Since the schema is pre-existing, these indexes may or may not be present. Story 6.1 technical notes should reference an index check.
- 🟡 Story 6.2 date-range filter: Technical notes suggest "consider adding a date-range filter control" — this is good but is it in scope for Phase 1? FR20 does not specify it. Should be explicitly flagged as out-of-scope or added as an optional enhancement in the story.

---

### Epic 7: Employee Self-Service Portal (Deferred)

**Not assessed for current Phase 4 readiness.** Deferred by design.

Pre-work for when Epic 7 begins:
- Create a UX design document before implementation
- Resolve Story 7.3's `TimeEntry.confirmed` schema change coordination with Epic 5
- Confirm GCS file storage (GAP-3) is resolved before Story 7.5

---

## Summary and Recommendations

### Overall Readiness Status

**Directus Backend (Epics 1–6): CONDITIONALLY READY**

The planning artifacts are comprehensive, internally consistent, and cover 100% of Directus backend requirements. The project may proceed to Phase 4 implementation for Epics 1–4 immediately. Epic 5 has two blocking schema gaps that must be resolved first; Epic 6 has a minor index concern.

---

### Issues by Severity

#### 🔴 Critical — Must Resolve Before Affected Epic Starts

| # | Issue | Blocks | Recommendation |
|---|---|---|---|
| C1 | `Leaves.status` field missing from `bidstruct4` schema — unresolved decision (migration vs virtual) | Epic 5 / Story 5.2 | Decide: use Directus Admin UI to add a real `status` column to `Leaves`. Capture as a pre-condition note in Story 5.2. |
| C2 | `Expense.status` field missing from `bidstruct4` schema — same issue | Epic 5 / Story 5.4 | Same resolution as C1. Add `status` column to `Expense`. |

#### 🟠 Major — Should Resolve Before Affected Story Starts

| # | Issue | Blocks | Recommendation |
|---|---|---|---|
| M1 | `directus_users` custom fields design for `profitCenter` and `employee_id` is an unresolved architectural decision embedded in story technical notes | Epic 2 / Stories 2.4, 2.5 | Add a short "Story 2.0: Configure Directus User Attributes" or an ADR addendum specifying the exact mechanism (custom user fields via Directus Settings → Data Model → `directus_users`). |
| M2 | Extension folder structure in Architecture Section 6.1 is missing `bank-statement-dedup/` | Epic 3 / Story 3.1 | Update Architecture Section 6.1 to include `extensions/hooks/bank-statement-dedup/`. |
| M3 | GCS file storage configuration has no story or ADR | Epic 3 / Story 3.3 (file upload), Epic 5 / Story 5.4 | Add a sub-task or technical note to Story 1.1 (Docker Compose) covering Directus GCS storage adapter environment variables (`STORAGE_LOCATIONS`, `STORAGE_GCS_BUCKET`, etc.) and Secret Manager injection. |
| M4 | Story 3.2 Option B atomicity is not achievable via Directus Flows — needs custom endpoint extension | Epic 3 / Story 3.2 | Update Story 3.2 technical notes to specify a custom `extensions/endpoints/` implementation for Option B. Add to Architecture Section 6.1 folder structure. |
| M5 | Story 5.3 Employee field-level write restriction (`Status` only) implementation path not specified | Epic 5 / Story 5.3 | Clarify in Story 5.3 technical notes: use Directus v11 field-level write permissions (`fields` array in the Directus permissions config) to restrict Employee writes to `Status` only on `Task`. |

#### 🟡 Minor — Note for Implementation

| # | Issue | Note |
|---|---|---|
| m1 | `Project.Status` and `Expense.category` enum values TBD (PRD A5/A6) | Stories 1.3 and 1.4 correctly flag this as a DB confirmation task. Low risk — dev will discover and update in-story. |
| m2 | NFR5 compliance depends on existing indexes in `bidstruct4` for Journal + Transaction | Add an index check to Story 6.1 technical notes: `CREATE INDEX IF NOT EXISTS idx_journal_ref ON "Journal"("JournalLink.collection", "JournalLink.item")`. |
| m3 | Story 3.3 Journal reverse panel: "M2A or custom approach" is vague | Update to explicitly reference ADR-06 (Custom Interface extension) and remove the ambiguous "M2A" alternative. |
| m4 | Story 6.2 date-range filter control is suggested but not in FR20 | Explicitly mark as optional / Phase 2 enhancement in Story 6.2. |
| m5 | Epic 7 Story 7.3 adds `confirmed` field to `TimeEntry` — cross-epic schema impact | Flag for awareness when Epic 7 planning resumes. |
| m6 | Redis decision is open (mentioned as optional in Architecture Section 7.1) | Not blocking. Decide before production GCR deployment. |

---

### Recommended Next Steps

1. **Start Epic 1 immediately** — no blockers. Story 1.1 (Docker Compose) is a clean greenfield story.
2. **Resolve M1 before beginning Epic 2 Story 2.4** — add a "Story 2.0: Configure Directus User Attributes" or ADR addendum for `profitCenter` and `employee_id` on `directus_users`. This is a one-session configuration decision.
3. **Resolve M3 (GCS config) and M4 (Option B atomicity) in the Story 1.1 / 3.2 implementation sessions** — these are technical note updates that don't require new planning artifacts, just story amendments.
4. **Resolve C1 and C2 before beginning Epic 5** — confirm that Directus Add Field UI will be used to add `status` columns to `Leaves` and `Expense` tables. Update Stories 5.2 and 5.4 technical notes accordingly.
5. **Create UX design document before Epic 7 implementation** — no timeline pressure given the deferral, but it should precede Epic 7 story creation.

---

### Final Note

This assessment identified **11 issues** across **3 severity categories**: 2 Critical, 5 Major, 6 Minor. None of the Critical issues block starting Epics 1–4. Epic 5 cannot start until C1 and C2 are resolved (a quick schema decision, not a re-planning exercise). Epic 6 is unblocked.

The planning artifacts are of high quality. FR/NFR traceability is complete. Architecture decisions are well-reasoned and internally consistent. The epics are appropriately sequenced with clean dependency chains.

**Verdict: Proceed to Phase 4 implementation starting with Epic 1.**

---

*Report generated: 2026-03-16 | Assessor: Winston (Architect) | BMAD Implementation Readiness Workflow v6.2.0*


