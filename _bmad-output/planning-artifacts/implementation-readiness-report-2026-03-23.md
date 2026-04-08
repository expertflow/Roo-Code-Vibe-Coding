---
stepsCompleted: [1, 2, 3, 4, 5, 6]
inputDocuments:
  - _bmad-output/planning-artifacts/prd-ExpertflowInternalERP-2026-03-16.md
  - _bmad-output/planning-artifacts/architecture-BMADMonorepoEFInternalTools-2026-03-15.md
  - _bmad-output/planning-artifacts/epics-ExpertflowInternalERP-2026-03-16.md
date: '2026-03-23'
assessor: 'Winston'
---
# Implementation Readiness Assessment Report

**Date:** 2026-03-23
**Project:** BMADMonorepoEFInternalTools

## Document Discovery

### Selected Documents

- PRD: `_bmad-output/planning-artifacts/prd-ExpertflowInternalERP-2026-03-16.md`
- Architecture: `_bmad-output/planning-artifacts/architecture-BMADMonorepoEFInternalTools-2026-03-15.md`
- Epics: `_bmad-output/planning-artifacts/epics-ExpertflowInternalERP-2026-03-16.md`

### Discovery Findings

- No duplicate whole-vs-sharded document sets found for PRD, Architecture, or Epics.
- No dedicated UX specification document found in planning artifacts.

## PRD Analysis

### Functional Requirements

FR1: Dockerized Directus v11 connects to `bidstruct4` through Cloud SQL Auth Proxy.  
FR2: All 42 tables from `schema_dump_final.json` are registered as Directus collections with field metadata and operator-friendly references.  
FR3: All foreign keys present in the schema are configured as Directus relational fields.  
FR4: Directus REST API is the sole communication layer for all clients.  
FR5: Activity/Revisions logging is enabled for finance collections and `EmployeePersonalInfo`.  
FR6: `BankStatement` import supports unreconciled rows.  
FR7: Deduplication on `BankStatement` uses `Account + BankTransactionID`.  
FR8: Fallback hash deduplication is supported when `BankTransactionID` is missing.  
FR9: Finance can reconcile `BankStatement` rows to `Transaction` records using supported workflows.  
FR10: `BankStatement -> Transaction` uses the two-step nullable import plus 0-2 linkage cap.  
FR11: Finance Manager has CRUD on `Transaction`.  
FR12: `Journal` supports polymorphic evidence linking.  
FR13: `Journal` does not use an exclusive single-table FK.  
FR14: Completeness Score dashboard reports `Transaction` evidence coverage.  
FR15: Finance Manager has CRUD on `Invoice`.  
FR16: Finance Manager has CRUD on `Allocation`.  
FR17: Finance Manager has exclusive CRUD on `Accruals`.  
FR18: `Currency` is a reference lookup.  
FR19: Finance Manager manages `CurrencyExchange` historical rates.  
FR20: Executive sees Profit/Loss through Insights only.  
FR21: Executive reads `Project` only, scoped by ProfitCenter.  
FR22: HR Manager has CRUD on `Employee`; `DefaultProjectId` is operational only.  
FR23: HR Manager and self-service owner manage `EmployeePersonalInfo`.  
FR24: HR manages `Seniority`, `Designation`, and `department` reference collections.  
FR25: `TimeEntry` supports employee/team/HR visibility model.  
FR26: `Leaves` supports employee submission and line-manager approval.  
FR27: `Task` supports employee/team workflows.  
FR28: `Expense` supports employee submission and HR/Finance review.  
FR29: Expense receipt upload uses Directus Files API.  
FR30: `InternalCost` supports Finance Manager CRUD for inter-ProfitCenter allocations.  
FR31: Five Directus roles are created.  
FR32: Collection-level permissions match the access model.  
FR33: Item-level permission filters enforce executive, HR, employee, and line-manager scope.  
FR35-FR39: Dedicated employee SPA requirements are explicitly deferred.  
FR40: Financial ledger visibility is derived from `Account -> LegalEntity.Type`, not `Employee` joins.  
FR41: `Journal`, `Allocation`, `Accruals`, and `CurrencyExchange` are Finance-only.

Total FRs: 40

### Non-Functional Requirements

NFR1: Dual-layer security with Directus RBAC plus PostgreSQL RLS.  
NFR2: Secrets stay in `.env` / secret manager only.  
NFR3: Zero per-user licensing cost.  
NFR4: Deduplication enforces data integrity at API layer before write.  
NFR5: Insights performance target under 5 seconds.  
NFR6: Full local environment reproducible through `docker compose up`.  
NFR7: AI-assisted development uses Directus API only.  
NFR8: Audit trail enabled for finance collections and `EmployeePersonalInfo`.  
NFR9: Deployment remains Cloud Run compatible.  
NFR10: Directus schema is exportable and version-controlled.  
NFR11: Employee PII is protected.  
NFR12: Production authentication uses external IdP with JIT provisioning rules.  
NFR13: RLS defense in depth on sensitive tables.  
NFR14: Data administration surface must show human-readable references.

Total NFRs: 14

### Additional Requirements

- Architecture and PRD both encode current field-level assumptions for `Transaction`, `Invoice`, `CurrencyExchange`, `InternalCost`, and `Project`.
- Several requested SQL deletions conflict with current approved requirement text, not just implementation metadata.

### PRD Completeness Assessment

- The PRD is complete enough to drive implementation, but it is **not aligned** with the requested schema cleanup.
- The most material readiness issue is that the approved PRD still names several legacy fields as supported product fields.

## Epic Coverage Validation

### Coverage Matrix

| FR Number | PRD Requirement | Epic Coverage | Status |
| --------- | --------------- | ------------- | ------ |
| FR1 | Dockerized Directus + Cloud SQL Proxy | Epic 1 | Covered |
| FR2 | Register all tables / collections | Epic 1 | Covered |
| FR3 | Configure all FK relationships | Epic 1 | Covered |
| FR4 | Directus REST as sole client API | Epic 1 | Covered |
| FR5 | Activity/Revisions logging | Epic 1 | Covered |
| FR6 | BankStatement import | Epic 3 | Covered |
| FR7 | BankStatement deduplication | Epic 3 | Covered |
| FR8 | Fallback dedup hash | Epic 3 | Covered |
| FR9 | Transaction reconciliation workflow | Epic 3 | Covered |
| FR10 | Nullable import + 0-2 cap | Epic 3 | Covered |
| FR11 | Transaction CRUD | Epic 3 | Covered |
| FR12 | Journal polymorphic evidence | Epic 3 | Covered |
| FR13 | Journal non-exclusive FK design | Epic 3 | Covered |
| FR14 | Completeness Score dashboard | Epic 6 | Covered |
| FR15 | Invoice CRUD | Epic 3 | Covered |
| FR16 | Allocation CRUD | Epic 3 | Covered |
| FR17 | Accruals finance-only CRUD | Epic 3 | Covered |
| FR18 | Currency lookup | Epic 3 | Covered |
| FR19 | CurrencyExchange management | Epic 3 | Covered |
| FR20 | Executive P&L dashboard | Epic 6 | Covered |
| FR21 | Executive reads Project only | Epic 2 | Covered |
| FR22 | Employee CRUD | Epic 4 | Covered |
| FR23 | EmployeePersonalInfo | Epic 4 | Covered |
| FR24 | Reference HR collections | Epic 4 | Covered |
| FR25 | TimeEntry workflow | Epic 5 | Covered |
| FR26 | Leaves workflow | Epic 5 | Covered |
| FR27 | Task workflow | Epic 5 | Covered |
| FR28 | Expense workflow | Epic 5 | Covered |
| FR29 | Expense file upload | Epic 5 | Covered |
| FR30 | InternalCost workflow | Epic 4 | Covered |
| FR31 | Five Directus roles | Epic 2 | Covered |
| FR32 | Collection permissions | Epic 2 | Covered |
| FR33 | Item-level filters | Epic 2 | Covered |
| FR35 | Deferred SPA scaffold | Epic 7 deferred | Covered (Deferred) |
| FR36 | Deferred SPA project ordering | Epic 7 deferred | Covered (Deferred) |
| FR37 | Deferred daily confirmation | Epic 7 deferred | Covered (Deferred) |
| FR38 | Deferred SPA leave form | Epic 7 deferred | Covered (Deferred) |
| FR39 | Deferred SPA expense form | Epic 7 deferred | Covered (Deferred) |
| FR40 | Ledger visibility by LegalEntity.Type | Epic 2 + Architecture | Covered |
| FR41 | Finance-only collections | Epic 2 | Covered |

### Missing Requirements

- No PRD FRs are uncovered in the epics document.
- One epic requirement exists without a matching PRD requirement number: `FR34` appears in epics as a finance-only visibility rule but is not present in the approved PRD numbering.

### Coverage Statistics

- Total PRD FRs: 40
- FRs covered in epics: 40
- Coverage percentage: 100%

## UX Alignment Assessment

### UX Document Status

Not Found

### Alignment Issues

- Phase 1 is still user-facing because operators and employees use Directus Admin and extensions, so UX is implied even without a standalone SPA.
- The absence of a dedicated UX document is acceptable only because the epics explicitly defer the standalone employee SPA and rely on Directus-first workflows.

### Warnings

- UX is implied for finance and HR operators but not captured in a separate UX artifact.
- For this specific schema cleanup, operator impact is real: removing fields changes collection forms, filters, and relation behaviors, yet there is no UX note documenting the intended post-cleanup forms.

## Epic Quality Review

### Critical Violations

- The approved planning set still encodes legacy schema fields you now want removed:
  - PRD FR11 explicitly names `Transaction` fields including `BankStatementId`, `image`, and `expense_id`.
  - PRD FR15 explicitly names `Invoice.Transaction` and `Invoice.image`.
  - PRD FR19 explicitly names `CurrencyExchange` fields `Day`, `Key`, `Year`, and `Month`.
  - PRD FR30 explicitly names `InternalCost` fields `FromPC`, `ToPC`, and `TimeEntryId`.
- This means the requested SQL deletions are **not implementation-ready against the current approved requirements**.

### Major Issues

- Epic 1 Story 1.2 and Story 1.5 artifacts still assume the old field set for finance metadata / relations.
- Architecture still treats current field shapes as the working schema, so deleting columns without updating architecture would break traceability.
- The entity cleanup spans multiple epics (`1`, `2`, `3`, `4`, `5`, `6`) but there is no dedicated change-control story or ADR addendum describing the new canonical schema.

### Minor Concerns

- `FR34` exists in epics but not in the PRD numbering, which weakens traceability discipline.
- No dedicated UX artifact explains what the slimmer forms should look like after schema cleanup.

## Summary and Recommendations

### Overall Readiness Status

NOT READY

### Critical Issues Requiring Immediate Action

- Update the PRD to remove or rename the legacy fields before continuing broad SQL cleanup:
  - `CurrencyExchange.Day/Key/Year/Month`
  - `InternalCost.FromPC/ToPC/TimeEntryId`
  - `Invoice.Transaction`
  - `Project.legal_entity_id`
  - `Transaction.expense_id/image`
- Update Architecture §4 / relationship mapping to match the reduced schema.
- Update Epic 1 / Epic 3 / Epic 4 story artifacts so Directus metadata and FK stories stop recreating deleted relationships or fields.

### Recommended Next Steps

1. Create a short schema-change decision record or PRD amendment for the new canonical field set.
2. Update PRD, Architecture, and affected epic/story artifacts before further destructive SQL drops.
3. After artifact alignment, apply SQL drops and immediately regenerate schema metadata (`schema_dump_final.json`, Directus field config, relation scripts).

### Final Note

This assessment identified 7 material issues across requirements traceability, architecture alignment, story alignment, and UX/documentation. Address the specification drift before proceeding with the remaining database-entity deletions.
