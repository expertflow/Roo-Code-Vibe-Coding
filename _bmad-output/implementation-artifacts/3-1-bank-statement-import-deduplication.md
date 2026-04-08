# Story 3.1: Bank statement import with deduplication

**Story ID:** 3.1  
**Story key:** `3-1-bank-statement-import-deduplication`  
**Status:** ready-for-dev

**Epic:** 3 — Financial ledger & bank (`epics-ExpertflowInternalERP-2026-03-16.md`).  
**Sprint plan:** `_bmad-output/implementation-artifacts/epic-3-sprint-plan.md` (first in Epic 3 sequence).  
**Depends on:** Collections **`BankStatement`**, **`Account`**, **`Transaction`** registered (Stories **1-2** / **1-5**). **Epic 2** is PM-recommended before Finance Manager AC; verify as **Administrator** until roles exist.

**Scope note (2026-03-24):** This story now bundles **(A)** Finance-only visibility for **`BankStatement`**, **(B)** per-account file import UX + Python parsers (~12 accounts), **(C)** generic **create-time** deduplication hook. Sub-stories below split delivery; **(C)** can ship after **(B)** produces rows via normal **`items.create`** (hook runs automatically).

---

## Story

As a **Finance user** (role aligned with **`finance-manager`** / **`UserToRole`** Finance mapping per Architecture §8),  
I want to **upload** a bank file **for a chosen `Account`**, have an **account-specific** import turn it into **`BankStatement`** rows, and have the system **reject duplicates** on create,  
So that only Finance can see bank lines, imports match each bank’s format, and unreconciled rows are ready for **Story 3-2** reconciliation (**FR6** / **FR9**).

---

## Sub-stories (delivery slices)

### 3-1a — RLS / visibility: Finance-only **`BankStatement`** read

**Requirement:** Only users whose **`UserToRole`** (and matching PostgreSQL session context via **1-10**) classify them as **Finance** may **`SELECT`** (view/list/detail) **`BankStatement`** rows. Non-Finance roles must receive **no rows** / **403** on `GET /items/BankStatement` and must not see the collection in Admin if product policy is “Finance-only.”

**Conflict flag:** Current Architecture (`architecture-BMADMonorepoEFInternalTools-2026-03-15.md`) grants **`hr-manager`** read on **`BankStatement`** where **`Account` → LegalEntity.Type = Employee**, and **line-manager** paths for payroll-linked ledger rows. **Tightening to Finance-only** is a **policy change** — see **BMAD routing** at end of this file before merging SQL.

**Tasks (indicative):** Revise PostgreSQL RLS policies on **`BankStatement`**; align Directus collection **read** permissions for **Epic 2** roles; verify with **`sterile_dev`** + RLS extension + test users.

---

### 3-1b — Import UX: file + **`Account`** + **Import**

**Requirement:** In Directus (custom **module**, **Flow** + operation, or **endpoint** + minimal UI), the user:

1. Selects a **file** (typically **`.csv`** / spreadsheet export).
2. Selects which **`Account`** the statement belongs to (~**dozen** house banks / accounts — maintain a **registry**: account id → importer id).
3. Clicks **Import**.

**Then:** The app invokes the **account-specific** import path for that **`Account`** (see **3-1c**), which creates **`BankStatement`** items via the **Data API** (or service path that still triggers **`items.create`** hooks). **Deduplication (3-1d)** applies to each create.

**Tasks (indicative):** Registry config (YAML/JSON or DB table); authenticated route callable only by Finance; progress/error feedback; optional async job for large files.

---

### 3-1c — Per-account import implementations (Python, ~12 accounts)

**Requirement:** For each supported **`Account`**, a **Python** script (or package module) parses that bank’s **CSV/layout** into a **normalized** row shape matching **`BankStatement`** fields (`Account`, `BankTransactionID`, `Date`, `Amount`, `Description`, …). Parsers live under repo e.g. `projects/internal-erp/directus/scripts/bank-import/` or `projects/internal-erp/bank-import/` (dev agent picks consistent layout).

**Invocation:** **3-1b** passes **file path + account id** → dispatcher runs `python -m ...` or calls imported function → outputs rows → **POST** to Directus **as Finance user** (user token) or **static import role** if explicitly approved (prefer user token + RLS).

**Tasks (indicative):** One module per bank format + shared column normalizer; unit tests with fixture CSVs; document adding a new account (copy template, register in registry).

---

### 3-1d — Generic deduplication hook (original epic core)

**Requirement:** **`action: items.create`** on **`BankStatement`** only; **atomic-line** dedup per **FR7**/**FR8** (2026-03-26): key includes **`Account` + `Date` + `Amount` + normalized merged `Description` + `BankTransactionID`** (when present). **`Account` + `BankTransactionID` alone is NOT unique** — same bank reference may appear on multiple rows. No dedup on **`items.update`**. **No** DB **`UNIQUE (Account, BankTransactionID)`** if it would block legitimate multi-line bank references.

---

## Additional acceptance criteria (sub-stories)

**3-1a — Finance-only visibility**

7. **Given** a user **not** mapped to Finance in **`UserToRole`**, **When** they call `GET /items/BankStatement` (or open the collection in Admin), **Then** they receive **empty result / 403** and **no** bank statement PII.

8. **Given** a Finance-mapped user, **When** they list **`BankStatement`**, **Then** they see rows subject to any remaining Finance-wide rules (no extra LegalEntity slice unless product adds one later).

**3-1b / 3-1c — Import pipeline**

9. **Given** a Finance user selects a valid **`.csv`** and a registered **`Account`**, **When** they click **Import**, **Then** the correct Python (or registered) importer runs and **`BankStatement`** rows appear with **`Account`** set to the selection.

10. **Given** an **`Account`** with **no** registered importer, **When** the user attempts import, **Then** the UI shows a clear error (do not silently no-op).

---

## Acceptance criteria (from epics — normative, dedup / 3-1d)

1. **Given** a new **`BankStatement`** with **`Account`**, **`BankTransactionID`**, **`Amount`**, **`Date`**, **`Description`**, and **`Transaction` null**, **When** submitted, **Then** the row persists with **`Transaction = NULL`** and appears in the collection list (**FR6**).

2. **Given** a new **`BankStatement`** with the same fields **and** a valid **`Transaction`** FK, **When** submitted, **Then** the row persists successfully.

3. **Given** a **`BankStatement`** row already exists for **`Account = A`** with **`BankTransactionID = "TXN-ABC-001"`**, **`Date`**, **`Amount`**, and merged **`Description`**, **When** a **second** create is submitted with the **same** **`Account`**, **`BankTransactionID`**, **`Date`**, **`Amount`**, and **normalized** **`Description`**, **Then** API returns **4xx** with a clear duplicate message and **no** second row is stored (**atomic-line** match per **FR8**).

4. **Given** two creates with the **same** **`Account`** and **`BankTransactionID`** but **different** **`Amount`** or **`Description`**, **When** both are submitted, **Then** **both** are accepted (bank batch reference is **non-unique**; lines are distinguished by **Amount** + narrative + **Date** in the dedup key).

5. **Given** **`BankTransactionID`** is empty/null, **When** the row is submitted, **Then** dedup uses the same **FR8** key without the ID token (**`Account` + `Date` + `Amount` + normalized `Description`**). A second row matching that key **Then** rejects as duplicate.

6. **Given** two rows with the same **`BankTransactionID`** but **different** **`Account`**, **When** both are submitted, **Then** **both** are accepted (dedup scope is per **`Account`** plus full atomic key).

7. **Hook scope:** Deduplication runs on **`action: items.create`** for **`BankStatement`** **only** — **not** on **`items.update`** (reconciliation in **3-2** must not trip dedup).

**UBS (`Account` 7 / 8 / 9) — product rules (2026-03-26):** Parser drops **summary** row(s) for multi-line **same `Transaction no.`**; imports **only atomic** rows with **`Individual amount`** → maps to **`Amount`**; **`Footnotes`** source column **not** imported; **`Trade time`**, **`Booking date`**, **`Value date`**, **`Balance`** not stored. Staging verification: parser **MAY** emit **JSON/CSV** of normalized rows before **`POST`** (no extra DB schema required).

---

## Technical requirements (dev guardrails)

| Topic | Requirement |
|--------|-------------|
| **Location** | New extension folder: `projects/internal-erp/directus/extensions/bank-statement-dedup/` (or `hooks/bank-statement-dedup` if team standardizes under `extensions/hooks/` — **match existing mount**: compose maps `./extensions` → `/directus/extensions`; subfolders are fine). |
| **Extension type** | Directus **hook** extension, **`type: "module"`** + **`directus:extension.type: "hook"`**, **`host: "^11.0.0"`** — mirror `extensions/rls-user-context/package.json` pattern. |
| **Registration** | Export default function registering `filter` or `action` per Directus 11 hook API — use **`action('items.create', …)`** scoped to **`BankStatement`** (or equivalent collection key). |
| **Errors** | Use **`@directus/errors`** **`InvalidPayloadError`** (or current project standard) so clients get **400** + structured message. |
| **Logic** | Before insert: build **atomic-line** key per **FR8** — **`Account`** + **`Date`** + **`Amount`** + normalized **`Description`** + **`BankTransactionID`** (include ID in hash input when non-empty). Query for an existing row with the **same** key (same **`Account`**); if found → reject duplicate. **Do not** reject solely on **`Account` + `BankTransactionID`**. Document normalization (trim, newline handling in merged description, decimal format for **`Amount`**, date as ISO date string). |
| **RLS (3-1a)** | Implement **Finance-only** **`SELECT`** on **`BankStatement`** per sub-story **3-1a**; update **`INSERT`/`UPDATE`/`DELETE`** policies so only Finance (and break-glass DB roles) can mutate bank lines unless PM dictates otherwise. **Replaces** Architecture’s HR/line-manager **`BankStatement`** read paths once approved — track SQL in `docs/sql/` with migration id. |
| **Import stack (3-1b/c)** | Python **3.x** in repo; pin minor version in README; run from Directus **custom endpoint** (Node `child_process` / queue) or sidecar — document security (no shell injection, temp file cleanup, max upload size). Prefer **Finance user token** for `POST /items/BankStatement` so RLS applies. |
| **Tests** | Extension unit / integration tests for **dedup**; **pytest** (or similar) for each CSV fixture under **`bank-import/tests/`**; manual matrix for **3-1a** role × visibility. |

---

## Architecture compliance

- **ADR-05** (Architecture): two-step **`BankStatement`** workflow; dedup on create; **0–2 cap** is **Story 3-2** (`bank-statement-limit`) — **do not** implement cap in this story.
- **BankStatement ↔ Transaction** nullable at import — **do not** add NOT NULL at DB layer for **`BankStatement.Transaction`** in this story.
- Reference: `_bmad-output/planning-artifacts/architecture-BMADMonorepoEFInternalTools-2026-03-15.md` — BankStatement hooks section.

---

## Implementation tasks (checklist)

**3-1a**

- [ ] Draft SQL: drop/replace **`BankStatement`** policies that grant **`hr-manager`** / line-manager **`SELECT`**; add Finance-only **`SELECT`** aligned with **`UserToRole`** + **`auth` helpers** (see `fix-rls-policies-v2.sql` patterns).
- [ ] Epic 2 / Directus: hide **`BankStatement`** from non-Finance admin roles when permissions exist.

**3-1b / 3-1c**

- [x] Registry: `accountId` → `importerKey` (file).
- [x] UI surface + endpoint to run importer and stream/create rows. _(API: `POST /bank-statement-import/run`; Finance UI still pending.)_
- [ ] Python parsers for each house bank (~12); shared normalizer; tests per format. _(UBS for accounts 7/8/9 done.)_

**3-1d**

- [x] Scaffold **`package.json`** + **`index.js`** for **dedup** hook (mirror **rls-user-context**).
- [x] **`items.create`** on **`BankStatement`** only; composite + hash paths; **no** hook on **`items.update`**.
- [x] **`docker compose`** / README: extensions volume + rebuild. _(compose: `bank-import` volume; Dockerfile: `python3` + COPY.)_
- [ ] Manual matrix: duplicate TXN, cross-account, hash collision, post-import dedup, reconciliation update (no dedup fire).
- [ ] **`schema.json`** snapshot if collection metadata changes.

---

## Brownfield note

Architecture text references **`extensions/hooks/bank-statement-dedup/`** — **repo currently has only `rls-user-context` under `extensions/`**. Treat **3-1** as **implement (or replace) dedup hook**; align final path with **README** and compose after implementation.

---

## References

- `_bmad-output/planning-artifacts/epics-ExpertflowInternalERP-2026-03-16.md` — Story 3.1
- `_bmad-output/implementation-artifacts/epic-3-sprint-plan.md`
- `_bmad-output/planning-artifacts/architecture-BMADMonorepoEFInternalTools-2026-03-15.md` — ADR-05, **ADR-16**, BankStatement hooks / import
- `_bmad-output/planning-artifacts/sprint-change-proposal-2026-03-24.md` — Correct Course (Story 3-1 expansion)
- `projects/internal-erp/directus/extensions/rls-user-context/` — extension packaging reference
- `projects/internal-erp/directus/docker-compose.yml` — extensions volume
- `projects/internal-erp/directus/schema.json` — **`BankStatement`** / **`BankTransactionID`**

---

## BMAD: do we need **Architect** or **PM** for this amendment?

| Change | Who | Why |
|--------|-----|-----|
| **Finance-only `BankStatement` visibility** | **Architect** ✅ + **PM** ✅ | **Done in repo:** **ADR-16** + architecture §5.2/§8.2/§4.2; **PRD** **`prd-ExpertflowInternalERP-2026-03-16.md`** — **FR40.1**, **FR33**/**FR40**/**§4** alignment; **`sprint-change-proposal-2026-03-24.md`**. Org PO may still **sign off** on HR losing bank-line read. |
| **Per-account Python import + UI** | **PM** ✅ + **SM** | **PRD** **FR46.2** / **FR46.6** + **FR6** — mandatory **`Account`** selection, registry-bound parser, same authenticated **`POST`** path. **SM** may split **`sprint-status.yaml`** keys later; **3-1a–d** labels suffice for dev. |
| **Pure implementation** (after decisions) | **Dev** (`bmad-dev-story`) | No further Architect/PM loop if policies are signed off. |

**Minimum path:** PO confirms “Finance-only bank statements overrides HR/manager read,” then **`bmad-architect`** (or manual architecture doc edit) + SQL review, then dev.

---

## Dev Agent Record

### Agent Model Used

Composer (Cursor agent).

### Completion Notes List

- UBS semicolon CSV parser with header detection, `Transaction no.` grouping, multi-line summary drop (keep `Individual amount` rows), fixture-driven unittest (stdlib only).
- CSV reader uses unique synthetic headers for trailing `;` columns so Python `csv` does not collapse duplicate empty keys.
- **`bank-statement-dedup`** hook: atomic-line duplicate check on `items.create` for `BankStatement` (FR8); env `BANK_STATEMENT_DEDUP_ENABLED=false` to disable.
- **`bank-statement-import`** endpoint: `POST /bank-statement-import/run` body `{ account, csv, dryRun? }` → `python3` + `cli.py` → JSON rows or `ItemsService.createOne` per row.
- Docker image installs `python3` and copies `bank-import`; compose mounts `./bank-import` for live edits.

### File List

- `projects/internal-erp/directus/bank-import/` — `registry.json`, `dispatch.py`, `cli.py`, `parsers/ubs_ebanking_csv.py`, `tests/*`, `README.md`
- `projects/internal-erp/directus/extensions/bank-statement-dedup/` — `package.json`, `index.js`
- `projects/internal-erp/directus/extensions/bank-statement-import/` — `package.json`, `index.js`
- `projects/internal-erp/directus/extensions/bank-statement-import-ui/` — Data Studio module (`src/`, built `dist/`); enable **Bank import** in project module settings
- `projects/internal-erp/directus/Dockerfile` — Python 3 + COPY `bank-import`
- `projects/internal-erp/directus/docker-compose.yml` — volume `./bank-import:/directus/bank-import`
