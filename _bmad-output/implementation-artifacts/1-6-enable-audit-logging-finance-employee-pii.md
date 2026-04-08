# Story 1.6: Enable audit logging (Finance + `EmployeePersonalInfo`)

Status: **deferred** (2026-03-24 — pick up after cloud Directus / when audit verification is scheduled; no code blocker; Administrator checklist remains in this file.)

## Story

As a **Finance Manager** and **HR Manager**,  
I want Directus **Activity** and **Revisions** logging enabled for all Finance-domain collections **and** for **`EmployeePersonalInfo`** (**NFR8**),  
So creates/updates/deletes on financial records and sensitive HR PII are tracked with timestamp and acting user.

**Normative epic:** `_bmad-output/planning-artifacts/epics-ExpertflowInternalERP-2026-03-16.md` — Story 1.6.

## Implementation approach (repo)

| Mechanism | Role |
|-----------|------|
| **Directus core** | **Activity** / **Revisions** are **on by default** for collections; no extra extension required for baseline logging. |
| **Epic 2 (later)** | **Finance Manager** / **HR Manager** **read** access to **`directus_activity`** (and filtered views) per epic technical notes — **not** a blocker for **Administrator** verification of **1.6** AC. |

**No second `@expertflow.com` required:** all **1.6** checks below are **Administrator** (or equivalent) UI smoke — see **Operator checklist**.

## Tasks / Subtasks

- [ ] **Administrator smoke — Activity:** Create a test **`Invoice`** (or use sandbox row); confirm **Settings → Activity** (or **Module → Activity**) shows **create** with collection, item id, user, time.
- [ ] **Administrator smoke — Revisions:** Update **`Transaction.Amount`** (or other scalar) on an existing row; open item **Revisions** / history; confirm before/after for the field.
- [ ] **Delete path:** Delete (or soft-delete if policy forbids hard delete) a **`BankStatement`** test row **if safe**; confirm **delete** (or equivalent) in Activity — _skip if production data policy forbids._
- [ ] **`EmployeePersonalInfo`:** Update a non-production test field (e.g. dummy note if available) or document **read-only** env; confirm Activity/Revisions for that collection.
- [ ] **Collections in scope** (spot-check at least one op each where allowed): `Account`, `BankStatement`, `Transaction`, `Invoice`, `Allocation`, `Accruals`, `Journal`, **`EmployeePersonalInfo`**.
- [ ] **Epic 2 follow-up:** Track **Finance / HR** role permissions on **`directus_activity`** in **`2-*` implementation artifacts** (optional note in **1.6** completion when Epic 2 starts).

## Operator checklist (copy/paste)

1. Log in as **Administrator** (or user with access to Activity).
2. **Invoice → create** → **Activity** shows `create` / `Invoice` / your user.
3. **Transaction → edit field → save** → item **Revisions** shows delta.
4. **`EmployeePersonalInfo` → edit → save** → Activity or Revisions shows change.

## References

- PRD **NFR8** — `_bmad-output/planning-artifacts/prd-ExpertflowInternalERP-2026-03-16.md`
- Directus docs: Activity & Revisions (version 11 Data Studio)

## Dev agent sections

### Completion Notes List

- _(Add date + verifier when AC met.)_

### File List

- `projects/internal-erp/directus/README.md` — **Story 1.6** (Epic 1 **1.1–1.10** numeric order)
- _(No code change required for default-on audit; config diffs only if env overrides exist.)_
