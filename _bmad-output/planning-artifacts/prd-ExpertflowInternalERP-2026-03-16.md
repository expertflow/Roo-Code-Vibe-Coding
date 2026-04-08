---
stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
inputDocuments:
  - projects/internal-erp/vision.md
  - docs/governance.md
  - schema_dump_final.json
  - _bmad-output/planning-artifacts/architecture-BMADMonorepoEFInternalTools-2026-03-15.md
  - _bmad-output/planning-artifacts/identity-provider.md
  - _bmad-output/planning-artifacts/data-admin-surface-requirements.md
workflowType: 'prd'
project_name: 'ExpertflowInternalERP'
user_name: 'Andreas'
date: '2026-03-16'
---

# Product Requirements Document — Expertflow Internal ERP (Phase 1)

> **Note:** Please verify against `antigravity-implementation-history.md` for alternative implemented methodologies (e.g., *Fix Row Level Security*, *Strict CRUD Enforcement*), as previous Antigravity session plans may supersede or contradict these requirements.

**Author:** Andreas
**Date:** 2026-03-16
**Status:** Approved for Implementation
**Scope:** Phase 1 — Directus Backend Configuration + HR/ERP Core Modules

---

## 1. Executive Summary

This document defines the requirements for Phase 1 of the Expertflow Internal ERP. The project replaces the legacy internal back-office stack with a **Directus v11 (self-hosted, Dockerized)** backend layer configured against the existing `bidstruct4` PostgreSQL schema.

**Phase 1 UX / delivery strategy (PM — 2026-03-17):** For **implementation speed** and **minimal moving parts**, Phase 1 **does not** introduce a separate employee SPA (previously described as **Lovable**). **All personas**, including **Employee**, use **Directus** as the product surface: **Directus Admin UI** for collection-based workflows and, where needed, **in-repo Directus extensions** (modules, interfaces, hooks) — still **only** the Directus REST API to the database. A **dedicated employee SPA** (Lovable, Vite/React in monorepo, or similar) remains a **deferred option** if mobile/UX gaps justify the extra platform later; the API contract does not change.

**PM course correction (2026-03-24 — bank statements):** **`BankStatement`** is **Finance-only** for read/write (**FR40.1**, Architecture **ADR-16**); HR and line managers use **`Invoice`** / **`Transaction`** / **`Journal`** for payroll narrative, not raw bank lines. **Import** requires an operator-selected house-bank **`Account`**; a **versioned registry** selects **one** import implementation per `Account` (**FR46.2**, **FR46.6**).

**PM clarification (2026-03-26 — dedup):** **`BankTransactionID`** may repeat per **`Account`**; **FR7**/**FR8** deduplicate **atomic import lines** using **`Account` + `Date` + `Amount` + narrative + `BankTransactionID`** in the hash, not **`Account` + `BankTransactionID`** alone (**NFR4** updated).

Phase 1 strictly covers **Accounting/ERP** and **HR** modules. CPQ, CRM, and support ticket functionality are explicitly out of scope.

**Identity — final product (org standard):** In **production**, **every human login** to the product (**Directus Admin** and any future SPA) **MUST** use an **external OIDC/OAuth identity provider** per **`identity-provider.md`** (canonical spec — **Story 1.8** implements). **Trusted-domain JIT:** users with IdP-verified email on allowlisted domains (e.g. **`@expertflow.com`** via Google Workspace) **MUST** be able to sign in **without** manual Directus user creation — full rules in **`identity-provider.md`** and **NFR12**. **Which** IdP (vendor, endpoints, domains) is defined **only** in that file; changing IdP requires editing that file + Story 1.8 — **not** this PRD. Local development and short-lived bootstrap may use Directus local admin/email-password where operationally necessary; production **MUST NOT** rely on shared passwords for end users. See **NFR12** and Architecture **ADR-12**.

### 1.1 Strategic Objectives

- **Zero Licensing Cost**: Replace per-user SaaS tools with self-hosted open-source alternatives (Directus OSS).
- **Data Sovereignty**: Full ownership of schema and source code; no vendor lock-in.
- **Security Migration**: Move all RBAC/RLS logic from raw PostgreSQL policies to the Directus API layer, enabling safe AI-assisted development ("vibecoding").
- **Operational Velocity**: Eliminate manual spreadsheet-based reporting; achieve instant Directus Insights for Monthly Close.
- **Corporate IAM**: Align end-user authentication with the **external IdP** defined in **`identity-provider.md`** (NFR12, Story 1.8).

---

## 2. Scope & Boundaries

### 2.1 In Scope (Phase 1)


| Domain                  | Tables / Collections                                                                            |
| ----------------------- | ----------------------------------------------------------------------------------------------- |
| **Financial Core**      | `Account`, `BankStatement`, `Transaction`, `Invoice`, `Allocation`, `Accruals`, `Journal`, `InternalCost` |
| **Currency**            | `Currency`, `CurrencyExchange`                                                                  |
Perform the same self-service outcomes as FR25–FR29 **via Directus** (Admin and/or extensions): time on `TimeEntry`, leave on `Leaves`, **employee spend** via **FR28** (creates **`Transaction`/`Invoice` + `Journal`**), within RBAC. Dedicated SPA flows (original FR35–FR39) are **deferred**; see §5.13.

**Executive (Profit Center Manager) — Unit performance**
Same **RLS and Directus read rules** as **any other employee** (**FR21**, **FR40**) — **no** special database or API visibility for holding the **`executive`** role. Use **Directus Insights** for **aggregated** P&L views **only** where those panels query data the user is already permitted to see under the same rules (**FR20**); Insights **must not** bypass RLS. **Mutations** remain with **Finance** (ledger) and **HR** (workforce / time / expenses) unless delegation is added later.

**Line Manager — Team operations**
Read/update direct reports’ `TimeEntry`, `Leaves`, and `Task`; no financial collection access (§4 Target Users matrix).

---

## 4. Target Users & Access Control Model

### 4.1 Administrative Roles (Directus Admin UI)


| Role                                  | Scope                                                                      | Restrictions                                                                                                                                                                                                                   |
| ------------------------------------- | -------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Finance Manager (Global)**          | Full CRUD on all financial collections across all LegalEntities            | None                                                                                                                                                                                                                           |
| **Executive (Profit Center Manager)** | **Same read visibility as Employee** for sensitive data (**FR21**, **FR40**) — **no** extra RLS tier; optional **Insights** (FR20) for convenience only | **No write** on Finance ledger collections (`Account`, `BankStatement`, `Transaction`, `Invoice`, `Allocation`, `Accruals`, `Journal`, **`InternalCost`**, etc.) or **HR operations** collections (`Employee`, `EmployeePersonalInfo`, `TimeEntry`, `Leaves`, `Task`) unless a later story extends delegation (**FR21**). |
| **HR Manager**                        | Full CRUD on employee lifecycle, payroll, leave management                    | **Payroll / colloquial “salary”** = recurring **`Invoice`** on Employee/Executive **`LegalEntity`** — see **§4.4**. **Read** access to **amount-bearing financial** collections **`Account`**, **`Transaction`**, and **`Invoice`** **only** for rows where **at least one** account leg is **`LegalEntity.Type = 'Employee'`** and **no** leg is **`Executive`** (see FR33, FR40). **`BankStatement`**: **no** read and **no** write — **FR40.1**. **No** create/update/delete on those ledger collections unless explicitly extended later. **Read** access to **`CurrencyExchange`** permitted (non-sensitive FX reference; FR19). **Read** access to **`Journal`** **only** for **`JournalLink.collection` ∈ {`Transaction`, `Invoice`, `Employee`}** with **item filters** consistent with **FR33** (employee-ledger evidence — **FR41**). **Blocked** from: `Allocation`, `Accruals`, **`InternalCost`**, and any financial row where **either** leg is **`Executive`**. **No** item-level hiding of `Employee` master rows; visibility rules use **`Account → LegalEntity.Type`**, not `Employee.DefaultProjectId` / `Employee.ProfitCenter`. |
| **Line Manager**                      | Read own team `TimeEntry`, `Leaves`, `Task`; Approve leaves/time           | **Plus (FR33/FR40):** may **read subordinates’ payroll-related recurring `Invoice` rows** and **related ledger rows tied to those invoices** (**`Transaction`** per **FR40**; **not** **`BankStatement`** — **FR40.1**) for **all subordinates** (direct and indirect via **`Employee` → `Manager`** — **FR22**). **Payroll** is **not** a separate domain object — it is **recurring `Invoice`** lines on accounts whose **`LegalEntity.Type`** is **`Employee`** or **`Executive`** (BS4). Line managers do **not** get **Executive**-ledger reads unless they are also HR/Finance. No other amount-bearing ledger access beyond that rule unless extended.                                                                                                                                                                                    |


### 4.2 End-User Roles (Employee — Phase 1: Directus)


| Role         | Interface (Phase 1) | Capabilities                                                                        |
| ------------ | ------------------- | ----------------------------------------------------------------------------------- |
| **Employee** | **Directus Admin** (constrained) and/or **Directus extensions** | Log time entries, submit/view leaves, **employee spend** via **FR28** (**`Transaction`/`Invoice` + `Journal`**; incl. receipt capture), view own data per RBAC (FR25–FR29). **Deferred:** dedicated SPA if UX requires it later. |


### 4.3 Privacy-by-Role Mandate

All role restrictions must be enforced at the **Directus API layer**. Frontend access control is supplementary only and cannot be the sole security gate (per `docs/governance.md` Zero-Trust mandate).

### 4.4 Terminology — “Salary” / payroll (**for HR and operators**)

In conversation and HR policy, people often say **“salary”** or **“payroll.”** In this product those ideas are **not** stored as a separate **`salary`** table or field on **`Employee`**.

**What to use in the system:** recurring **`Invoice`** rows (see **FR15**, **FR44**, BS4) whose **`OriginAccount`** / **`DestinationAccount`** resolve to a **`LegalEntity`** with **`Type = 'Employee'`** or **`Type = 'Executive'`**. Employment contracts in BS4 are modeled as a **`Project`** with such **monthly (or other) recurring invoices**.

**Why payroll is protected (RLS in every manifestation):** What staff treat as **salary** is **financial data** end-to-end. Each form it takes is a **ledger-backed** record covered by **PostgreSQL RLS** and **Directus RBAC** (**NFR1**, **NFR13**, **FR33**, **FR40**, **FR41**) — not a single “salary blob”:

| Manifestation | Role in the payroll story |
| --- | --- |
| **`Invoice`** (typically **recurring**) | The **employment contract** in data shape — amounts and terms owed between accounts on an Employee/Executive **`LegalEntity`**. |
| **`Transaction`** | The **moment of disbursement** — movement between accounts when pay is executed. |
| **`BankStatement`** | **Proof of transfer** — bank-side evidence aligned with reconciliation (**FR6**–**FR10**). **Phase 1 visibility:** **Finance-only** — HR and line managers do **not** read raw bank lines (**FR40.1**); payroll assurance for HR uses **`Invoice`** / **`Transaction`** / **`Journal`**. |
| **`Accruals`** | When **payment or recognition is delayed** — fiscal / project accrual before cash settles. **Finance Manager only** — **no** read and **no** write for **`hr-manager`**, **`line-manager`**, **`employee`**, or **`executive`** (**FR17**, **FR41**); still **RLS-protected** for everyone. |

**Who sees what:** **HR** reads **Employee-ledger** **`Invoice`** / **`Transaction`** (and permitted **`Journal`**) per **FR33**/**FR40**; **`BankStatement`** is **excluded** — **FR40.1**. **Executive-ledger** legs are **hidden** from HR. **HR never** reads **`Accruals`**. **Line managers** see **subordinate payroll `Invoice`** paths and linked **`Transaction`** rows per **FR40** — **not** **`BankStatement`**, **not** **`Accruals`**. **`Allocation`** and **`InternalCost`** remain **Finance**-scoped per **FR41** (no HR read in Phase 1 unless a separate PRD change).

**Why this note exists:** so **HR** (and Finance) can map everyday language to **`Invoice`** and the **surrounding ledger**, and understand **why** there is no separate “salary” collection — **protection is in the financial objects themselves**. **Directus** SHOULD surface this explanation in **onboarding copy, collection `note` text, or an internal wiki link** tied to **`Invoice`** / HR training materials (**NFR14** operator clarity).

---

## 5. Functional Requirements

### 5.1 Platform Infrastructure

**FR1**: The system SHALL run as a Dockerized Directus v11.x instance connecting to the existing `bidstruct4` PostgreSQL database (`localhost:5432`) via Cloud SQL Auth Proxy.

**FR2**: The system SHALL register all 42 tables from `schema_dump_final.json` as Directus collections, configuring field metadata (labels, interfaces, display templates) appropriately. **Phase 1 delivery** focuses on full configuration of the 29 in-scope collections (per Section 2.1); the remaining 13 out-of-scope tables SHALL still be registered (hidden/inactive or permission-blocked) so the schema snapshot matches `bidstruct4` and accidental raw-table access is prevented — aligned with the Architecture document’s phasing strategy. **Reference fields in the internal data administration UI** SHALL satisfy **`data-admin-surface-requirements.md`** (**NFR14**).

**FR3**: The system SHALL configure all foreign-key relationships present in the schema as Directus relational fields (M2O, O2M, M2M as applicable), making them navigable in the Admin UI.

**FR4**: The system SHALL expose a Directus REST API as the single communication layer between **all** user-facing clients (Directus Admin, Directus extensions, and any **future** optional SPA) and the database. Direct database access from those clients is forbidden.

**FR5**: The system SHALL configure Directus Activity and Revisions logging for all Finance-domain collections **and** for `EmployeePersonalInfo` to provide a native audit trail (see **NFR8**).

---

### 5.2 Bank Statement Import & Deduplication

**FR6**: The system SHALL support importing bank transactions into `BankStatement` via the Directus Admin UI (CSV/Excel upload or direct form entry), treating each row as an atomic, indivisible record. **File-based import** SHALL follow **FR46.6**: the operator **selects (or confirms)** the **target house-bank `Account`** before ingest; the system SHALL run the **registered** import implementation for **that** `Account` only (see **FR46.2**). **Multi-column bank narratives** and **recurring multi-bank file** workflows **SHALL** follow **FR46**. At import time, **`BankStatement.Transaction` MAY be `NULL`** (unreconciled bank line). **Reconciliation** (**FR9**/**FR10**/**FR45**) SHALL allow Finance to **map every `BankStatement` to exactly one `Transaction`** before the line is considered **closed** for operational purposes; **Hooks**, **workflows**, or **reporting** MAY flag or block “done” states until mapped. **Deduplication** (**FR7**/**FR8**) applies at import regardless of `Transaction` nullability.

**FR7**: The system SHALL enforce **zero-duplication at the atomic imported-line level** on `BankStatement` **create**: a second row that represents the **same** atomic line as an existing row (per the deduplication key in **FR8**) MUST be rejected with a descriptive validation error before persisting. **`BankTransactionID`** is an **informational** bank-supplied reference and **MAY repeat** across multiple **`BankStatement`** rows for the same **`Account`** when the bank groups several movements under one reference (e.g. one batch ID, many detail lines). **SHALL NOT** rely on **`Account` + `BankTransactionID` alone** as a uniqueness constraint — that pair is **not** unique in the general case. **Architecture** documents hash/normalization (**FR8**) and any bank-specific import notes (e.g. which source rows are dropped).

**FR8**: The system SHALL compute a **deterministic deduplication key** for each **`BankStatement`** **create** from **`Account`** / `AccountID`, **`Date`**, **`Amount`**, **merged narrative text** from all populated description fields used for that import (**FR46.1**), and **`BankTransactionID`** when present. Rows that share the same **`BankTransactionID`** but differ in **`Amount`** or merged narrative **SHALL** produce **distinct** keys and **SHALL** both be allowed. When **`BankTransactionID`** is absent, the key **SHALL** still use **`Account` + `Date` + `Amount` + narrative** (collision resistance for that path). **Architecture** SHALL define exact normalization (whitespace, merge order, encoding) so the **same** source line re-imported yields the **same** key (**per-atomic-line** idempotency). Import implementations **MAY** ignore source columns that are not part of the stored row (e.g. bank **footnotes** columns excluded by policy).

**FR46** (**Multi-bank spreadsheet / CSV import to `BankStatement`**): The system SHALL support recurring import of external bank files into **`BankStatement`** for **multiple** house bank **`Account`**s (typically **`LegalEntity.Type` = `Internal`**), consistent with **FR6**–**FR8** and **NFR7** (no direct ad-hoc SQL against `bidstruct4` from operators). **Traceability:** archived notes in **`_bmad-output/reference/banking-spreadsheet-import-legacy-source.md`** (non-normative).

**FR46.1 — Multiple description columns:** The **`BankStatement`** model **SHALL** expose **up to four** operator-relevant text fields for bank-provided narrative data (e.g. **`Description1`**…**`Description4`**, or equivalent names per schema story) so a single bank line can retain **all** distinct text columns common in bank exports. Legacy single-**`Description`** columns **MAY** map to **`Description1`** for backward compatibility. **Directus** layouts **SHALL** surface these fields where Finance needs them for matching and audit (**NFR14**).

**FR46.2 — Per-`Account` import implementation:** Each integrated house bank **`Account`** **MAY** use a **different** source file layout (CSV/spreadsheet columns) and **SHALL** map to **its own** import implementation in a **versioned registry** (e.g. one Python parser module per `Account`, or one module shared by a documented group — **Architecture** defines storage and discovery). The operator-selected **`Account`** **SHALL** determine **which** implementation runs (**FR46.6**); the system **SHALL NOT** silently substitute another `Account`’s parser. The product **SHALL** support **normalization** from each bank-specific layout to the canonical **`BankStatement`** shape (**FR46.1**, **`Amount`**, **`Date`**, **`Account`**, optional **`BankTransactionID`**, etc.) via **documented** mapping rules maintained in **Architecture** / runbooks / versioned config. Persisted rows **SHALL** carry the selected **`Account`** FK so **RLS**, **dedup** (**FR7**/**FR8**), and **hooks** apply consistently.

**FR46.3 — Deduplication before insert:** Batch or scripted import **SHALL** compare candidate rows against **existing** **`BankStatement`** records and **SHALL** insert **only** rows that do not duplicate an existing line under the same rules as **FR7**/**FR8** (composite key where present; otherwise deterministic hash including **date, amount, account, and bank-specific identifier / description fields** per **FR46.2**).

**FR46.4 — Human review gate (scripted / batch path):** For **developer-operated** or **scripted** ingestion (outside an interactive Directus Admin flow where the operator commits row-by-row with immediate feedback), the workflow **SHALL** support a **two-phase** pattern: **(Phase A)** emit a **review artifact** (e.g. CSV) listing proposed inserts, including **bank / `Account` identity** and **source file export date** (or equivalent metadata) so Finance can validate; **(Phase B)** persist to **`BankStatement`** **only** after **explicit approval** (second job step, signed command, or ticket — **Architecture** defines). **Directus Admin** CSV/Excel upload **MAY** use a single-step commit where the operator’s upload action constitutes approval (**FR6**).

**FR46.5 — Credentials and tooling:** Bank feed credentials, database passwords, and API secrets **SHALL NOT** be stored in version-controlled import scripts, shared notebooks, or import working directories (**NFR2**). **NFR7** remains in force: production data paths go through **Directus API** (or approved automation using service credentials **outside** the repo).

**FR46.6 — Import entry point bound to selected `Account`:** The Finance-facing import flow **SHALL** present **file upload** (or equivalent) **together with** a mandatory **`Account`** selection (or explicit confirmation when a single house bank is in scope). The system **SHALL** resolve **one** registry entry for that **`Account`** and invoke **that** import implementation only. **SHALL NOT** run a generic parser without a registry match — the operator **SHALL** receive a clear error and instructions. Parsed candidate rows **SHALL** be written through the **same** Directus-authenticated path as manual entry (e.g. **`POST` as the Finance user**) so **PostgreSQL RLS** and **`items.create` hooks** (**FR7**/**FR8**) execute identically. **Architecture** documents subprocess safety, registry format, and break-glass exceptions (if any).

---

### 5.3 Transaction Mapping & Ledger

**FR9**: The system SHALL support a Finance Manager **reconciliation** workflow to **map** each `BankStatement` row to **exactly one `Transaction`** when the user completes reconciliation (from an initial state where **`BankStatement.Transaction` MAY be `NULL`** — **FR6**). The same **`Transaction`** MAY already exist and MAY already reference **one** other **`BankStatement`** (same underlying cash movement, two bank legs — **FR10**). Options:

- **Option A — Match existing Transaction**: The system surfaces existing `Transaction` records whose `Date` and `Amount` fall within the **reconciliation match window** (below); the user selects one and sets `BankStatement.Transaction` (including attaching a **second** `BankStatement` to a `Transaction` that already has **one** bank line, within the **FR10** cap).
- **Option B — Spawn from Invoice**: The system surfaces existing `Invoice` records whose dates and amounts fall within the same **reconciliation match window**; the user selects one; the system creates a new `Transaction` pre-populated from the Invoice data and links the **`BankStatement`** to it. **Product linkage model:** ongoing **`Invoice` ↔ `Transaction`** relationships (including many-to-many / split settlements) are represented in **`Allocation`** (**FR16**), **not** via a canonical **`Invoice.Transaction`** FK (**FR15**). Implementations MAY auto-create an **`Allocation`** row when spawning from Invoice where Finance policy requires it.
- **Reconciliation match window (Options A & B)** — applied relative to the `BankStatement` row being reconciled:
  - **Date:** candidate records whose date is within **±3 working (business) days** of the BankStatement date (weekends excluded; aligns with bank weekends and ~2-day international transfer delays). *Optional refinement:* exclude public holidays in a later iteration if Finance requires it.
  - **Amount:** candidate amount must be within **±5%** of the BankStatement `Amount` (symmetric band). Phase 1 compares **same currency only** (no FX conversion in the matcher); cross-currency suggestions are out of scope unless explicitly added later.
- **Option C — Create new Transaction**: The user creates a new `Transaction` from scratch (possibly in the same save as setting **`BankStatement.Transaction`**). The system pre-populates `OriginAccount` or `DestinationAccount` from `BankStatement.Account` based on sign: a positive `Amount` sets `DestinationAccount = BankStatement.Account`; a negative `Amount` sets `OriginAccount = BankStatement.Account`.
- An AI engine MAY perform reconciliation programmatically via `PATCH` / `POST` on `BankStatement` and related **`Transaction`** operations using the same rules, subject to Hook enforcement.

**Guided completion:** A Finance-facing **queue**, **invoice shortlist** (heuristics in **FR45.3**), **counterparty suggestions**, and **`Allocation`** creation/editing **SHALL** follow **FR45**.

**FR10**: The system SHALL enforce the following **`BankStatement` ↔ `Transaction` relationship** rules:

- **Import / create:** A **`BankStatement`** MAY be persisted with **`Transaction = NULL`** (**FR6**). **Reconciliation** sets **`BankStatement.Transaction`** to a non-null **`Transaction`**. **Deduplication** (**FR7**/**FR8**) runs on **`BankStatement` create** and does **not** re-run on reconciliation updates unless Architecture explicitly requires it.
- **Cardinality:** A **`Transaction`** MAY be referenced by **zero, one, or two** **`BankStatement`** rows (e.g. **zero** = ledger-only / manual **`Transaction`** with no bank mirror yet; **one** = normal; **two** = split legs such as currency-bridge pairs). **Link direction:** **`BankStatement` → `Transaction`** is canonical; **`Transaction` SHALL NOT** use a parallel **`BankStatementId`** (or similar) FK — navigation from **`Transaction`** to bank lines is **via reverse relation** or query.
- Attempting to link a **third** **`BankStatement`** to a **`Transaction`** that already has **two** **`BankStatement`** rows MUST be rejected with a descriptive error.
- **Hooks / DB constraints** MUST enforce the **0–2** cap when assigning or changing **`BankStatement.Transaction`**.

**`Transaction` → `Invoice` (optional):** After a **`BankStatement`** points to a **`Transaction`**, linking that **`Transaction`** to an **`Invoice`** is **MAY** only, via **`Allocation`** (**FR16**) — not every bank movement has a matching invoice.

**FR11**: The system SHALL expose **create / update / delete** for `Transaction` (fields: `OriginAccount`, `DestinationAccount`, `Amount`, `Currency`, `Description`, `Date`, `Project`) **only** to the Finance Manager role. The **`executive`** role SHALL **not** receive broader **`Transaction`** read access than **`employee`** — **no** special Executive RLS (**FR21**, **FR40**). **Supporting documents** (scans, PDFs, photos) for a transaction SHALL **not** use a per-row **`image`** (or similar) column — use **`Journal`** entries with `JournalLink.collection = 'Transaction'` (**FR12**). Legacy DB **`image`**, **`expense_id`**, or **`BankStatementId`** columns on **`Transaction`** (if present) are **non-canonical** (omit in Directus or read-only until dropped). **Evidence** and **bank linkage** use **`Journal`** and **`BankStatement.Transaction`** respectively.

---

### 5.4 Journal (Universal Document Linking)

**FR12** (**universal evidence / attachments**): The system SHALL use **`Journal`** as the **only** canonical place to attach **files, images, PDFs, and document URLs** **to a specific business object row** (per-parent evidence). Each attachment is one **`Journal`** row with **`ResourceURL`** and/or **`document_file`** (Directus Files API) and a polymorphic link **`JournalLink.collection`** + **`JournalLink.item`** to that parent. **Many `Journal` rows MAY reference the same parent** (`JournalLink.collection` + `JournalLink.item`) — e.g. multiple receipts for one **`Invoice`** or several scans for one **`Transaction`**. The STTM-style shape (**`JournalLink.collection`**, **`JournalLink.item`**, **`ResourceURL`**, plus optional file/entry metadata such as **``**) is sufficient to model this **1-to-many** polymorphic pattern; **do not** require a single exclusive FK from **`Journal`** to one table (**FR13**). **There SHALL NOT** be parallel **`image`**, **`receipt_image`**, or similar per-row attachment fields on **`Invoice`**, **`Transaction`**, **`Employee`**, **`Expense`**, etc. **`JournalLink.collection`** (string enum maintained in Directus) SHALL include at least: **`Invoice`**, **`Transaction`**, **`Employee`**, **`LegalEntity`**, **`Expense`**, **`Account`**, **`BankStatement`**, **`Project`**, **`InternalCost`** (extend in schema stories as needed).

**`LegalEntity.DocumentFolder` (canonical — default storage location):** The **`LegalEntity`** collection SHALL retain and expose **`DocumentFolder`** (URL to GDrive, GCS, shared drive, or equivalent). It is the **default organization-level storage root** for that legal entity’s documents (per BS4): integrations, Finance workflows, and future automation **MAY** use it as the **target folder** when syncing or archiving. It **does not** replace **`Journal`** for evidence tied to a specific **`Invoice`**, **`Transaction`**, or other keyed row — those remain **`Journal`** entries. **`DocumentFolder`** visibility SHALL follow **`LegalEntity`** read permissions (**FR40** / role matrix). Optional **`Journal`** rows with `JournalLink.collection = 'LegalEntity'` may still point to **entity-specific** docs when needed alongside the folder default.

**Directus UX:** Parent collection layouts SHALL surface a **Journal / attachments** panel (O2M-style filter on `JournalLink.collection` + `JournalLink.item`) so users with **`Journal`** permissions per **FR41** can add evidence in context; **`LegalEntity`** detail views SHALL show **`DocumentFolder`** as a labeled link or copyable URL for the default folder.

**Journal URLs and file links — visibility inheritance (SHALL):** Any **`ResourceURL`** value, any **download / asset URL** derived from **`document_file`** (e.g. Directus `GET /assets/:id` or signed links), and any API field that exposes such a URL **SHALL** be **available only** to users who **would** be allowed to **read** the **referenced parent record** (`JournalLink.collection` + `JournalLink.item`) under the same RBAC and RLS rules as **direct** access to that entity (**FR33**, **FR40**, **FR41**, etc.). Users without read access to the parent **SHALL NOT** see the **`Journal`** row in listings, **SHALL NOT** receive resolvable file URLs in API responses, and **SHALL NOT** fetch the underlying binary **via** that journal linkage. **Implementation** (Architecture / stories): combine **`Journal`** permissions with **parent visibility checks** (Directus hooks, filtered relations, **`Journal` RLS** that joins or predicates on parent tables, and/or **asset access** rules so public file URLs cannot bypass parent isolation).

**FR13**: The `Journal` collection SHALL NOT enforce an exclusive foreign-key to any single table. The `JournalLink.collection` field defines the linked entity type; `JournalLink.item` holds the target record's ID.

**FR14**: The system SHALL expose a **Completeness Score** Directus Insights widget that displays the percentage of `Transaction` records with at least one linked `Journal` entry, enabling Finance to monitor audit evidence coverage. A **similar** widget for **`Invoice`** (share of invoices with ≥1 `Journal` for `JournalLink.collection = 'Invoice'`) **SHOULD** be provided in Phase 1 where effort allows.

---

### 5.5 Invoices & Allocations

**FR15**: The system SHALL model **`Invoice`** as the unified **AR/AP** object (contractual payment terms between accounts — BS4 `BS4 Accounting Tool 2026NoLegacy.md` §Invoice): one record represents money owed between **`OriginAccount`** (debitor) and **`DestinationAccount`** (creditor), optional **`Project`** context, lifecycle **`Status`**, and settlement metadata. **Canonical fields:**

| Field | Semantics |
| ----- | --------- |
| **`OriginAccount`** | M2O → **`Account`** (debitor / sending side). |
| **`DestinationAccount`** | M2O → **`Account`** (creditor / receiving side). |
| **`Description`** | Free text. |
| **`SentDate`** | Date invoice sent / sending basis (maps legacy “date send”). |
| **`DueDate`** | Payment due date. |
| **`PaymentDate`** | Date paid when applicable. |
| **`Currency`** | M2O → **`Currency`**. |
| **`Amount`** | Monetary amount in **`Currency`**. |
| **`Status`** | Lifecycle (e.g. Planned, Sent, Paid, Cancelled — exact enum per schema/Finance). |
| **`Project`** | Optional M2O → **`Project`**. |
| **`RecurMonths`** | **Phase 1 (FR44 / FR47):** Billing cadence — in **`bidstruct4`** this **SHALL** be treated as an **integer number of months** between occurrences (e.g. **1** = monthly, **3** = quarterly, **12** = annual; **0** or null = non-recurring / one-time per **Architecture**). Directus **MAY** show friendly labels. **FR44** (spawn job) and **FR47** (cash view) **SHALL** use this integer-month semantics. |

**`Invoice` and `Employee` (SHALL NOT):** The canonical product model **MUST NOT** include **`employee_id`** (or any direct **`Employee`** FK) on **`Invoice`**. Many invoices are **not** tied to a person (B2B AP/AR, internal charges, etc.); person-specific context belongs on **`Account`**, **`Project`**, **`Journal`**, or downstream reporting — **not** a mandatory or optional employee link on the invoice row. Legacy DB **`employee_id`** on **`Invoice`**, if present, is **non-canonical**.

**Attachments (FR12):** PDFs, scans, and other files for an invoice SHALL be stored as **one or more `Journal`** rows with `JournalLink.collection = 'Invoice'` and `JournalLink.item` = invoice id — **not** as an **`image`** / **`document_file`** column on **`Invoice`**. Legacy DB columns (**`image`**, etc.) are **non-canonical**.

**`Invoice` ↔ `Transaction` (SHALL NOT):** The canonical product model **MUST NOT** use a direct **`Invoice` → `Transaction`** foreign key. **Cash settlement** and **many-to-many** links between invoices and bank-side transactions are modeled only through **`Allocation`** (**FR16**) and **`BankStatement` → `Transaction`** reconciliation (**FR9**/**FR10**). If the database retains a legacy **`Transaction`** column on **`Invoice`**, it is **non-canonical** — omit from Directus operator workflows or keep read-only until a migration **drops** it.

**Access:** **`finance-manager`**: full **CRUD** on **`Invoice`**. **`executive`**: **no** broader read than **`employee`** (**FR21**/**FR40**). Other roles: per **FR33**/**FR40**/**FR41** (HR read on Employee-ledger cash-side collections only; **no** HR write on `Invoice`).

**FR44** (**Phase 1 — recurring invoices, required**): Per BS4 §Invoice (recurrence + daily process), the product **in Phase 1** SHALL:
- Persist **`RecurMonths`** on **`Invoice`** as **integer months** between occurrences (**FR15**) so Finance can mark invoices as recurring.
- Provide a scheduled cron job that searches for **`Invoice`** rows where **`RecurMonths`** is **non-null** and **> 0** (recurring), and where the **`DueDate`** is **exactly equal to today**.
- **Create the next `Invoice`** row for the next period with its **`DueDate`** equal to the old invoice's `DueDate` plus `RecurMonths` months. The spawned invoice inherits the agreed fields (including the original `RecurMonths` value) and its `Status` is set to `"Sent"`.
- After a successful spawn, the **`RecurMonths`** value of the parent (original) invoice MUST be set to **0** (preventing it from recurring again). 
- **MUST NOT** send outbound emails (deferred to a later release).
- **MUST NOT** link the spawned invoice to its parent (series members are not explicitly linked via an origin/template ID).

**FR16**: The system SHALL expose **create / update / delete** for `Allocation` (fields: `Invoice`, `Transaction`, `Amount`, `OriginAccount`, `DestinationAccount`, `TransferLoss`) **only** to the Finance Manager role. The **`executive`** role SHALL **not** receive **`Allocation`** read access beyond **`employee`** (**FR21**/**FR40** — typically **none** in Phase 1).

**FR45** (**BankStatement completion queue & invoice–allocation assist**): The system SHALL provide **Finance Manager** tooling (Directus **saved view**, **bookmark**, **module extension**, or **Flow** — **Architecture** / implementation story selects) for **reconciliation** and **optional invoice allocation**, consistent with **FR6**, **FR9**, **FR10**, and **FR16**. **Traceability:** archived notes in **`_bmad-output/reference/bank-statement-allocation-legacy-source.md`**; alignment notes in **`_bmad-output/reference/bank-statement-allocation-prd-alignment.md`** (non-normative).

**FR45.1 — Completion queue (“lines needing work”):** The UI SHALL offer a **default filter** (or dedicated view) listing **`BankStatement`** rows where **`Transaction` IS NULL** **or** the linked **`Transaction`** does **not** yet have **both** **`OriginAccount`** and **`DestinationAccount`** set.

**FR45.2 — Create or complete `Transaction` from the bank row:** When the user works a **`BankStatement`** in this flow, the system SHALL support **linking** to an **existing** **`Transaction`** (including one that already has **one** **`BankStatement`**, within **FR10**) **or** **creating** a new **`Transaction`**. When creating or completing from bank data alone: if **`BankStatement.Amount` < 0**, set **`Transaction.OriginAccount`** = **`BankStatement.Account`**; if **`Amount` ≥ 0**, set **`Transaction.DestinationAccount`** = **`BankStatement.Account`**; set **`Transaction.Amount`** to the **absolute value** of **`BankStatement.Amount`**; copy **`Date`** and **`Description`** from **`BankStatement`**; set **`Currency`** (and any required fields) per **Architecture** from **`BankStatement`** / **`Account`** context.

**FR45.3 — Suggested `Invoice` list (Phase 1 heuristics):** The UI SHALL surface **`Invoice`** candidates for the **current** `BankStatement` / `Transaction` context where: **(a)** the **amount** is within **±10%** (symmetric) of the **`Transaction`** or **`BankStatement`** **amount**, **same currency** only in Phase 1; **(b)** an **`Invoice`** date field agreed in **Architecture** (e.g. **`SentDate`** or **`DueDate`**) is within **±4 calendar months** of **`BankStatement.Date`** (or **`Transaction.Date`** if bank date unavailable — **Architecture** picks anchor); **(c)** **either** **`Invoice.OriginAccount`** or **`Invoice.DestinationAccount`** overlaps the **`Transaction`** account leg already known; **(d)** the invoice is **eligible for allocation** (e.g. **no** duplicate **`Allocation`** for this **`Transaction`+`Invoice`** pair — exact predicate **Architecture**). **Later phase:** **AI-assisted similarity** (amount, text, counterparties) **MAY** replace or refine these fixed bands — not required for Phase 1 beyond documenting intent.

**FR45.4 — User selects an `Invoice`:** On selection, the system SHALL: copy the **missing** **`OriginAccount` or `DestinationAccount`** from **`Invoice`** onto **`Transaction`** if not yet set; **create** an **`Allocation`** row joining that **`Transaction`** and **`Invoice`** (**FR16**); **suggest** **`Transaction.Project`**, **`Transaction.Description`**, and related **`Allocation`** fields from **`Invoice`** where still empty; allow **edit** of **`Allocation`**, including **`TransferLoss`**, before commit (follow-up invoice or manual correction remains a Finance process).

**FR45.5 — Fallback when no suitable `Invoice`:** If **FR45.3** returns no candidates, the system SHALL: **(A)** search **prior **`BankStatement`** rows** with **similar `Description`** (text similarity — **Architecture** defines, e.g. token overlap / fuzzy match) **for which** Finance already chose a **counterparty** leg (**the other `Account`** on the linked **`Transaction`**), and **offer that counterparty** as a suggestion; **(B)** if **(A)** is empty, surface **`Account`** rows whose **`Name`** is **similar** to **`BankStatement.Description`**. The user SHALL pick the **counterparty** **`Account`** (from list or via **normal `Account` create**), completing the missing **`Transaction`** leg.

**FR45.6 — End state:** **Bank reconciliation:** **`BankStatement.Transaction`** is **set** (mapped). **`Transaction`** has **both** **`OriginAccount`** and **`DestinationAccount`** and **`Project`** set. **`Invoice` linkage:** **`Allocation`** linking **`Transaction`** to **`Invoice`** exists **only when** Finance explicitly matched an invoice (**FR45.4**); **no** requirement that every **`Transaction`** has an **`Allocation`** (**FR10** last paragraph).

**FR17**: The system SHALL expose **create / update / delete** on `Accruals` (fields: `Project`, `Amount`, `Currency`, `FiscalYear`) **only** to the Finance Manager role. **`Accruals` SHALL remain Finance-only:** **`hr-manager`**, **`line-manager`**, **`employee`**, and **`executive`** SHALL have **neither** read **nor** write on **`Accruals`** (no Phase 1 carve-out; normative unless a future PRD major revision explicitly changes this).

---

### 5.6 Currency Management

**FR18**: The system SHALL expose the `Currency` collection as a reference lookup (read-only for most roles, Finance Manager editable) containing `CurrencyCode` and `Name`.

**FR19**: The system SHALL model `CurrencyExchange` as a **daily FX snapshot** table relative to USD as the common base for cross-rate derivation and reporting (convert invoice amounts to a legal entity’s reporting currency **on that calendar day**). The canonical row SHALL contain only:
- **`Currency`** — M2O / FK to `Currency` (exactly one currency per row).
- **`Date`** — **date only** (no time-of-day component).
- **`RateToUSD`** — numeric rate meaning **1 USD = X units of that currency** (not the inverse).

The system SHALL enforce **at most one row per (`Currency`, `Date`)** (unique constraint or equivalent). Legacy or redundant columns (`Key`, `Month`, `Year`, `Day` as a parallel date key) SHALL NOT be part of the canonical product model; schema alignment is a migration concern.

**Operational policy (Phase 1+):**
- **Automated ingestion:** Historical and daily rate loading (**FR42**) SHALL be implemented by **developers** (scheduled jobs, migration scripts, Airflow / Apps Script / equivalent) — not an end-user Finance workflow in Directus.
- **Manual correction:** **Finance Manager** SHALL have **create / update / delete** on `CurrencyExchange` to correct erroneous or missing rates when automation or source data is wrong.
- **Sensitivity:** FX snapshot rows are **non-sensitive** (reference data, not payroll or ledger secrets). **`CurrencyExchange` is out of scope for PostgreSQL RLS** (NFR13); access control is **Directus RBAC only**.
- **RBAC posture:** The collection SHALL **not** be treated as Finance-exclusive like **`Accruals` / `Allocation`** (**`Journal`** follows **FR41**). **Read** access MAY be granted to **`hr-manager`** and to **`employee` / `executive`** (same rule for both per **FR21**) for transparency where policy allows. **Write** remains **Finance Manager** in Phase 1 unless a later story changes it. **Directus presentation:** the collection MAY be **hidden from the Admin sidebar** for some roles via layout/bookmark configuration without changing the underlying permission model.

**FR42** *(future functional requirement — currency rate ingestion)*: The product SHALL support populating `CurrencyExchange` for **historical data (from 2013 onward)** and **ongoing daily updates** via a **developer-operated** backend retrieval process (see **FR19** for Finance manual correction and RBAC). Recommended approaches and sources (implementation detail may live in Architecture / runbooks; behavior below is the product intent):

1. **Initial setup — historical data (2013–present)**  
   For a one-time migration of historical rates, use a provider with long-term retention.  
   - **Recommended source:** Frankfurter API (European Central Bank data).  
   - **Why:** Free, open-source, historical data back to 1999.  
   - **How to query:** Date-range request for monthly or daily rates during migration.  
   - **Example format:** `https://api.frankfurter.app/2013-01-01..2026-01-01?base=USD`  
   - **Implementation note:** A Python script (e.g. in Google Colab for migration) can iterate date ranges, parse JSON, and insert rows into PostgreSQL `CurrencyExchange` aligned with **FR19** (`Currency`, `Date`, `RateToUSD`).

2. **Ongoing — daily updates**  
   For regular operations in BS4, reliability matters.  
   - **Recommended sources:** ExchangeRate-API or Frankfurter.  
   - **Why:** ExchangeRate-API free tier (~1,500 requests/month) suits a daily job; Frankfurter suits no-key access.  
   - **How to query:** GET latest rates for base USD.  
   - **Example format:** `https://open.er-api.com/v6/latest/USD`  
   - **Implementation note:** Automate via Google Apps Script, Apache Airflow, or equivalent so the job runs at least every 24 hours and **appends** one row per currency per calendar **Date** (per **FR19** uniqueness).

---

### 5.7 Executive P&L Visibility

**FR20**: The system SHALL configure **Directus Insights** dashboard(s) presenting monthly and annual Profit/Loss and other **aggregated** views **for convenience**. Panels are built and maintained by the Finance Manager (e.g. `SUM(Amount)` grouped by month/project). The **`executive`** role MAY be granted **dashboard view** access. **RLS rule (2026-03-16):** Insights queries **MUST** respect the **same** row visibility as **`items.read`** for that user (**FR21**, **FR40**, **NFR13**) — **no** bypass for Executives or any role, **except** where **FR47.1** documents an **interim Phase 1** reporting path (org-wide cash panel). Default dashboard filters MAY highlight an Executive’s **assigned** `ProfitCenter`(s) for UX only. **Cash flow reporting** (**past `Transaction` + forward `Invoice`**) **SHALL** follow **FR47** (extends legacy **Looker** spec — **`_bmad-output/reference/cashflow-looker-reports-legacy-source.md`**).

**FR47** (**Cash flow report — Directus Insights or successor**): The system SHALL provide a **combined cash flow** view (implemented as **Directus Insights** panel(s) **or** an **equivalent** in-repo reporting layer — **FR47.9**): **(a)** **historical** series from **`Transaction`** (past periods); **(b)** **forward-looking** series from **`Invoice`** (**Planned** / **Sent**, **`DueDate`**-driven, with virtual recurring rows per **FR47.7**). **`BankStatement` SHALL NOT** feed this report (out of scope for this dashboard). **Looker** is **not** required. **Traceability:** **`_bmad-output/reference/cashflow-looker-reports-legacy-source.md`**. **Story:** Epic **6.3**.

**FR47.1 — Roles & Phase 1 visibility (PM 2026-03):** **`finance-manager`** and **`executive`** **SHALL** both be able to use the **same** cash flow dashboard definition (**org-wide** series — **no** per–**ProfitCenter** row filter on this panel **for now**). **Future:** the product **SHOULD** introduce a **ProfitCenter owner** (often an **executive**) who sees only **owned** **`ProfitCenter`** slice — **deferred**. **Implementation note:** achieving org-wide visibility **SHALL** comply with **NFR1**/**NFR13** (e.g. reporting views, definer rights, or explicit read grants documented in **Architecture**) — **SHALL NOT** silently weaken unrelated collections.

**FR47.2 — Forward scope (`Invoice`):** Include **`Invoice`** rows with **`Status`** ∈ {**`Planned`**, **`Sent`**} (exact labels per schema). Bucket **upcoming** amounts by the **active time grain** (**FR47.9** — default **calendar month**) using **`Invoice.DueDate`**.

**FR47.3 — Past scope (`Transaction`):** Include **`Transaction`** rows using **`Transaction.Date`** (or agreed ledger date) grouped by the **active time grain** (**FR47.9**), limited to the **selected past window** (**FR47.9**, default **24 trailing months**). **SHALL NOT** include **`BankStatement`** in this report.

**FR47.4 — `LegalEntity.Type` (corrected model):** **`Project`** relates to **`ProfitCenter`**; it **does not** provide a direct **`Project` → `LegalEntity`** path for typing. **`LegalEntity`** may have **zero or many** **`Project`**s. For **invoice** classification (Salary block, sign context), **`LegalEntity.Type`** **SHALL** be resolved from **`Invoice.OriginAccount` / `DestinationAccount` → `LegalEntity` → `Type`** (same **either-leg** spirit as **FR40** where applicable — **Architecture** picks **primary leg** for display sign per **FR47.5**).

**FR47.5 — Amount sign (invoice forward series):** When **`Invoice.OriginAccount` → `LegalEntity` → `Type` = `Internal`**, show amount as **negative**; otherwise **positive**. **Transaction (past / realized) series:** The reporting surface **SHALL** use **stored `Transaction.Amount`** **as-is** (no panel-side sign flip). **FR47.8** / **FR47.9** define how **realized** and **forecast** series are **structured** and **parameterized**.

**FR47.6 — Salary block (forward series):** Aggregate invoices whose relevant **`LegalEntity.Type`** ∈ {**`Employee`**, **`Executive`**} (per **FR47.4**) into one **“Salary”** series; **SHALL** display as **negative** in the forward view.

**FR47.7 — Recurring expansion (view-only):** **`Invoice.RecurMonths`** is an **integer = months between occurrences** (**FR15**). For **display only** (no persisted clone unless **FR44** creates rows), over the **selected forward window** from the report **as-of** date (**FR47.9** — default **24 calendar months**):
- **`RecurMonths` = 1:** synthesize **per-recurrence** points through that horizon from anchor **`DueDate`** (cap at **horizon end**; step count **SHALL** respect **FR47.9** max forward span).
- **`RecurMonths` = 12:** synthesize points every **twelve** months within the same horizon.
- **Other N:** synthesize per **N**-month steps within the same horizon.

**FR47.8 — Presentation rules (structure):**
1. **Realized vs forecast:** The cash dashboard **SHALL** use **at least two clearly labeled series** (or sub-panels): **“Realized — `Transaction`”** (past window per **FR47.9**, amounts = **raw `Transaction.Amount`**, **FR47.5**) and **“Forecast — `Invoice`”** (forward **FR47.2** + **FR47.7**). **SHALL NOT** imply a single net cash number by silently mixing sign rules; a **future** story **MAY** add one **harmonized “net cash”** series once Finance signs a single convention.
2. **ProfitCenter owner / scoped executive view:** **Out of scope for Phase 1.** No **per–`ProfitCenter`** filter on this dashboard; **FR47.1** stands until **Phase 2+** adds ownership metadata and reporting views.

**FR47.9 — Time windows & granularity (user-defined where feasible):**
1. **Product intent:** **`finance-manager`** and **`executive`** (where the dashboard is shared per **FR47.1**) **SHOULD** be able to **adjust** — without developer deploy — **(a)** the **past** lookback span, **(b)** the **forward** forecast span, **(c)** the **as-of** / anchor date (if the tool supports it), and **(d)** the **reporting granularity**: **monthly**, **quarterly**, or **annually** (calendar-aligned roll-ups of **`Transaction.Date`** / **`Invoice.DueDate`**).
2. **Phase 1 default:** **Past** = **24 trailing calendar months**; **forward** = **24 calendar months**; **granularity** = **monthly**. These **SHALL** be the **initial** panel settings when no user overrides exist.
3. **Directus Insights feasibility:** **Architecture** SHALL **spike** which of (1) are **native** (e.g. dashboard/panel variables, date filters), which need a **small extension** or **parameterized database view**, and which are **not** achievable without leaving Insights.
4. **Later increment / tool change:** **Quarterly** and **annual** grains and **full** user control of spans **MAY** ship in a **follow-on** story once the reporting mechanism supports them. If **Directus Insights** **cannot** meet **reasonable** configurability after the spike, **FR47** **MAY** be implemented in **another** approved tool or **in-repo** reporting (**SQL view + chart**, BI product, etc.) **provided** **NFR1**/**NFR13** and **FR47.1** visibility rules **still** hold — record the decision in **Architecture** (**ADR**).

**FR21** (**Executive = normal user — no special RLS**): The **`executive`** Directus role SHALL have **the same** collection-level and item-level **read** posture as **`employee`** for **sensitive** data (Employee-/Executive-ledger financials — including **recurring payroll `Invoice`** rows — Finance-only collections, and **`Journal`** — see **FR40**/**FR41**). Holding **`executive`** **SHALL NOT** grant extra PostgreSQL RLS paths, extra Directus filters, or **Insights** queries that return rows the user could not read via the API. **ProfitCenter** on `Project` remains for **reporting and UX** defaults only. **Writes:** Executives SHALL **not** receive create/update/delete on Finance-operated ledger collections (`Account`, `BankStatement`, `Transaction`, `Invoice`, `Allocation`, `Accruals`, `Journal`, **`InternalCost`**) unless delegated — those remain **`finance-manager`**. Executives SHALL **not** receive **create / update / delete** on HR-operated collections (`Employee`, `EmployeePersonalInfo`, `TimeEntry`, `Leaves`, `Task`) in Phase 1 unless extended — **`hr-manager`** (and scoped roles per FR25–FR29) retain operational **write** ownership. **Non-sensitive** reference data (**`Currency`**, **`CurrencyExchange`** if granted per **FR19**, `Project`, `LegalEntity`, etc.): **`executive`** = **`employee`** for permissions. Users who also hold **`line-manager`** get **manager** visibility (**FR33**/**FR40**) in addition, not via **`executive`** alone.

---

### 5.8 HR — Employee Lifecycle

**FR22**: The system SHALL expose full CRUD for `Employee` (fields: `email`, `mobile_number`, `employ_start_date`, `status`, `Seniority`, `departmentid`, `DesignationID`, `EmployeeName`, `DefaultProjectId`, **`Manager`**) to the HR Manager role for **all** employee records. **`Manager`** is an M2O → **`Employee`** (the subject’s **direct manager**). The stored value is the **manager’s `Employee` primary key** (unique id); **operator-visible labels** for lists, pickers, and relation chips **SHALL** use the **manager’s `email`** (and name) as the human-readable reference — **not** a bare surrogate id (**NFR14**). Legacy DB column name **`ManagerId`** is acceptable if the data model retains it; product language uses **Manager → Employee**. Policy:
- The legacy DB column `ProfitCenter` on `Employee` SHALL **not** be exposed in Directus Admin (or any deferred SPA) in Phase 1 (hidden/omitted from collection config — no relational link to the `ProfitCenter` entity from `Employee`; see A2).
- **`DefaultProjectId`** (**M2O → `Project`**) **SHALL** be the **default project for the employee’s effort** — used as **`InternalCost.FromProject`** default in **FR43**, as the **default `Project`** on **`TimeEntry`** UX when applicable, and as the **default `Project`** on **FR28** **`Transaction`/`Invoice`** when the employee omits a project. If the physical FK is missing from the database, **Architecture** SHALL **add** this relation (same semantics; column name MAY differ in migration). It SHALL **not** be used in any Directus item-level permission filter that controls **visibility** of `Employee` rows or of **financial** collections (see FR40).
- **Required for self-service:** **`TimeEntry`** create and **FR28** submit **SHALL** be **blocked** (validation hook or Flow) when **`DefaultProjectId`** is **null**, with an operator-visible message to contact **HR** to set a default project — **unless** **Architecture** documents a **narrow** exception (e.g. non-timekeeping roles).
- **Attachments** (contracts, ID scans, etc.) SHALL use **`Journal`** with `JournalLink.collection = 'Employee'` (**FR12**) — **not** ad-hoc **`image`** columns on **`Employee`**.

**FR23**: The system SHALL expose full CRUD for `EmployeePersonalInfo` (fields: `personal_email`, `phone_no`, `father_name`, `emergency_contact_phone/name`, `cnic`, `ntn`, `date_of_birth`, `country`, `city_area`, `address_line`) linked to `Employee` (1:1). Access restricted to HR Manager and the Employee themselves (own record only). Sensitive identifier handling and audit MUST comply with **NFR8** and **NFR11**.

**FR24**: The system SHALL expose the `Seniority`, `Designation`, and `department` tables as reference/lookup collections, with HR Manager CRUD and read-only access for other administrative roles.

**FR24.1 — `Seniority` rate for time → `InternalCost`:** The **`Seniority`** row **SHALL** include a **single numeric day-rate field** used by **FR43** (name in DB **MAY** differ — **Architecture** maps to **`DayRate`** in Directus; semantics: **currency units per calendar day** in the **company’s internal reporting currency** unless **Architecture** documents per-row currency). **No** per-employee rate override in Phase 1; **FR43** uses **only** this **`Seniority.DayRate`** (or mapped column) × **derived hours**.

---

### 5.9 HR — Time & Leave Tracking

**FR25**: The system SHALL expose the `TimeEntry` collection (fields: `Description`, `StartDateTime`, `EndDateTime`, `Employee`, `Project`) with:

- **SHALL NOT** require **`HoursWorked`** as a persisted field: duration **SHALL** be **derived** from **`EndDateTime` − `StartDateTime`** (reports, validation, and UX MAY show computed hours). Legacy **`HoursWorked`** columns, if present, are **non-canonical** optional/read-only until dropped.
- **SHALL NOT** require **`Task`**: **`Project`** is the **granular cost / effort** anchor for Phase 1; optional **`Task`** links, if retained in schema for other flows, are **out of canonical scope** for time entry (**Architecture** may hide or omit in Directus).
- **`Project`** picker (Directus and extensions) **SHALL** restrict to **open** projects — default rule: **`Project.Status = Active`** (or equivalent **Architecture** flag).

**Access:**

- Employees: Create/Read/Update their own entries only
- Line Managers: Read entries for their direct reports
- HR Manager: Read all

**FR26**: The system SHALL expose the `Leaves` collection (fields: `Type`, `StartDate`, `EndDate`, `Employee`) with:

- Employees: Create and view own leave requests via Directus (Phase 1); deferred SPA optional later
- Line Managers: Read and Update (`Status`) for direct reports (approve/reject)
- HR Manager: Full CRUD

**FR27**: The system SHALL expose the `Task` collection (fields: `Name`, `Description`, `Status`, `Project`, `DueDate`, `Employee`) with:

- Employees: Read tasks assigned to them; Update `Status` on own tasks
- Line Managers: Full CRUD for their team's tasks
- HR Manager: Read all

---

### 5.10 HR — Employee spend & reimbursement (**no `Expense` collection**)

**FR28** (**employee spend — ledger materialization**): The system SHALL **not** use a canonical **`Expense`** collection for employee spend tracking. Instead, it SHALL provide a **Directus**-native workflow (**Flow**, extension, or guided form) so an **Employee** can submit: **receipt** (file), **amount**, **currency**, **optional `Project`**, and **payment context** (**company-paid account** vs **paid personally / to be reimbursed**). On submit, the system **SHALL** **immediately** create:

1. **`Transaction`** — when paid with a **company** account / card, **with** **`Project`** = selected project **or** **`Employee.DefaultProjectId`** (**FR22**), **and** **only if** **FR28.1** dedup finds **no** matching row. If a match exists, the system **SHALL NOT** create a second **`Transaction`** automatically (**`finance-manager`** may adjust manually).

2. **`Invoice`** — when paid **personally**, representing **AP / reimbursement** to the employee per **FR28.2**, **with** **`Project`** = selected project **or** **`Employee.DefaultProjectId`**.

**FR28.1 — “Similar `Transaction`” (company-card dedup):** Before insert, the system **SHALL** treat an existing **`Transaction`** as a **duplicate** if **all** of the following hold (evaluated in **reporting / company timezone** per **Architecture**, default **UTC** if unset):
- **Same submitter identity** — the **same authenticated user** (or **same `Employee`** resolved from that user — **Architecture** implements the link used at create time).
- **Same selected company-paid `Account`** — the **company card / cash account** chosen in the workflow appears on the **same ledger leg** as defined in **Architecture** (typically **`BankStatement.Account`**-style leg on **`Transaction`**).
- **Same `Project`** FK (including **both null** if that were allowed — **SHOULD NOT** occur if **FR22** default is enforced).
- **Same `Currency`**.
- **Same calendar `Date`** on **`Transaction.Date`** (submission date for **FR28**-created rows in Phase 1).
- **Same absolute amount** — **`Transaction.Amount`** matches **exactly** to **two decimal places** (or **integer minor units** — **Architecture** matches DB type).

**FR28.2 — Personal reimbursement `Invoice` template:** For the **personal / reimbursed** path, **`Invoice` SHALL** use the **standard account pair** from **Architecture** / Finance seed data: **one `Account` leg SHALL resolve** to the submitter’s **`LegalEntity`** with **`Type = 'Employee'`** (employee-side **payable** to the company), and **the other leg SHALL** be the **designated internal reimbursement clearing / AP account** (**`LegalEntity.Type = 'Internal'`**). **`Status`** **SHALL** default to **`Planned`** (or **`Sent`** if Finance prefers immediate recognition — **Architecture** picks one default). **Exact `Account` IDs** are **data/environment**, not hardcoded in application logic beyond configuration.

**Finance** MAY **contest, edit, void, or replace** these rows after creation; there is **no** separate pre-approval gate in Phase 1.

**Access (high level):** **Employees** initiate the workflow and **read** **`Transaction`/`Invoice`** (and **`Journal`**) **they created** via **FR41** / **Architecture** attribution; **`finance-manager`**: full **CRUD** on **`Transaction`/`Invoice`**; **HR Manager**: read per **FR33** on employee-ledger rows. **There SHALL NOT** be a persisted **`Expense`** row as the books-of-record object.

**FR29** (**receipt files**): The system SHALL support **file upload** for employee spend evidence **only** through **`Journal.document_file`** / **`ResourceURL`** (**FR12**) with **`JournalLink.collection`** ∈ {**`Transaction`**, **`Invoice`**} and **`JournalLink.item`** = the created row. **Legacy `JournalLink.collection = 'Expense'`** **SHALL NOT** be used for new implementations. **Directus Files API** stores assets as managed files.

---

### 5.11 Internal Cost Transfers

**FR30**: The system SHALL model **`InternalCost`** as **project-to-project internal allocation** — i.e. moving **recognized internal cost / effort attribution** from one **`Project`** to another **without** replacing cash-basis ledger entries (`Transaction` / `Invoice` / `BankStatement`). **ProfitCenter** is **not** part of the canonical product shape for this table: PC is **derived for reporting** from **`Project.ProfitCenter`** (and legal-entity context on the project) when needed; legacy DB columns **`FromPC`** / **`ToPC`** (if present) are **not** canonical and SHOULD be **omitted or read-only legacy** in Directus — migration may drop them in a later story.

**Canonical fields and semantics:**

| Field | Semantics |
| ----- | --------- |
| **`FromProject`** | M2O → **`Project`** — **required** (when row is complete): source project of the internal charge. |
| **`ToProject`** | M2O → **`Project`** — **required** (when row is complete): destination project receiving the allocation. |
| **`Currency`** | M2O → **`Currency`** — denomination of **`Amount`**. |
| **`Date`** | Calendar **date** anchoring the **allocation period** (for **FR43** monthly rows: typically **one date per calendar month**, e.g. month-end or first-of-month — Finance to confirm); date-only, no time-of-day. |
| **`Amount`** | Numeric magnitude of the allocation in **`Currency`** (for **FR43**: **sum** of all contributing effort per pair/period). |

**`InternalCost` ↔ `TimeEntry` (SHALL NOT):** The canonical product model **MUST NOT** include a foreign key from **`InternalCost`** to **`TimeEntry`** (no **`TimeEntryId`**). Allocations are **aggregates**: drill-down to supporting time is done by **reporting / queries over `TimeEntry`** (e.g. filter by `Project`, employee, date range) — **not** by a per-row link on `InternalCost`. If the legacy database column **`TimeEntryId`** exists, it is **non-canonical**; Directus SHOULD **omit** it (or keep read-only hidden) and a migration story MAY **drop** it.

**Integrity (SHOULD):** When both projects are set, validation **SHOULD** reject **`FromProject` = `ToProject`**. For rows produced by **FR43**, the system **SHOULD** enforce **at most one** `InternalCost` row per **distinct (`FromProject`, `ToProject`, calendar month`)** (idempotent monthly job: upsert/replace the same logical row).

**Scope boundary (SHALL NOT):** Neutral **treasury / inter-company bank movements** that do **not** change **project-level** internal attribution SHALL use **`Transaction`** / **`Invoice`** only — **not** `InternalCost`. Use `InternalCost` when Finance intentionally **re-attributes effort/cost between projects** (internal “invoice” in the BS4 sense).

**Access:** **`finance-manager`**: full **CRUD**. **`executive`**: **no** broader read than **`employee`** (**FR21**/**FR40** — typically **none**). **Other roles** (HR Manager, Line Manager, Employee): **no** read/write on `InternalCost` in Phase 1 unless extended. **PostgreSQL RLS** is **not** required on `InternalCost` for Phase 1 unless Architecture adds it (**NFR13**).

**FR43** *(future functional requirement — time tracking → monthly `InternalCost`)*: The product SHALL support a **developer-operated** process run **at least once per calendar month** that:

1. Considers **all** relevant **`TimeEntry`** rows for that month (all employees). **Hours** **SHALL** be derived from **`EndDateTime` − `StartDateTime`** (**FR25**). **Cost rate** **SHALL** come **only** from **`Seniority`** via **FR24.1** (**`DayRate`** or **Architecture**-mapped column); **no** per-employee rate override in Phase 1 unless a later FR adds it.
2. Derives, for that month, which **internal effort** flows from each **source `Project`** to each **destination `Project`**. **Default mapping (SHALL):** **FromProject** = **`Employee.DefaultProjectId`** and **ToProject** = **`TimeEntry.Project`** for each employee’s time (**FR22**). Finance **MAY** document exceptions in **Architecture**; mapping is **not** stored as FKs on **`InternalCost`**.
3. For **each distinct (`FromProject`, `ToProject`)** pair that has non-zero allocated effort in that month, **creates or updates exactly one** **`InternalCost`** row for that month (**no** `TimeEntryId`; **`Amount`** = aggregated **hours × Seniority rate** (or agreed formula) for that pair; **`Date`** / period key per **FR30**).

Re-runs for the same month **SHOULD** be **idempotent** (same pair → same single row updated, not duplicated). Finance **reviews** / **manually corrects** `InternalCost` in Directus as needed (**FR30**). Traceability to underlying time remains via **`TimeEntry`** reports, not row-level links.

---

### 5.12 RBAC Configuration

**FR31**: The system SHALL configure Directus roles matching the four administrative personas: **Finance Manager**, **Executive**, **HR Manager**, **Line Manager**, plus one end-user role: **Employee**.

**FR32**: The system SHALL configure collection-level permissions for each role using Directus Permissions API, mapping every collection to the correct CRUD combination per the Access Control Model in Section 4.

**FR33**: The system SHALL configure item-level permission filters aligned with **four RLS privilege tiers** (**FR40**), **with `BankStatement` visibility governed solely by FR40.1** (Finance-only — **not** part of HR or line-manager Employee-ledger read paths): (1) **baseline employee** — any staff user without Finance/HR/manager elevation; (2) **line manager** — may see **subordinates’ payroll-related recurring `Invoice` rows** and related **`Transaction`** rows per **FR40** — **not** **`BankStatement`** — for **all subordinates** (direct and indirect via the **`Employee` → `Manager`** link — **FR22**) plus existing team operational data; (3) **HR** — may see **employee-ledger** **`Account`**, **`Transaction`**, and **`Invoice`** rows **except** where **either** account leg is **`LegalEntity.Type = 'Executive'`** — **not** **`BankStatement`** (**FR40.1**); (4) **Finance** — full visibility including **`BankStatement`**. **`executive`** uses tier **(1)** only unless the same user is also **`line-manager`** (**tier 2**). **Payroll** is modeled **only** as **`Invoice`** (recurrence on **Employee/Executive `LegalEntity`** accounts — BS4); **no** extra payroll collection. **Colloquial “salary”** for HR: **§4.4**.

- **Executive** (**FR21**): **Same** item-level rules as **`employee`** on every collection — **no** blanket “see all rows” filters.
- **HR Manager**: No item-level filter on `Employee`. On **`Account`**, **`Transaction`**, and **`Invoice`** (read only): filter restricts to rows where **at least one** account FK resolves to **`LegalEntity.Type = 'Employee'`** (i.e. `OriginAccount` OR `DestinationAccount` touches an Employee account), **AND no** account FK resolves to **`LegalEntity.Type = 'Executive'`**. Any row where **either** leg touches an Executive-type `LegalEntity` is **invisible to HR** (**`finance-manager`** may still CRUD per **FR40**). **`BankStatement`**: **no** collection access for **`hr-manager`** — **FR40.1**. Enforced at **Directus** and **PostgreSQL RLS** (NFR13). `Employee.DefaultProjectId` / `Employee.ProfitCenter` MUST NOT be used in these filters. On **`Journal`** (read only): restrict to **`JournalLink.collection`** ∈ {`Transaction`, `Invoice`, `Employee`} **with** item filters consistent with **FR33** / **FR41** (employee-ledger evidence).
- **Employee**: All personal records (`TimeEntry`, `Leaves`, `Task`) scoped to `currentUser.employee_id`. **`Transaction`/`Invoice`** created via **FR28**: **read** (and **initiate** via workflow) scoped per **FR41** / **Architecture** (employee attribution). On **`Journal`**: **read** (and **create** where Directus allows) for evidence on **own** **FR28** parents and **`JournalLink.collection = 'Employee'`** on **own** **`Employee`** row; use **hooks** if item-level filters cannot express create-time validation.
- **Line Manager**: Team records scoped to **`Employee.Manager` = current user’s `Employee` id** (direct reports; field name may be **`ManagerId`** in DB) **or** recursive subordinate chain per Architecture — **and** **read** access to **payroll-related recurring `Invoice` rows** (and ledger rows tied to those invoices) for those subordinates only, **`Employee`-ledger only** (**FR40**); **no** org-wide financial ledger read beyond that rule unless extended.

---

### 5.13 Employee Self-Service — **Phase 1: Directus-only (speed path)**

**PM decision (2026-03-17):** Phase 1 **does not** require a separate employee SPA. Employees use **Directus Admin** (with RBAC limiting visible collections) and/or **Directus extensions** in `projects/internal-erp/directus/extensions/` for targeted flows (e.g. receipt capture). All behavior remains **API-enforced** (NFR1).

**Phase 1 minimum (satisfied without FR35–FR39 SPA):**
- **Time / leave / employee spend (FR28)** data entry and file upload for receipts via Directus, meeting FR25–FR29 (Files API).
- **Project ordering / daily confirmation / polished mobile UX** are **nice-to-have** in Admin; implement in extensions or defer to future SPA.

---

### 5.14 Dedicated employee SPA (FR35–FR39) — **DEFERRED**

The following requirements describe a **future** dedicated employee SPA (originally Lovable). They are **out of scope for Phase 1 delivery** but preserved so a later increment (Lovable, in-repo Vite app, or other) can adopt the same backend.

**FR35** *(deferred)*: A dedicated (e.g. React/Vite/Tailwind) SPA **MAY** be scaffolded as an optional employee self-service interface. It SHALL communicate exclusively with the Directus REST API using a per-user Directus auth token. No direct database connections.

**FR36** *(deferred)*: The SPA's time logging screen SHALL display only `Project` records where `Status = 'Active'`, ordered by: projects whose `Project.ProfitCenter` matches the **authenticated user's assigned ProfitCenter** (from `directus_users` / role profile — **not** from `Employee.ProfitCenter`) first, then other Active projects (e.g. organization-wide), sorted by most recent `TimeEntry` activity descending.

**FR37** *(deferred)*: The SPA SHALL include a **Daily Confirmation** component — a sparkline/timeline view of the previous day's **recorded** `TimeEntry` rows (manual entry in Phase 1), with a single one-tap "Confirm" action that marks them as verified. **Note:** Jira/Email/Calendar ambient capture is out of scope for Phase 1 (see Assumption A4); wording MUST NOT imply integrations exist in Phase 1.

**FR38** *(deferred)*: The SPA SHALL provide a leave request form linked to the `Leaves` collection, showing current leave balance (derived from approved Leaves records) and a submission form.

**FR39** *(deferred)*: If a future SPA is built, it SHALL provide an employee spend form **equivalent to FR28** (materialize **`Transaction`/`Invoice` + `Journal`**); **SHALL NOT** target a canonical **`Expense`** collection.

---

### 5.15 Financial Ledger Visibility Policy

**FR40** (**confirmed policy — RLS privilege tiers**): PostgreSQL RLS and Directus item-level rules SHALL implement **exactly four** visibility tiers for sensitive **Employee-/Executive-ledger** money (including **payroll modeled as recurring `Invoice`** — not five tiers; the **`executive`** Directus persona is **not** a separate RLS tier; **FR21**):

1. **Baseline (any employee / default user)** — Users who are **not** Finance, not HR, and **not** granted **line-manager payroll-`Invoice` read** rights: MUST **not** read amount-bearing ledger rows where **`LegalEntity.Type` is `Employee` or `Executive`** on any applicable account leg (same **either-leg** rule as below). **No** access to **`Allocation`**, **`Accruals`**, **`InternalCost`**, or arbitrary **`Journal`** ledger evidence except as **FR41** allows for **`employee`**.

2. **Line manager** — In addition to baseline: MAY **read subordinates’ payroll-related recurring `Invoice` rows** and **linked `Transaction` rows** tied to those invoices (as **Architecture** / schema story defines) for **all subordinates** in the reporting hierarchy (via **`Employee` → `Manager`** — **FR22**). **`BankStatement`**: **no** read — **FR40.1**. **`Journal`**: unchanged from **FR41** (Phase 1 default **none** for line manager unless extended). **Does not** grant org-wide ledger read; **does not** grant **Executive**-ledger (`LegalEntity.Type = 'Executive'`) visibility unless the same user is **Finance** or **HR**.

3. **HR Manager** — In addition to tier-1 rules for *non-HR* paths: MAY read **Employee-ledger** financial rows on **`Account`**, **`Transaction`**, and **`Invoice`** where **at least one** leg is **`LegalEntity.Type = 'Employee'`** and **neither** leg is **`Executive`** (**FR33**). **`BankStatement`**: **no** read — **FR40.1**. MUST **not** read **Executive**-ledger rows. **`Journal`**: read only **`JournalLink.collection` ∈ {`Transaction`, `Invoice`, `Employee`}** with filters consistent with **FR33** / **FR41**.

4. **Finance Manager** — Full **CRUD** on all ledger collections and Finance-only tables; **no** `LegalEntity.Type` read restriction.

**Cross-cutting:** Visibility of **amount-bearing financial** data for tiers 1–3 SHALL depend **only** on **`LegalEntity.Type`** of the **`LegalEntity`** linked from the **`Account`**(s) involved **plus** the tier rules above. **Payroll** is expressed as **`Invoice`** rows (typically **`Recurrence` > 0** — recurring per **FR15**) on those accounts — **not** a parallel table or amount field outside the ledger. **HR-facing wording** for what staff call **“salary”** is defined in **§4.4**. **`Employee.DefaultProjectId`** and **`Employee.ProfitCenter`** SHALL NOT drive ledger visibility. **`LegalEntity.Type`** values: **`Employee`**, **`Executive`**, **`Internal`**, **`Client`**, **`Partner`**, **`Supplier`** (books-of-record classification; not Directus role names).

**FR40.1 — `BankStatement` Finance-only (Phase 1):** **`BankStatement`** SHALL be **readable and writable only** by users in the **Finance Manager** tier (**FR40** tier 4 — Directus permissions **and** PostgreSQL RLS / **`UserToRole`** alignment). **`hr-manager`**, **`line-manager`**, **`employee`**, and **`executive`** SHALL **not** receive **`BankStatement`** **SELECT** or mutations. **HR payroll assurance** SHALL rely on **`Invoice`**, **`Transaction`**, and permitted **`Journal`** only — not raw bank lines. **Dual-layer enforcement** is mandatory (**NFR1**, **NFR13**). **Architecture** reference: **ADR-16**. A future PRD change **MAY** introduce a **narrow** HR read scope for **`BankStatement`**; until then, **FR40.1** supersedes any prior wording that implied HR or line-manager read on this collection.

**Either-leg rule:** For **`Transaction`**, **`Invoice`**, and **`Allocation`**, evaluate **both** `OriginAccount` and `DestinationAccount`; for **`Account`**, the single linked account. **`BankStatement`** row visibility is **not** derived from Employee-ledger either-leg rules — use **FR40.1** only. **Implementation note:** PostgreSQL `policy_*_public_read` policies that only test **one** FK leg on **`Transaction`/`Invoice`/`Allocation`** MUST be updated to match.

**`executive` Directus role:** Same tier as **(1)** unless the user is also **`line-manager`** (**2**), **`hr-manager`** (**3**), or **`finance-manager`** (**4**) — **no** standalone Executive super-user path.

**FR41**: **`Accruals`**: **`finance-manager`** **only** — full **CRUD** and **read**; **no** other role **SHALL** have read or write (**HR excluded** — see **FR17**). **`Allocation`** and **`InternalCost`**: **`finance-manager`** holds **create / update / delete**; **`hr-manager`**, **`line-manager`**, **`employee`**, and **`executive`** **no** read/write unless a future PRD explicitly extends (**`executive`** = **`employee`** here).

**`Journal`** (exception — **FR12**): **`finance-manager`** **create / read / update / delete** (full evidence stewardship). **`employee`** / **`executive`**: **create** and **read** **`Journal`** evidence where **`JournalLink.collection` ∈ {`Transaction`, `Invoice`}** and the referenced row is **attributed to** the authenticated user via **FR28** / **Architecture** (replacing legacy **`Expense`** + **`JournalLink.collection = 'Expense'`**); **and** **`JournalLink.collection = 'Employee'`** for **own** **`Employee`** record evidence, unless extended. **`hr-manager`**: **read** **`Journal`** where **`JournalLink.collection` ∈ {`Transaction`, `Invoice`, `Employee`}** **with** item filters consistent with **FR33**. **`line-manager`**: **no** **`Journal`** access **unless** extended (e.g. subordinate evidence — optional story); **Phase 1** default **none**. **`CurrencyExchange`** remains **excluded** from this rule — see **FR19**. **Effective visibility:** **URLs and file access** MUST satisfy **parent read** per **FR12**.

---

## 6. Non-Functional Requirements

**NFR1 — Security (Dual-Layer Zero-Trust)**: RBAC and data isolation logic MUST be enforced at **two independent layers**: (1) **Directus API layer** — collection-level and item-level permissions per role; (2) **PostgreSQL RLS** — row-level security policies on sensitive tables, driven by the authenticated user's email passed via `SET LOCAL app.user_email`. **Neither layer alone is sufficient.** Directus RBAC governs UX (which collections/fields appear) and API-level access; PostgreSQL RLS is the database-level backstop that prevents unauthorized row access even if Directus is misconfigured or bypassed. No security rule may depend solely on frontend filtering or UI hiding. **`Journal`** attachments: **`ResourceURL`** and **`document_file`** / asset URLs MUST **inherit** the referenced parent’s visibility — see **FR12** (no orphan links that leak evidence).

**NFR2 — Secret Management**: Database credentials (`DB_PASSWORD`, `SECRET`, `KEY`) MUST be stored exclusively in local `.env` files, never in version-controlled files or scripts. Production credentials MUST be injected via Google Cloud Secret Manager into Cloud Run environment at runtime.

**NFR3 — Licensing (Zero Variable Cost)**: The solution MUST incur zero per-user licensing fees. Directus OSS self-hosted MUST remain within its BSL license free tier. All tooling selections must pass a Licensing Lever Analysis per `docs/governance.md`.

**NFR4 — Data Integrity**: BankStatement deduplication MUST enforce **atomic-line** uniqueness at the API layer before any database write (**FR7**/**FR8**). **Dedup key:** deterministic composite including **`AccountID`**, **`Date`**, **`Amount`**, merged **description / narrative** text, and **`BankTransactionID`** when present — **not** `AccountID + BankTransactionID` alone. **Multiple rows with the same `AccountID` and `BankTransactionID` are allowed** when **`Amount`** and/or narrative differ. **`BankStatement` MAY be created with `Transaction` NULL** (**FR6**). Updates that only change **`Transaction`** (reconciliation) MUST NOT re-run deduplication unless Architecture explicitly requires it. **SHALL NOT** add a DB unique constraint on **`(Account, BankTransactionID)`** alone if it would forbid legitimate multi-line bank references.

**NFR5 — Performance**: Directus Insights dashboards (P&L, Completeness Score) MUST return aggregated results within **5 seconds** for a baseline of **up to 10,000 `Transaction` rows per calendar month** per ProfitCenter slice, as measured by end-to-end request time from the Directus API or Insights panel load. Queries over date-partitioned columns (`Date`, `Month`, `Year`) SHOULD use indexed reads.

**NFR6 — Containerization**: All backend services MUST be defined in `docker-compose.yml`. The local development environment MUST be fully reproducible with a single `docker compose up` command after `.env` configuration.

**NFR7 — AI Compatibility (Vibecoding Safety)**: All schema modifications and data operations during AI-assisted development MUST go through the Directus API. No AI agent may issue direct SQL DDL/DML commands against `bidstruct4`. The Directus Admin UI is the designated management interface.

**NFR8 — Audit Trail**: Directus Activity and Revisions MUST be enabled for all Finance-domain collections (`Account`, `Transaction`, `Invoice`, `BankStatement`, `Allocation`, `Accruals`, `Journal`, **`InternalCost`** (project-to-project allocations per **FR30** / **FR43**), **`CurrencyExchange`** — manual corrections per **FR19**) **and** for `EmployeePersonalInfo` (PII changes). The audit log MUST be accessible to the Finance Manager role for finance collections; **`executive`** Activity access = **`employee`** unless extended (**FR21**). HR-accessible audit for `EmployeePersonalInfo` MUST follow the same Directus Activity/Revisions mechanism.

**NFR9 — Deployment Compatibility**: The Directus Docker image MUST be deployable to Google Cloud Run. Database connectivity MUST use Cloud SQL Auth Proxy sidecar pattern for both local development and production environments.

**NFR10 — Schema Portability**: All Directus collection configurations, field metadata, and permission policies MUST be exportable as a `schema.json` snapshot and committed to version control. This enables reproducible schema migrations.

**NFR11 — Employee PII**: Fields `cnic`, `ntn`, and other government identifiers on `EmployeePersonalInfo` MUST be treated as **sensitive**: Directus field permissions and/or display templates SHOULD restrict visibility to HR Manager and the owning Employee except where Finance/legal workflow explicitly requires access. **Data retention and right-to-erasure policies** for ex-employees are **deferred to Phase 2** unless compliance mandates earlier — document the chosen policy when implemented.

**NFR14 — Data administration presentation:** The **internal data administration surface** (Phase 1: Directus; see Architecture **ADR-01**) MUST comply with **`data-admin-surface-requirements.md`** — human-readable references in **lists, detail views, and pickers**; no raw surrogate keys as the default operator-visible value (**R1–R3** in that document). **Do not** duplicate the full contract here. **Directus-specific** field metadata, scripts, and **ADR-14 / §4.4** binding are in the Architecture document and **`data-admin-surface-requirements.md`** §3.

**NFR13 — PostgreSQL RLS defense-in-depth**: The **12** RLS-protected tables in `bidstruct4` (`Account`, `Accruals`, `Allocation`, `BankStatement`, `Invoice`, `Journal`, `Transaction`, `Employee`, `LegalEntity`, `Role`, `RolePermissions`, `UserToRole`) MUST retain PostgreSQL RLS + **`FORCE ROW LEVEL SECURITY`** where Architecture **ADR-13** requires it. For **`Transaction`**, **`Invoice`**, and **`Allocation`**, RLS **read** rules MUST implement **FR40**’s **four tiers**: **Finance** full read; **HR** Employee-ledger only, no Executive leg; **line manager** **subordinate payroll-`Invoice`** (and related row) rules as Architecture defines; **baseline** — deny rows touching **`LegalEntity.Type IN ('Employee','Executive')`** on any applicable leg unless a higher tier applies. There is **no** separate **`executive`** bypass — **`executive`** maps to **baseline** (or **line-manager** if dual-assigned). Align legacy policies that only checked **one** FK leg with the **either-leg** rule. **Directus** MUST connect as **`sterile_dev`** (not covered by `policy_owner_access_*`); **`bs4_dev`** = break-glass only. **Directus extension:** `SET LOCAL ROLE` + `SET LOCAL app.user_email` on **`items.*`** for **every** authenticated user (**including** Administrator). Tables without sensitive data (`Currency`, **`CurrencyExchange`**, `ProfitCenter`, `Project`, etc.) MAY drop RLS per Architecture. See **ADR-13** and **`setup-sterile-dev.sql`**.

**NFR12 — Production identity (external IdP)**: For the **deployed / final product** environment, **all interactive user authentication** to Directus (Admin UI and, when built, any SPA using user-delegated tokens) **MUST** use the **OIDC/OAuth identity provider** specified in **`identity-provider.md`** (vendor, endpoints, and domain rules are maintained **only** there; **Story 1.8** owns implementation). **Exceptions (non-production only):** local `docker compose` development, emergency break-glass admin, or automated service accounts **MAY** use other Directus auth mechanisms; these exceptions MUST be documented and MUST NOT be the default for production users. **Provisioning note:** Directus `directus_users` records and role assignment remain authoritative for **authorization** (RBAC); the IdP establishes **authentication**. **`UserToRole.User`** and PostgreSQL RLS **`app.user_email`** MUST align with the IdP’s **verified email** (same normalization as RLS policies). **Trusted-domain JIT:** Users who authenticate via the **configured trusted IdP** (e.g. Google Workspace SSO) with an IdP-**verified** email whose **domain** is listed in **`identity-provider.md`** (today: **`expertflow.com`**) MUST be able to **sign in without a prior manually created Directus user** — **Story 1.8** MUST enable **first-login user provisioning** (create/link) per that document; behavior for **non-allowlisted** domains MUST match **`identity-provider.md`**. Directus SHOULD **link or create** users by verified email where supported; this requirement **extends** that to **mandatory** JIT for allowlisted corporate domains.

---

## 7. Data Model Reference

Full field lists, relationship types, nullable annotations, and Directus mapping notes for all 29 in-scope collections are maintained in the **Architecture document** (`architecture-BMADMonorepoEFInternalTools-2026-03-15.md`, §4 Relationship Mapping). **Operator presentation of references (CMS-agnostic)** is specified only in **`data-admin-surface-requirements.md`** (PRD **NFR14**). **Directus implementation** of that contract: Architecture **§4.4** and **ADR-14**. The Architecture document is the single source of truth for schema detail; this PRD defers to it for structure and to **`data-admin-surface-requirements.md`** for cross-cutting admin UX rules. The in-scope collection names are listed in §2.1 (Scope) above.

**Identity provider (vendor, endpoints, migration):** single source of truth is **`identity-provider.md`** (see NFR12, Story 1.8).

---

## 8. Success Metrics & Acceptance Criteria


| Metric                                                                    | Target                                                                                        |
| ------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| All 42 tables registered as Directus collections                          | 100% coverage                                                                                 |
| All defined FK relationships navigable in Directus Admin                  | 100% of schema FKs                                                                            |
| Reference fields in the data admin UI show human-readable labels (not raw PKs) | **100%** per **`data-admin-surface-requirements.md`** / **NFR14**; Directus binding per **ADR-14** |
| Finance Manager can import BankStatement CSV and duplicates are rejected  | Zero duplicates pass                                                                          |
| BankStatement import allows unreconciled rows                             | Rows with `Transaction = NULL` accepted at import; reconciliation maps to `Transaction` (**FR6**) |
| BankStatement reconciliation 0–2 rule enforced                            | Rejected when linking a third `BankStatement` to a `Transaction` that already has two (**FR10**)   |
| HR Manager cannot read Executive-ledger rows (`LegalEntity.Type = 'Executive'`) or Accruals/Allocation/`InternalCost`; Journal only as scoped in FR41 | Zero unauthorized reads per FR33/FR40/FR41; `CurrencyExchange` MAY be HR-readable per FR19 |
| HR Manager can read Employee-ledger financial rows (Account/BankStatement/Transaction/Invoice) per FR33                     | Filtered lists only — Executive books invisible                                              |
| `executive` has no broader read than `employee` on sensitive collections (FR21/FR40) | Directus + RLS — no Executive super-user path |
| Line managers may read subordinate payroll **`Invoice`** rows only within FR33/FR40 rules | Manager payroll-`Invoice` visibility tested; no Executive-ledger leakage to HR |
| Directus Insights P&L dashboard loads in < 5s                             | 100% of typical monthly datasets                                                              |
| All clients (Admin, extensions, any future SPA) use Directus REST API only | Zero direct DB calls from user-facing clients                                                  |
| Production users sign in via IdP in `identity-provider.md` (NFR12, Story 1.8) | No production reliance on shared Directus passwords for end users                             |
| PostgreSQL RLS enforced on 12 sensitive tables; email passed per request  | Zero sensitive rows returned when RLS email context is missing or role unauthorized (NFR13)    |
| Full environment spins up via `docker compose up`                         | Single command, zero manual steps                                                             |
| All collection schema exported as versioned `schema.json`                 | Present in repo root                                                                          |


---

### 5.16 CRM & Interaction History (HubSpot Integration)

**FR50 (Gmail Sync Hook):** The system SHALL implement a Directus backend extension (hook) to sync Gmail interactions into the **`Journal`** collection.
- Each email (incoming/outgoing) SHALL be stored as a **`Journal`** entry with `JournalLink.collection` set to `Contact` or `Company`.
- The `` SHALL be set to `Email`.
- Privacy: Emails SHALL inherit the visibility/RLS of the parent **`Contact`** or **`Company`**.

**FR51 (Attachment Storage & GDrive Routing):** The system SHALL extract email attachments and store them in Google Drive.
- **Root Folder Discovery:** The system SHALL resolve the target folder by following the chain: **`Contact`** -> **`Company`** -> **`LegalEntity.DocumentFolder`**.
- If a contact is not linked to a company, or the company does not have a legal entity with a defined `DocumentFolder`, the system SHALL fallback to a "Global CRM Inbox" folder defined in environment variables.
- **Reference Persistence:** A **`Journal`** entry SHALL be created for each attachment, referencing the parent `Contact`/`Company` and providing the `ResourceURL` to the GDrive file.

**FR52 (HubSpot-style Activity Timeline):** The system SHALL implement a custom Directus Interface or Module that renders **`Journal`** entries (where `` is `Email` or `Interaction`) as a chronological timeline.
- The UI MUST mimic HubSpot’s interaction history (vibrant icons, threaded views, attachment previews).
- Interaction types SHALL include: Email, Manual Call Log, Meeting Note, and System Notification.

---

## 6. Non-Functional Requirements

---

**NFR15 — CRM Interaction Privacy:** Journal entries created via Gmail sync MUST strictly follow the RLS of the parent `Contact` or `Company`. If a user is restricted from seeing a `Contact` record, they MUST NOT be able to view synced emails for that contact.

---

## 8. Success Metrics & Acceptance Criteria

---

| Metric                                                                    | Target                                                                                        |
| ------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| HubSpot-style Timeline renders Journal interactions      | Matches HubSpot UI (Image 2)                                                                  |
| Gmail interactions sync to Journal within 5 minutes      | 95% of emails synced correctly                                                                |
| Attachments routed to correct GDrive `DocumentFolder`    | 100% accuracy in LegalEntity resolution                                                       |

---

## 9. Open Questions & Assumptions

---

| A13 | Interaction Sync Frequency: The system will use a polling mechanism (5-minute intervals) for Gmail sync in Phase 1 to avoid complex Webhook/Push Notification setups. | Andreas | TBD |
| A14 | Company Resolution: The `Company` collection is currently a stub. Phase 1 assumes manual linking or data migration of existing company profiles. | Andreas | TBD |



