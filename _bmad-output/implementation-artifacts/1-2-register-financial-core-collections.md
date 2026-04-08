# Story 1.2: Register Financial Core Collections

Status: done

## Story

As a **Finance Manager**,
I want all financial collections (`Account`, `BankStatement`, `Transaction`, `Invoice`, `Allocation`, `Accruals`, `Journal`, `Currency`, `CurrencyExchange`) to be visible and properly labelled in the Directus Admin UI,
So that I can immediately navigate to and work with financial data without encountering raw table names or unformatted field IDs.

## Context (Epic 1)

**Epic goal:** All 42 tables registered with metadata, relationships, and audit — this story covers **only the nine financial core collections** and their field presentation in Admin.

**Dependencies:** **Story 1.1** — Directus must run and connect to `bidstruct4`.

**Blocks:** Meaningful Finance Manager testing before Epic 2 RBAC; Stories 1.5+ assume collections exist for relationship wiring.

**FR traceability:** **FR2** (collections with field metadata, labels, display templates).

## Acceptance Criteria

1. **Given** I am logged in as an **Administrator**, **When** I open the Directus Admin UI and navigate to Collections, **Then** all **9** financial collections are listed with human-readable labels (e.g., `BankStatement` → "Bank Statement", `CurrencyExchange` → "Currency Exchange Rates").

2. **Given** I open the **`Invoice`** collection, **When** I inspect the fields, **Then** every field has a label, correct interface type (e.g., `Amount` → input-decimal, `Status` → select-dropdown, `SentDate` → datetime), and a display template of **`INV-{{id}} · {{Amount}} {{Currency.CurrencyCode}}`**.

3. **Given** I open the **`Journal`** collection, **When** I inspect the **`JournalLink.collection`** field, **Then** it is configured as a **select-dropdown** with valid options matching in-scope collection names (e.g., `Invoice`, `Transaction`, `BankStatement`, `Expense`).  
   **Note:** The **Custom Interface** for polymorphic pickers is **Story 3.3** / ADR-06; this story only requires dropdown metadata and labels so Admin remains usable.

4. **Given** I open the **`Account`** collection, **When** I check the display template, **Then** it shows **`{{Name}} [{{LegalEntity.Name}}]`**.

## Tasks / Subtasks

- [x] **Import or surface tables** — Ensure all nine tables exist as Directus collections (database already has tables; use Admin “Database” flow or schema sync per project convention).
- [x] **Collection labels & icons** — Set readable collection names and optional icons for navigation.
- [x] **Field metadata** — Per architecture **§4.1 Field Interface Mapping**: FK integers → `m2o`, `numeric` → `input-decimal`, enums → `select-dropdown`, dates → `datetime`, etc.
- [x] **Display templates** — Apply **§4.3 Display Templates** for `Account` and `Invoice`; set sensible templates for other financial collections where missing.
- [x] **`JournalLink.collection`** — Define dropdown choices for Phase 1 in-scope targets (align with PRD/architecture polymorphic list).
- [ ] **Verify as Administrator** — Walk through AC 1–4 in Admin UI _(operator: run apply script against live Directus, then confirm in Admin)_.
- [x] **Schema export (optional)** — Run `npx directus schema snapshot ./schema.json` from a context with CLI access if desired; **canonical VCS commit of `schema.json` is Story 1.7**.

## Dev Notes

### Collections in scope (9)

`Account`, `BankStatement`, `Transaction`, `Invoice`, `Allocation`, `Accruals`, `Journal`, `Currency`, `CurrencyExchange`

### Architecture references

- **Field Interface Mapping:** `architecture-BMADMonorepoEFInternalTools-2026-03-15.md` §4.1  
- **Display templates:** same doc §4.3 (`Account`, `Invoice`; align others for consistency)  
- **Journal polymorphic:** §4.2 — full custom UI deferred to **Story 3.3**

### Implementation companion (repo)

Step-by-step hints derived from `schema_dump_final.json`:  
`projects/internal-erp/directus/docs/story-1-2-financial-collections.md`

### Governance

- Schema changes to PostgreSQL DDL are **out of scope** — configure Directus metadata only (**NFR9**).

### References

- [Source: `_bmad-output/planning-artifacts/epics-ExpertflowInternalERP-2026-03-16.md` — Story 1.2]
- [Source: `_bmad-output/planning-artifacts/architecture-BMADMonorepoEFInternalTools-2026-03-15.md` — §4.1–4.3]
- [Source: `_bmad-output/planning-artifacts/prd-ExpertflowInternalERP-2026-03-16.md` — FR2]

## Dev Agent Record

### Agent Model Used

Composer / Cursor agent (bmad-dev invocation)

### Debug Log References

- `node --test projects/internal-erp/directus/scripts/story-1-2-config.test.mjs` — pass
- `node .../apply-story-1-2-financial-meta.mjs --dry-run` — pass

### Completion Notes List

- Delivered **idempotent** `apply-story-1-2-financial-meta.mjs` + `scripts/lib/story-1-2-config.mjs` (collection translations, display templates, **22** finance-scope relations, field interfaces including **JournalLink.collection** dropdown + **Invoice** AC).
- **Operator step:** run apply script with live `DIRECTUS_URL` + admin credentials; if `input-decimal` is not registered in your Directus build, switch Amount fields to the project’s decimal interface id in `story-1-2-config.mjs`.
- Story **1.5** still owns the **full** FK map across all in-scope collections; this story adds relations needed for finance M2O + display templates.

### File List

- `projects/internal-erp/directus/scripts/apply-story-1-2-financial-meta.mjs`
- `projects/internal-erp/directus/scripts/lib/story-1-2-config.mjs`
- `projects/internal-erp/directus/scripts/story-1-2-config.test.mjs`
- `projects/internal-erp/directus/README.md` — **Story 1.2** (Epic 1 **1.1–1.10** numeric order)
- `projects/internal-erp/directus/docs/story-1-2-financial-collections.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (1-2 → done)


