# Canonical database ↔ PRD ↔ stories — traceability & rapid de‑legacy plan

**Purpose:** Stop operators from using **fields and patterns the PRD will not support**, while keeping **PostgreSQL shape**, **Directus `schema.json`**, **PRD**, and **epics/stories** explicitly linked.  
**Assumption (PM):** **Security / RBAC / RLS** are largely in place; this doc focuses **schema canonicalization** and **documentation coherence**.  
**Normative product rules:** **`prd-ExpertflowInternalERP-2026-03-16.md`**.  
**Schema detail:** **`architecture-BMADMonorepoEFInternalTools-2026-03-15.md`** §4; **`data-admin-surface-requirements.md`** (**NFR14**).

---

## 1. How to use this document

| Audience | Action |
|----------|--------|
| **Engineering** | For each **non-canonical** row below: apply **L1** immediately in Directus; schedule **L3/L4** migrations with Finance sign-off. |
| **PM / SM** | When PRD changes, update **§3** and **§4** in the same PR; open or adjust stories so nothing is “PRD-true / DB-false.” |
| **QA** | Acceptance = **no write path** through Directus to deprecated fields for non-admin roles; evidence = `schema.json` diff + API tests. |

---

## 2. Rapid migration — two speeds

### Speed A — **Immediate (days)** — no blocking DDL

- In **Directus**: **omit** non-canonical fields from layouts; set **read-only** where omit is impossible; add **field note** “Deprecated — use `Journal` / …” per PRD.
- **Hooks / validation**: reject **creates/updates** that populate deprecated columns (where hooks can see payload).
- **Export `schema.json`** and commit — this is the **operator contract** (**NFR10**).

*Honors **NFR7** (no ad-hoc AI SQL): changes go through Directus Admin / approved migrations, not random DDL in chat.*

### Speed B — **Planned (sprints)** — PostgreSQL migrations

- **`ALTER`…`DROP COLUMN`** / FK fixes only after **data backfill** (e.g. move `image` blobs to **`Journal`**).
- Track in same epic as **Story 3.3** (Journal), **A12** umbrella, or a dedicated **“schema canonicalization”** story.

**Rule:** **Speed A** must be true **before** production Finance/HR scale-up so users **cannot** build process on dead fields.

---

## 3. Non-canonical inventory (from PRD — working list)

| # | Table / area | Non-canonical / legacy | PRD / note | Speed A (Directus) | Speed B (DB) |
|---|----------------|------------------------|------------|--------------------|-------------|
| 1 | **`Transaction`** | Per-row **`image`**, **`expense_id`**, **`BankStatementId`** | **FR11** — evidence = **`Journal`**; bank link = **`BankStatement` → `Transaction`** | Omit / RO; hook block writes | Drop after Journal backfill |
| 2 | **`Invoice`** | **`employee_id`**, direct **`Invoice` → `Transaction`**, per-row **`image`/file**, persisted **`NextIssueDate`** | **FR15**, **FR238–242**, **FR44** | Omit / RO | Drop FK/columns after migration |
| 3 | **`Invoice.RecurMonths`** | String enums vs **integer months** | **FR15**, **FR44**, **FR47** | Correct interface + validation | Align column type if wrong |
| 4 | **`Employee`** | **`ProfitCenter`** (legacy text) | **FR22**, **A2** | **Hidden** (already PRD) | Optional drop later |
| 5 | **`Employee`** | Missing **`DefaultProjectId`** | **FR22** — required for **TimeEntry** / **FR28** | Enforce in Flow/hook | Add FK if missing (**Architecture**) |
| 6 | **`Expense`** | Whole table for **employee spend** | **FR28**, **A6** | Hide / RO legacy | Migrate flows off; deprecate table |
| 7 | **`CurrencyExchange`** | Parallel **`Key`**, **`Month`**, **`Year`**, **`Day`** keys | **FR19** | Hide redundant fields | Drop when unused |
| 8 | **`InternalCost`** | **`TimeEntryId`**, **`FromPC`/`ToPC`** | **FR30** | Omit / RO | Drop when safe |
| 9 | **`TimeEntry`** | Required persisted **`HoursWorked`** | **FR25** — derived | Don’t require; RO legacy column | Drop optional |
|10 | **`BankStatement`** | **`Transaction` NOT NULL** at import | **FR6** | Must allow null in UI/API | Nullable FK (**A1**) |
|11 | **`JournalLink.collection`** | **`Expense`** for new evidence | **FR29**, **FR41** | Dropdown without `Expense` for new rows | N/A |
|12 | **Various** | CPQ/CRM/ticket tables | **PRD §2.2** | Hidden / no permissions | N/A |

*DB column names may differ — reconcile against **`schema_dump_final.json`** / live DB and extend this table in-repo.*

---

## 4. Coherence matrix — PRD ↔ architecture ↔ stories

**Legend:** ✅ = explicit story coverage; ⚠️ = partial / deferred; **GAP** = add or refine story.

| PRD anchor | Capability | Architecture | Primary stories (epics file) | Coherence note |
|------------|------------|--------------|------------------------------|----------------|
| **FR6–FR10**, **NFR4** | Bank import, nullable `BankStatement.Transaction`, dedup, 0–2 bank lines / `Transaction` | ADR-05, §3 | Epic **3** (bank/ledger) | Align hooks with **FR10** cap |
| **FR11–FR14**, **FR41** | `Transaction` canonical fields; **`Journal`** evidence; inheritance | ADR-06, §8 | **3.3** Journal; **1.2** financial core | **GAP:** backfill script **Transaction.image → Journal** if data exists |
| **FR15**, **FR44** | `Invoice` shape, RecurMonths, no `employee_id` | §4 mapping | **3.4** Invoice; **FR44** job story | **GAP:** recurring job + integer **RecurMonths** verification |
| **FR28–FR29** | No `Expense`; `Transaction`/`Invoice` + `Journal` | §10.1–10.2 | **5.4** | Flow + dedup **FR28.1** |
| **FR30**, **FR43** | `InternalCost` no `TimeEntryId` | §4 | Epic **4**/5 split | Monthly job story; hide **TimeEntryId** |
| **FR33**, **FR40**, **FR40.1**, **FR41** | HR read paths; **`BankStatement` Finance-only**; Journal scopes | §5.3, §8, **ADR-16** | **Epic 2**, **3-1** | **Re-verify** RLS/SQL: HR/line **no** `BankStatement` **SELECT**; **`Journal`** parent inheritance (**FR12**) |
| **FR46.6**, **FR46.2** | Per-`Account` registry import | ADR-16, §4.2 | **3-1** | Parser choice **must** follow selected `Account` |
| **FR47**, **FR47.9** | Cash dashboard | §10.5–10.7 | **6.3** + artifact `6-3-*.md` | Spike + tool decision log |
| **FR22**, **FR24.1** | `DefaultProjectId`, **`Seniority.DayRate`** | §10.3–10.4 | **1.3** Employee; Epic **4** | Migration if columns missing |
| **NFR14** | Human-readable references | ADR-14, **data-admin-surface** | **1.5** M2O templates; scripts | **schema.json** review checklist |
| **NFR13**, **A11** | RLS + extension context | ADR-13 | **1-10**, **1-8**, **1-9** | User: largely done — keep regression tests |
| **A12** | Legacy columns cleanup, **FR44** scheduler | A12 row | **GAP:** single “**A12 schema hardening**” epic slice | Consolidates scattered migration work |

---

## 5. Keeping coherence over time

1. **Single PRD version** in filenames (`prd-ExpertflowInternalERP-2026-03-16.md`) — date bumps on major revision.  
2. **Any PRD FR change** that touches schema → update **§3–4** here + **Architecture §4** + **`schema.json` PR**.  
3. **Epic FR table** (`epics-…md`) should reference the same FR numbers; if a story closes, mark row **✅** in a living copy of **§4** (or link to sprint board).  
4. **Quarterly** (or each release): run a **diff** — PRD “SHALL NOT” list vs Directus field visibility export.

---

## 6. Related documents

| Document | Role |
|----------|------|
| `migration-plan-postgres-directus-cloud-wave1.md` | Cloud waves + pilot sequencing |
| `prd-ExpertflowInternalERP-2026-03-16.md` | Normative requirements |
| `architecture-BMADMonorepoEFInternalTools-2026-03-15.md` | FKs, RLS, Directus binding |
| `epics-ExpertflowInternalERP-2026-03-16.md` | Story IDs |
| `employee-time-expense-requirements-and-plan.md` | FR28 operational detail |

---

## 7. Suggested immediate backlog items (coherence-focused)

1. **`schema.json` audit PR** — cross-walk **§3** (hide/RO all Speed-A items for Finance/HR roles).  
2. **Story: “A12 — canonical column migration plan”** — one owner; subtasks per table in **§3**.  
3. **Traceability tick** — for each **GAP** in **§4**, create or rename a story so **no orphan PRD rule**.  
4. **Optional:** add **`canonical-schema-prd-story-traceability.md`** to CI or pre-release checklist as “documentation gate.”

---

*This file is **planning glue**; it does not override the PRD. When they conflict, **fix this file**.*


