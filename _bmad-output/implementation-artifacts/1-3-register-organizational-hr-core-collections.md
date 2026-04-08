# Story 1.3: Register Organizational & HR Core Collections

Status: done

## Story

As an **HR Manager** and **Administrator**,
I want all organizational and HR core collections (`LegalEntity`, `ProfitCenter`, `Project`, `CountryLocation`, `Contact`, `Company`, `Employee`, `EmployeePersonalInfo`, `Seniority`, `Designation`, `department`) visible and correctly configured in Directus,
So that I can manage employee and organizational data with intuitive field labels and correctly linked reference dropdowns.

## Context (Epic 1)

**Epic goal:** Full collection registration for Phase 1 — this story covers **11** org/HR core tables (not HR ops like `TimeEntry`; those are Story **1.4**).

**Dependencies:** **Story 1.1** (running Directus). **Story 1.2** should be complete or in parallel only if collections are registered in dependency-safe order (register referenced lookups before heavy M2Os where Directus requires it).

**Blocks:** Story **1.4** (HR ops reference `Employee`, `Project`, etc.), Story **1.5** (FK relationships across these collections).

**FR traceability:** **FR2**.

**Operator reference presentation (CMS-agnostic):** **`_bmad-output/planning-artifacts/data-admin-surface-requirements.md`** (**PRD NFR14**). Phase 1 implementation binding: Architecture **ADR-14 / §4.4** (Directus today).

## Acceptance Criteria

1. **Given** I am logged in as an **Administrator**, **When** I navigate to the **`Employee`** collection, **Then** the display template shows **`{{EmployeeName}} ({{email}})`** and the **`ManagerId`** field is a **self-referential M2O** back to **`Employee`**.

2. **Given** I open a **`Project`** record, **When** I view the **`ProfitCenter`** field, **Then** it renders as an **M2O** dropdown listing all **`ProfitCenter`** records by name.

3. **Given** I open the **`LegalEntity`** collection, **When** I inspect the **`Type`** field, **Then** it is configured as a **select-dropdown**. The display template shows **`{{Name}} ({{Type}})`**.

4. **Given** I open the **`EmployeePersonalInfo`** collection, **When** I view the **`employee_id`** field, **Then** it is configured as a **1:1 M2O** link to **`Employee`**, displaying the employee name.

## Tasks / Subtasks

- [x] Register or surface all **11** collections in Directus with **human-readable collection names** (per **`data-admin-surface-requirements.md`** §1 / **NFR14**).
- [x] Apply architecture **§4.1** field interfaces (FK → `m2o`, `USER-DEFINED` → `select-dropdown`, `date` → `datetime`, etc.).
- [x] **`Employee`**: set display template per AC1; configure **`ManagerId`** → M2O → `Employee`.
- [x] **`Employee`**: **`ProfitCenter`** column exists in DB as `text` — **omit/hide** from Directus collection config in Phase 1 (PRD A2 / FR22); do not expose in Admin or API field list for app roles.
- [x] **`Project`**: **`ProfitCenter`** M2O; **`Status`** is `USER-DEFINED` enum — `select-dropdown`; **verify enum values** against DB (epics suggest `Active`, `Inactive`, `Archived` — confirm).
- [x] **`LegalEntity`**: display template and **`Type`** dropdown per AC3.
- [x] **`EmployeePersonalInfo`**: M2O to `Employee` with display using employee name; note **NFR11** / Story **4.2** for PII field permissions later.
- [ ] Verify AC 1–4 in Admin as Administrator _(after running apply script against your Directus instance)_.
- [ ] **Schema export:** optional incremental snapshot; **canonical `schema.json` commit is Story 1.7**.

## Dev Notes

### Collections in scope (11)

`LegalEntity`, `ProfitCenter`, `Project`, `CountryLocation`, `Contact`, `Company`, `Employee`, `EmployeePersonalInfo`, `Seniority`, `Designation`, `department`

### DB reference

- Canonical column list: repo root **`schema_dump_final.json`**.

### Architecture references

- **§4.1** Field Interface Mapping  
- **§4.3** Display templates (`Employee`, `Project`, `LegalEntity`)

### Governance

- **No PostgreSQL DDL** — Directus metadata only (**NFR9**).

### References

- [Source: `_bmad-output/planning-artifacts/epics-ExpertflowInternalERP-2026-03-16.md` — Story 1.3]
- [Source: `_bmad-output/planning-artifacts/architecture-BMADMonorepoEFInternalTools-2026-03-15.md` — §4.1, §4.3]
- [Source: `_bmad-output/planning-artifacts/prd-ExpertflowInternalERP-2026-03-16.md` — FR2, FR22, A2]

## Dev Agent Record

### Agent Model Used

Composer (Cursor agent)

### Debug Log References

- `node --test projects/internal-erp/directus/scripts/story-1-3-config.test.mjs`

### Completion Notes List

- Idempotent REST apply script + schema-validated config (same pattern as Story 1.2).
- **Employee.ProfitCenter** patched with `meta.hidden: true` (Phase 1 hide per FR22/A2).
- Relations include **department** / **Designation** custom PKs via `field_one` where required by Directus.

### File List

- `projects/internal-erp/directus/scripts/lib/story-1-3-config.mjs`
- `projects/internal-erp/directus/scripts/apply-story-1-3-org-hr-meta.mjs`
- `projects/internal-erp/directus/scripts/story-1-3-config.test.mjs`
- `projects/internal-erp/directus/docs/story-1-3-org-hr-collections.md`
- `projects/internal-erp/directus/README.md` — **Story 1.3** (Epic 1 **1.1–1.10** numeric order)
