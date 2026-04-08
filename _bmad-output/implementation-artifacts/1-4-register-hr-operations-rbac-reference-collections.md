# Story 1.4: Register HR Operations & Hide Out-of-Scope (CPQ/CRM/Ticket) Collections

Status: backlog

**PM — deferred priority (2026-03-17):** After **security wave** (**1-9**, **1-10**, **1-8**), **1-5–1-7**, **Epic 2**, **Epic 3**, **Epic 6**, and **Epics 4–5** in `sprint-status.yaml`. **`Role` / `RolePermissions` / `UserToRole` → Story 1.9** (not this story). **Hiding** CPQ/CRM/ticket collections is **lowest** Phase 1 product value.

## Story

As an **HR Manager** and **Administrator**,
I want HR operational collections (`TimeEntry`, `Leaves`, `Task`, `Expense`, `InternalCost`) registered in Directus, and out-of-scope CPQ/CRM/ticket tables hidden from navigation,
So that the Admin UI stays focused on Phase 1 ERP scope.

## Context (Epic 1)

**Dependencies:** Stories **1.2–1.3**. **`Role*`:** **Story 1.9**.

**Blocks:** None for bank path (**1-5**). HR ops flows (**Epic 5**) benefit from this story when scheduled.

**FR traceability:** **FR2**; navigation hygiene supports **FR31+** (with **Epic 2**).

## Acceptance Criteria

1. **Given** I am logged in as an **Administrator**, **When** I open the **`TimeEntry`** collection, **Then** **`StartDateTime`** and **`EndDateTime`** are **datetime** fields, **`HoursWorked`** is **text** (ISO 8601 duration string per architecture), and **`Employee`**, **`Project`**, **`Task`** are **M2O** dropdowns.

2. **Given** I open the **`Expense`** collection, **When** I view the **`category`** field, **Then** it is a **select-dropdown** with enum values **confirmed from the PostgreSQL `USER-DEFINED` type** in the live DB (TBD list until introspected).

3. **Given** I navigate to **Collection settings** as Administrator, **When** I view the collection list, **Then** all **13** out-of-scope collections are **hidden** from navigation:  
   `product_catalogue`, `offers`, `offer_line_items`, `Deal`, `Quotes`, `QuoteLineItems`, `ProductDependencies`, `SalesScriptRequests`, `ChatLogs`, `KnowledgeSources`, `sla_definitions`, `tickets`, `ticket_updates`  
   **And** **`TestDebug`** is also hidden.

## Tasks / Subtasks

- [ ] Register **`TimeEntry`**, **`Leaves`**, **`Task`**, **`Expense`**, **`InternalCost`** with labels and §4.1 interfaces.
- [ ] Introspect **`Expense.category`** enum values; configure dropdown.
- [ ] Mark **13 + TestDebug** collections as hidden / not shown in navigation (per Directus collection settings).
- [ ] Verify AC 1–3.
- [ ] **Schema snapshot:** Story **1.7** for committed `schema.json`.

## Dev Notes

- Hidden collections **retain data**; hiding is Directus presentation (**epics** technical notes).
- **`Expense.category`**: confirm against DB before shipping dropdown options (implementation-readiness A6).

### References

- `_bmad-output/planning-artifacts/epics-ExpertflowInternalERP-2026-03-16.md` — Story 1.4
- `_bmad-output/planning-artifacts/architecture-BMADMonorepoEFInternalTools-2026-03-15.md` — §4.1
- `schema_dump_final.json`

## Dev Agent Record

### Agent Model Used

_(filled by dev agent)_

### Debug Log References

### Completion Notes List

### File List

- `projects/internal-erp/directus/README.md` — **Story 1.4** (deferred); Epic 1 **Story 1.1–1.10** are in numeric order in that file.
