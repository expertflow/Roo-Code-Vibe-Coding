---
stepsCompleted: [1, 2, 3, 4]
inputDocuments:
  - _bmad-output/planning-artifacts/prd-ExpertflowInternalERP-2026-03-16.md
  - _bmad-output/planning-artifacts/identity-provider.md
  - _bmad-output/planning-artifacts/data-admin-surface-requirements.md
  - _bmad-output/planning-artifacts/architecture-BMADMonorepoEFInternalTools-2026-03-15.md
  - projects/internal-erp/vision.md
  - docs/governance.md
  - schema_dump_final.json
project_name: 'ExpertflowInternalERP'
user_name: 'Andreas'
date: '2026-03-16'
---

# Expertflow Internal ERP — Epic & Story Breakdown

## Overview

This document decomposes all Phase 1 requirements for the Expertflow Internal ERP into implementable epics and stories. Each epic delivers standalone user value and enables subsequent epics. Stories are sized for single dev-agent completion. The Directus backend runs as a Docker container on Google Cloud Run, connected to `bidstruct4` via Cloud SQL Auth Proxy.

### Implementation sequencing (deliberate PM decision — updated 2026-03-17)

**Chosen delivery order (PM — security-led 2026-03-17):** **Epic 1 security cluster first:** **1-9** (register `Role` / `RolePermissions` / `UserToRole`) → **1-10** (Directus **RLS request-context** extension, **NFR13** / **ADR-13**) → **1-8** (Google Workspace SSO + **`@expertflow.com` JIT** per **`identity-provider.md`**) → **1-5** (FKs), **1-6** (audit), **1-7** (snapshot) → **Epic 2** (Directus roles + permissions + nav — **RLS + Directus alignment**) → **Epic 3** (ledger/bank — may overlap early demos with Admin-only) → **Epic 6** (reporting) → **Epic 1 Story 1.4** (HR ops + CPQ hide) → **Epic 4** → **Epic 5**. **Epic 7** deferred — PRD §5.14.

| Label | Meaning |
|--------|--------|
| **Security wave (highest)** | **1-9** exposes RBAC tables in Directus; **1-10** sets `SET LOCAL ROLE <RLS_SESSION_ROLE>` (default **`directus_rls_subject`**) + `SET LOCAL app.user_email = …` on user API requests so PostgreSQL RLS policies evaluate correctly (**NFR13**); **1-8** delivers **Google SSO** + trusted-domain JIT for **`expertflow.com`**. **Epic 2** then maps **`directus_roles`** + collection permissions to personas. |
| **PENDING — RLS vs Directus** | **End-to-end proof** that **authenticated** users (SSO or local), **including Directus Administrator**, see **row sets** matching **PostgreSQL RLS** + **`UserToRole`** for their email — aligned with **Directus RBAC** where both apply — is **NOT YET VERIFIED** until **1-10** + **1-8** + **Epic 2** partial config exist. Track in **`1-10-directus-rls-user-context-extension.md`**. If the extension is missing or **`RLS_USER_CONTEXT_ENABLED=false`**, checks may look “OK” in Directus while the DB still uses **owner-access**. |
| **Story 1.4 — backlog deferral (PM)** | **HR ops** collections + **hiding** CPQ/CRM/ticket tables + `TestDebug` only — **`Role` / `RolePermissions` / `UserToRole` are Story 1-9**, not 1-4. **Lowest** Phase 1 value for the hidden CPQ domain. Ordered **after** Epic 6 in `sprint-status.yaml`. |
| **Financial reporting (PM priority)** | After **1-5** + **Epic 3** data path: **Epic 6** (**6-1**, **6-2**, **6-3** cash flow). |
| **Epic 2 — RBAC + RLS alignment (now before Epic 3 in sprint keys)** | Runs immediately **after** **1-9 / 1-10 / 1-8** (and baseline schema **1-5–1-7**) so **non-Admin** behavior can be validated. **PENDING:** full non-Admin RLS matrix until extension + SSO + **`UserToRole`** data exist. |
| **Epic 3 — ledger / bank** | Follows **Epic 2** in **`sprint-status.yaml`** order for **security-first** PM priority; **Administrator** demos during overlap are OK. **FR11** / **FR31–FR41** fully satisfied only when Epic 2 + RLS verification complete. |
| **Employee UX — Directus-only (2026-03-17)** | Phase 1 **does not** add Lovable or a separate SPA. Employee self-service is **Directus Admin** (+ optional extensions). **Epic 7** / **FR35–FR39** are **deferred** (PRD §5.14). |

**Minimum Epic 1 before Epic 3 bank work:** financial collections (**1-2**) + FK wiring (**1-5**). **Security-critical path:** **1-9 → 1-10 → 1-8** before trusting **non-Admin** RLS behavior. **Story 1-4** is **not** on the critical path for bank import, cash-flow reporting, or **`Role*`** (those are **1-9**).

---

## Requirements Inventory

### Functional Requirements

FR1: Directus v11 runs as a Docker container on Google Cloud, connected to `bidstruct4` PostgreSQL via Cloud SQL Auth Proxy. Local dev uses same image via `docker compose`.

FR2: All 42 tables from `schema_dump_final.json` are registered as Directus collections with field metadata, labels, and display templates. Reference presentation in the data admin UI per **`data-admin-surface-requirements.md`** (**NFR14**).

FR3: All FK relationships are configured as Directus relational fields (M2O, O2M, M2M) navigable in Admin UI.

FR4: Directus REST API is the sole communication layer between all clients (Admin, extensions; optional future SPA) and database.

FR5: Directus Activity and Revisions logging enabled for all Finance-domain collections (see NFR8 for `EmployeePersonalInfo` extension).

FR6: Bank transactions importable into `BankStatement` via Admin UI; **`Transaction` FK MAY be NULL** until reconciliation; **FR9**/**FR10** map each line to a `Transaction`; optional **`Allocation`** to **`Invoice`** (**FR16**).

FR7: Zero-duplication enforced on `BankStatement` via composite uniqueness: `Account + BankTransactionID`. Duplicates rejected with descriptive error.

FR8: Fallback deduplication hash from `Date`, `Amount`, `Account`, and **all populated description fields** when `BankTransactionID` is unavailable (**FR46.1**).

FR46: **`BankStatement`** **up to four** description columns; **per-bank** CSV/spreadsheet **normalization**; **dedup-before-insert** for batch; **review CSV + explicit approve** before persist for **scripted** imports (**NFR2**, **NFR7**).

FR9: Finance Manager **associates** each `BankStatement` with a `Transaction` via match existing, spawn from `Invoice`, or create new (±3 business days / ±5% matcher unchanged).

FR10: **`BankStatement.Transaction` nullable** at import; **reconciliation** assigns FK; a **`Transaction`** may have **0–2** linked **`BankStatement`** rows; **no** `Transaction.BankStatementId` FK; third link attempt rejected.

FR11: `Transaction` Finance CRUD (canonical: `OriginAccount`, `DestinationAccount`, `Amount`, `Currency`, `Description`, `Date`, `Project`); no per-row **`image`** / legacy **`expense_id`** — evidence via **`Journal`** (**FR12**); **`executive`** = **`employee`** read (**FR21**).

FR12: **`Journal`** = canonical **per-object** evidence; **many `Journal` rows** MAY share the same **`JournalLink.collection` + `JournalLink.item`** (polymorphic 1-to-many attachments); **`LegalEntity.DocumentFolder`** = canonical **default org storage** (folder URL); URLs/files **inherit parent visibility** (no leak via Journal/asset id).

FR13: `Journal` does not enforce exclusive FK to any single table; `JournalLink.collection` defines entity type.

FR14: Completeness Score widget(s): **Transaction** (+ **Invoice** SHOULD) with ≥1 linked `Journal`.

FR15: `Invoice` AR/AP — no **`Invoice.Transaction`** FK; **no** **`Invoice.employee_id`**; **`RecurMonths`** only (**FR44** derives next issue from **`RecurMonths` + `DueDate`** — **no** persisted **`NextIssueDate`**); attachments only via **`Journal`**; Finance CRUD; **`executive`** = **`employee`** read (**FR21**).

FR44: Recurring invoices — daily job spawns next instance based on **`DueDate`** and **`RecurMonths`** (**FR44** Phase 1 **required**).

FR16: Full CRUD for `Allocation` available exclusively to Finance Manager (**`executive`** no extra read — **FR21**).

FR45: **BankStatement completion queue** + **invoice ±10% / ±4-month** suggestions (Phase 1; AI refinement later) + **optional `Allocation`** + **counterparty fallbacks** — Finance UI (**FR6**/**FR9**/**FR16**).

FR17: `Accruals` **Finance-only** (no read/write for HR, line manager, employee, executive) — **FR17**/**FR41**.

FR18: `Currency` exposed as reference lookup; Finance Manager editable.

FR19: `CurrencyExchange` — Finance write + manual correction; optional HR / employee / **`executive`** read (non-sensitive).

FR20: Directus Insights P&L dashboard(s); **no** RLS bypass — same row visibility as API (**FR20**).

FR47: **Cash flow** — **past `Transaction` + forward `Invoice`**; **FR47.9** defaults **24m**/**monthly**, **user-tunable** spans/grain where Insights (or **successor**) allows; **two** series; **no `BankStatement`**; **PC owner** = Phase 2+.

FR21: **`executive`** = **`employee`** for sensitive reads — **no** special RLS; **no** write on Finance ledger or HR ops unless delegated.

FR22: HR Manager has full CRUD on **all** `Employee` records; **`Manager`** M2O → `Employee` (stored id; **human-readable** picker label = manager **`email`** + name — **NFR14**). `DefaultProjectId` is time/cost default only (not RBAC). `Employee.ProfitCenter` hidden from product. FR40: financial masking uses `LegalEntity.Type` via `Account`, not Employee fields.

FR23: HR Manager and Employee (own record) can manage `EmployeePersonalInfo`.

FR24: `Seniority`, `Designation`, `department` exposed as HR Manager CRUD reference tables.

FR24.1: **`Seniority.DayRate`** (or DB-mapped column) for **FR43** cost = hours × rate.

FR25: `TimeEntry` — `Description`, `StartDateTime`, `EndDateTime`, `Employee`, `Project` only; **no** persisted **`HoursWorked`** (derived); **no** required **`Task`**; Employees own records; Line Managers read team; HR Manager reads all.

FR26: `Leaves` workflow: Employees submit; Line Managers approve/reject; HR Manager full CRUD.

FR27: `Task` collection: Employees update own status; Line Managers full CRUD team tasks; HR Manager reads all.

FR28: **Employee spend** — Directus **Flow** / extension: **immediate** **`Transaction`** (company card, deduped) or **`Invoice`** (personal); **`Project`** default **`Employee.DefaultProjectId`**; **no** canonical **`Expense`** collection.

FR29: Receipt files via **`Journal.document_file`** with **`JournalLink.collection`** ∈ **`Transaction`/`Invoice`** — Directus Files API (**FR12**).

FR30: `InternalCost` CRUD for Finance Manager — **project-to-project** internal allocation (no `TimeEntryId`; monthly **`TimeEntry`** aggregation **FR43**).

FR31: Five Directus roles created: `finance-manager`, `executive`, `hr-manager`, `line-manager`, `employee`.

FR32: Collection-level permissions configured per role matching the Access Control Matrix.

FR33: **Four RLS tiers** — baseline employee, **line manager** (subordinate **payroll recurring `Invoice`** + linked rows), HR (employee-ledger, no Executive leg), Finance (all); **`executive`** = baseline unless dual role.

FR34: *(superseded by FR41 grouping — see PRD.)* Use FR41 for Finance-write collections.

FR40: **Four tiers** (PRD): Finance / HR / line-manager comp. / baseline — **no** **`executive`** super-user path.

FR41: **Journal** — Finance full CRUD; Employee/**`executive`** evidence on **own FR28** **`Transaction`/`Invoice`** + **`Employee`**; HR **`Transaction`/`Invoice`/`Employee`** journals per **FR33**; **`Accruals` Finance-only (no HR read)**; **`Allocation`**/**`InternalCost`** Finance CRUD for others; **CurrencyExchange** per **FR19**.

FR35 *(deferred — PRD §5.14)*: Optional dedicated SPA scaffold; Directus REST API + per-user token (was Lovable).

FR36 *(deferred)*: SPA time logging — Active Projects ordered by **user-assigned** ProfitCenter (`directus_users`), not `Employee.ProfitCenter`, then Global, by recent TimeEntry.

FR37 *(deferred)*: Daily Confirmation sparkline for previous day's time entries.

FR38 *(deferred)*: SPA leave form + balance display for `Leaves`.

FR39 *(deferred)*: SPA expense form + camera/file-upload for receipts.

### Non-Functional Requirements

NFR1: Dual-layer Zero-Trust: Directus RBAC (API/UX primary) + PostgreSQL RLS (database backstop). No security rule relies solely on frontend filtering.

NFR2: DB credentials stored exclusively in local `.env` files. Production credentials injected via Google Cloud Secret Manager.

NFR3: Zero per-user licensing fees. Directus OSS self-hosted within BSL free tier.

NFR4: BankStatement deduplication uses collision-resistant composite hash (`AccountID + BankTransactionID`). Rejected at API layer before DB write.

NFR5: Directus Insights dashboards return aggregated results within 5s for up to ~10k `Transaction` rows/month per ProfitCenter slice (baseline per PRD).

NFR6: All backend services defined in `docker-compose.yml`. Full local environment reproducible with single `docker compose up`.

NFR7: No proprietary vendor features. All schema definitions version-controlled and portable.

NFR8: Directus Activity/Revisions enabled for Finance collections and `EmployeePersonalInfo`. Audit accessible per PRD roles.

NFR9: All operations during AI-assisted development go through Directus API. No direct SQL DDL/DML from AI sessions.

NFR10: All Directus collection configs, field metadata, and permissions exportable as `schema.json` snapshot committed to VCS.

NFR11: Employee PII (`cnic`, `ntn`, etc.) sensitivity, display restrictions; retention/erasure deferred Phase 2 unless compliance requires earlier.

NFR12: Production user authentication via **external OIDC/OAuth IdP** per **`identity-provider.md`** (Story **1.8**); **trusted-domain JIT SSO** (e.g. `@expertflow.com`) without manual Directus user creation per that file; local dev / break-glass exempt per PRD.

NFR13: PostgreSQL RLS defense-in-depth on 12 sensitive tables; Directus extension passes email via `SET LOCAL ROLE <RLS_SESSION_ROLE>` + `SET LOCAL app.user_email` (default role **`directus_rls_subject`**); 10 non-sensitive tables may drop RLS. Architecture ADR-13.

NFR14: Data admin surface MUST satisfy **`data-admin-surface-requirements.md`**; Phase 1 Directus binding per Architecture **ADR-14 / §4.4** (do not restate full rules here).

### Additional Requirements (Architecture)

- Directus runs as Docker container deployed to Google Cloud Run (ADR-01, ADR-10)
- **Production** staff login: external IdP per **`identity-provider.md`** → Directus OIDC/OAuth (ADR-12, NFR12, Story **1.8**)
- Cloud SQL Auth Proxy used for all DB connectivity — local and production (ADR-02)
- `.env.example` committed (no secrets); actual `.env` gitignored (ADR-03)
- Directus Schema Snapshot (`schema.json`) version-controlled in repo root (ADR-04)
- BankStatement two-step import (`Transaction` null) + reconciliation; dedup + 0–2 cap Hooks in `extensions/hooks/bank-statement-dedup/` and `bank-statement-limit/` (ADR-05)
- Journal polymorphic linking implemented as Directus Custom Interface extension (ADR-06)
- All security rules at Directus API layer; no frontend-only security (ADR-07)
- **ADR-08 revised:** **`executive`** = **`employee`** for item-level scope; Insights UX filters only (**FR20**)
- **Dual-layer security:** Directus RBAC + PostgreSQL RLS defense-in-depth on 12 sensitive tables (ADR-07 revised, ADR-13)
- **Human-readable references (CMS-agnostic):** **`data-admin-surface-requirements.md`**; Directus binding **ADR-14** + `projects/internal-erp/directus/scripts/` (PRD **NFR14**)
- **Phase 1:** Admin + extensions use Directus API only; optional future SPA same rule (ADR-09)
- Monorepo layout: `projects/internal-erp/directus/` required; `projects/internal-erp/lovable-spa/` **optional / deferred**

### UX Design Requirements

No formal UX specification document exists for Phase 1. **All roles**, including **Employee**, use the **Directus Admin UI** (and extensions as needed) for Phase 1 speed (PRD §5.13). **FR35–FR39** (dedicated SPA) are **deferred** — see Epic 7.

---

### FR Coverage Map

| FR | Epic | Brief Description |
|---|---|---|
| FR1 | Epic 1 | Docker/Cloud Run/Cloud SQL Proxy setup |
| FR2 | Epic 1 | Register all 42 collections with field metadata (**NFR14** / **`data-admin-surface-requirements.md`**) |
| FR3 | Epic 1 | Configure FK relationships as Directus relational fields |
| FR4 | Epic 1 | REST API as sole communication layer |
| FR5 | Epic 1 | Activity/Revisions logging for Finance collections |
| FR6 | Epic 3 | BankStatement import via Admin UI |
| FR46 | Epic 3 | Multi-bank CSV/spreadsheet normalization; up to four description fields; scripted review-then-import (**NFR2**, **NFR7**) |
| FR7 | Epic 3 | Deduplication via AccountID + BankTransactionID |
| FR8 | Epic 3 | Fallback hash deduplication |
| FR9 | Epic 3 | Transaction mapping from BankStatement metadata |
| FR10 | Epic 3 | Nullable `BankStatement.Transaction` at import; reconcile + 0–2 BankStatements per Transaction |
| FR11 | Epic 3 | Transaction CRUD for Finance Manager |
| FR12 | Epic 3 + Epic 1 | Journal per-object evidence (**Story 3.3**); **`LegalEntity.DocumentFolder`** (**Story 1.3**) |
| FR13 | Epic 3 | Journal non-exclusive FK design |
| FR14 | Epic 6 | Completeness Score Insights widget |
| FR47 | Epic 6 **Story 6.3** | Cash flow — **FR47.9** defaults + user params / grain; Insights or successor; **Architecture** §10.5–10.7; `6-3-*.md` |
| FR15 / FR44 | Epic 3 | Invoice AR/AP + **Phase 1** recurrence job (**FR44**); evidence via **Journal** only |
| FR16 | Epic 3 | Allocation CRUD for Finance Manager |
| FR17 | Epic 3 | Accruals Finance CRUD only (**FR21**) |
| FR18 | Epic 3 | Currency reference lookup |
| FR19 | Epic 3 | CurrencyExchange (Finance write; optional HR / employee / **`executive`** read) |
| FR20 | Epic 6 | Insights — **no** RLS bypass |
| FR21 | Epic 2 | **`executive`** = **`employee`** on sensitive data; no write on Finance/HR ops unless delegated |
| FR22 | Epic 4 | HR Manager Employee CRUD (full roster; DefaultProject = time default only) |
| FR40 | Epic 2 + Arch | **Four RLS tiers**; line-manager subordinate **payroll `Invoice`**; **no** **`executive`** bypass |
| FR41 | Epic 2 | **Journal** nuanced RBAC + Allocation/Accruals/InternalCost; **CurrencyExchange** per **FR19** |
| FR23 | Epic 4 | EmployeePersonalInfo management |
| FR24 | Epic 4 | Seniority/Designation/department reference tables |
| FR24.1 | Epic 4 / 5 | **`Seniority.DayRate`** — **FR43** internal cost rate |
| FR25 | Epic 5 | TimeEntry logging and visibility |
| FR26 | Epic 5 | Leaves request and approval workflow |
| FR27 | Epic 5 | Task assignment and status tracking |
| FR28 | Epic 5 | Employee spend → **`Transaction`/`Invoice`** (Directus Flow); dedup; **no `Expense`** |
| FR29 | Epic 5 | Receipt **`Journal`** on **`Transaction`/`Invoice`** (Files API) |
| FR30 / FR43 | Epic 4 | InternalCost project-to-project; future monthly `TimeEntry` roll-up |
| FR31 | Epic 2 | Create 5 Directus roles |
| FR32 | Epic 2 | Collection-level permissions per role |
| FR33 | Epic 2 | Item-level permission filters |
| FR34 | Epic 2 | *(See PRD — navigation/UX; permissions per FR32/FR41.)* |
| FR35–FR39 | **Epic 7 (DEFERRED)** | Optional dedicated SPA (e.g. Lovable); **Phase 1** employee flows via **Epic 5** (Directus) + **Epic 2** (`employee` **app access** per Architecture) |

### NFR → canonical spec (avoid duplicating prose in stories)

| NFR | Primary epic | Canonical BMAD document |
|-----|----------------|-------------------------|
| **NFR14** | Epic 1 (foundation) + regression on metadata changes | **`data-admin-surface-requirements.md`** |
| **NFR13** | Epic 1 **Story 1-10** (RLS request-context extension) + verification matrix (non-Admin **PENDING** until 1-10 + 1-8 + Epic 2) | Architecture **ADR-13**, PRD **NFR13** |

---

## Epic List

### Epic 1: Directus Platform Foundation
Admins can access a running, secured Directus instance on Google Cloud (Docker/Cloud Run) connected to the `bidstruct4` database, with all 42 collections registered, all relationships configured, and audit logging active. **Operator reference presentation** satisfies **`data-admin-surface-requirements.md`** (**PRD NFR14**); Directus binding per Architecture **ADR-14 / §4.4** and repo scripts. This is the infrastructure bedrock all other epics depend on. **PM note:** **Story 1.4** (HR ops + hiding CPQ/CRM/ticket collections; **`Role*` = Story 1.9**) is **backlog-deferred** — see *Implementation sequencing*.
**FRs covered:** FR1, FR2, FR3, FR4, FR5
**NFRs addressed:** NFR2, NFR3, NFR6, NFR7, NFR8, NFR9, NFR10, NFR11, **NFR12** (Story **1-8**, JIT `@expertflow.com` per **`identity-provider.md`**), **NFR13** (Story **1-10**; authenticated-user RLS vs Directus **PENDING** — see **`1-10` artifact**; **no** Directus Admin bypass on `items.*`), **NFR14** (**`data-admin-surface-requirements.md`**)

### Epic 2: Secure Role-Based Access Control — **[SECURITY PRIORITY — after 1-9 / 1-10 / 1-8]**
***PM update 2026-03-17:** Epic 2 is **prioritized before Epic 3** in `sprint-status.yaml` so **Directus RBAC** and **PostgreSQL RLS** can be tested with **non-Admin** users (SSO) — see *PENDING* row in *Implementation sequencing*. Prior “Epic 3 before Epic 2” override is **replaced** for this security-led track.*

Each team persona (Finance Manager, Executive, HR Manager, Line Manager, Employee) can log into Directus and sees only the collections and records relevant to their role. **RLS tiers (FR40):** **Finance** (all), **HR** (employee-ledger only, **no** Executive leg), **line manager** (subordinate **payroll recurring `Invoice`** + linked ledger rows + team ops), **baseline** (`employee` and `executive` — **same** rules). **Payroll = `Invoice` only** (BS4). **`executive`** has **no** extra privileges (**FR21**). **Insights** (**FR20**) must **not** bypass RLS. **`Journal`** per **FR41**.
**FRs covered:** FR21, FR31, FR32, FR33, FR34, FR40, FR41
**NFRs addressed:** NFR1

### Epic 3: Financial Ledger & Bank Management — **[After Epic 2 in security-led sprint]**
***PM update 2026-03-17:** Follows **Epic 2** in `sprint-status.yaml`. **FR11** and role-scoped CRUD are **fully valid only after** Epic 2; early bank demos may still use **Administrator** if needed.*

Finance Managers can import bank statements with **`Transaction` optionally NULL** until reconciliation (zero-duplication guarantees), **reconcile** each line to a `Transaction` (including a **second** bank line on an **existing** `Transaction` within the **0–2** cap), **optionally** link to **`Invoice`** via **`Allocation`**, link any document as journal evidence (including **many `Journal` rows per parent** via polymorphic `JournalLink.collection`/`JournalLink.item`), and manage currencies and exchange rates — giving them a complete, auditable financial ledger.
**FRs covered:** FR6–FR19, **FR44** (recurring invoices), **FR46** (multi-bank spreadsheet import), FR12 (Journal per-object evidence + **`LegalEntity.DocumentFolder`** default storage)
**NFRs addressed:** NFR4, NFR8 *(NFR1 deferred until Epic 2)*

### Epic 4: HR Administration & Employee Lifecycle
HR Managers can onboard and manage the **full** employee roster, maintain personal information (with PII handling per NFR11), configure organizational reference data (seniority, designation, departments), and record internal cost transfers between profit centers.
**FRs covered:** FR22, FR23, FR24, FR30
**NFRs addressed:** NFR1, NFR8, NFR11

### Epic 5: Operational HR Tracking
Employees can log time against projects, submit leave requests, and file expense claims. Line Managers can approve leaves and oversee team tasks. HR and Finance can review all operational records — completing the day-to-day HR operations loop.

**Phase 1 UX (PM 2026-03-17):** These flows run in **Directus Admin** (and extensions if added). **No separate SPA.**
**FRs covered:** FR25, FR26, FR27, FR28, FR29
**NFRs addressed:** NFR1

### Epic 6: Executive & Finance Insights Dashboards
Finance Managers can monitor audit completeness with a live Completeness Score. **Executive** Insights follow **FR20**/**FR21** (no RLS bypass; P&L may require Finance-built aggregates). **Story 6.3** implements **FR47** + **FR47.9** (**defaults** + **user parameters** where feasible; **Insights** or successor); **no** **`BankStatement`**; **two** series (**FR47.8**); legacy **Looker** doc = reference-only.
**FRs covered:** FR14, FR20, **FR47**
**NFRs addressed:** NFR5

### Epic 7: Employee Self-Service Portal — **[DEFERRED — optional SPA track]**
*Originally a **Lovable** (or similar) SPA for FR35–FR39. **PM decision (2026-03-17):** **not in Phase 1.** Employee outcomes are met via **Directus Admin + Epic 5** first; revisit this epic only if UX requires a dedicated mobile/web app.*

If implemented later: mobile-friendly SPA for smart project ordering, daily confirmation, leave and expense UX — **only** via Directus REST API (no direct DB).
**FRs covered (when/un-if built):** FR35, FR36, FR37, FR38, FR39 *(all deferred in PRD §5.14 for Phase 1)*
**NFRs addressed:** NFR1, NFR9

---

## Epic 1: Directus Platform Foundation

**Goal:** A running, production-equivalent Directus v11 Docker environment on Google Cloud with all `bidstruct4` collections registered, all relationships mapped, and audit logging active. **Reference presentation** for operators follows **`data-admin-surface-requirements.md`** (**PRD NFR14**); verify per **§3** of that document (Directus scripts today). Every subsequent epic builds on this foundation.

---

### Story 1.1: Docker Compose & Google Cloud Run Setup

As a **DevOps Engineer / Developer**,
I want a `docker-compose.yml` that runs Directus v11 locally using the same Docker image as production, with Cloud SQL Auth Proxy connectivity and all credentials externalized to `.env`,
So that the local environment is 100% identical to the Google Cloud Run production deployment and no credentials are ever committed to the repository.

**Acceptance Criteria:**

**Given** the developer has configured a local `.env` file from `.env.example` with valid `DB_*`, `SECRET`, and `KEY` values,
**When** they run `docker compose up` in `projects/internal-erp/directus/`,
**Then** Directus v11 starts successfully on `http://localhost:8055` and the admin login screen is accessible.
**And** the Directus container connects to `bidstruct4` via `host.docker.internal:5432` (Cloud SQL Auth Proxy sidecar pattern).

**Given** a developer inspects the repository,
**When** they check any committed file,
**Then** no actual passwords, SECRET values, or KEY values appear anywhere — only `.env.example` with empty placeholders.

**Given** the `.env.example` is present,
**When** a new developer copies it to `.env` and fills in credentials,
**Then** `docker compose up` succeeds with no additional manual configuration steps.

**Given** the `docker-compose.yml` defines the Directus service,
**When** the image tag is inspected,
**Then** it references `directus/directus:11` (or a pinned minor version) from the official Docker Hub registry.

**Technical Notes:**
- Create `projects/internal-erp/directus/docker-compose.yml`
- Create `projects/internal-erp/directus/.env.example` (committed, no secrets)
- Add `.env` and `uploads/` to `.gitignore`
- **Production target (ADR-10):** **Google Cloud Run** — same image; env vars from **Google Cloud Secret Manager** (PRD **NFR2**, **NFR9**).
- **Interim / colleague access (same story family, 2026-03):** **Compute Engine VM + Docker Compose** + in-compose **Cloud SQL Auth Proxy** sidecar is documented in **`projects/internal-erp/directus/docs/gcp-directus-deployment.md`** and **`docker-compose.gcp-vm.example.yml`** — parity with local image; does **not** replace Cloud Run as the long-run architecture target. Implementation artifact: **`_bmad-output/implementation-artifacts/1-1-docker-compose-google-cloud-run-setup.md`** § *Shared GCP deployment*.
- Reference ADR-02 (Cloud SQL Auth Proxy), ADR-03 (Secret Management)
- Add GCS storage adapter environment variables (`STORAGE_LOCATIONS=gcs`, `STORAGE_GCS_BUCKET`, etc.) and Secret Manager injection to properly configure Google Cloud Storage for the Files API.

---

### Story 1.2: Register Financial Core Collections

As a **Finance Manager**,
I want all financial collections (`Account`, `BankStatement`, `Transaction`, `Invoice`, `Allocation`, `Accruals`, `Journal`, `Currency`, `CurrencyExchange`) to be visible and properly labelled in the Directus Admin UI,
So that I can immediately navigate to and work with financial data without encountering raw table names or unformatted field IDs.

**Acceptance Criteria:**

**Given** I am logged in as an Administrator,
**When** I open the Directus Admin UI and navigate to Collections,
**Then** all 9 financial collections are listed with human-readable labels (e.g., `BankStatement` → "Bank Statement", `CurrencyExchange` → "Currency Exchange Rates").

**Given** I open the `Invoice` collection,
**When** I inspect the fields,
**Then** every field has a label, correct interface type (e.g., `Amount` → input-decimal, `Status` → select-dropdown, `SentDate` → datetime), and a display template of `INV-{{id}} · {{Amount}} {{Currency.CurrencyCode}}`.

**Given** I open the `Journal` collection,
**When** I inspect the `JournalLink.collection` field,
**Then** it is configured as a select-dropdown with valid options matching in-scope collection names (e.g., `Invoice`, `Transaction`, `BankStatement`, `Employee`).

**Given** I open the `Account` collection,
**When** I check the display template,
**Then** it shows `{{Name}} [{{LegalEntity.Name}}]`.

**Technical Notes:**
- Configure all 9 collections via Directus schema or Admin UI
- Field interface mapping: integer(FK) → m2o, text → input, numeric → input-decimal, date → datetime, boolean → toggle, USER-DEFINED → select-dropdown, jsonb → input-code
- **Operator reference presentation:** **`data-admin-surface-requirements.md`** (**NFR14**); Directus binding Architecture **§4.4**
- After configuration, run `directus schema snapshot ./schema.json` and commit

---

### Story 1.3: Register Organizational & HR Core Collections

As an **HR Manager** and **Administrator**,
I want all organizational and HR core collections (`LegalEntity`, `ProfitCenter`, `Project`, `CountryLocation`, `Contact`, `Company`, `Employee`, `EmployeePersonalInfo`, `Seniority`, `Designation`, `department`) visible and correctly configured in Directus,
So that I can manage employee and organizational data with intuitive field labels and correctly linked reference dropdowns.

**Acceptance Criteria:**

**Given** I am logged in as an Administrator,
**When** I navigate to the `Employee` collection,
**Then** the display template shows `{{EmployeeName}} ({{email}})` and the **`Manager`** field is a self-referential M2O back to `Employee`, with the relation **displaying the manager’s `email`** (and name) per **NFR14** (DB column may remain `ManagerId`).

**Given** I open a `Project` record,
**When** I view the `ProfitCenter` field,
**Then** it renders as an M2O dropdown listing all `ProfitCenter` records by name.

**Given** I open the `LegalEntity` collection,
**When** I inspect the `Type` field,
**Then** it is configured as a select-dropdown. The display template shows `{{Name}} ({{Type}})`.

**Given** I open the `LegalEntity` collection,
**When** I inspect the `DocumentFolder` field,
**Then** it is labeled (e.g. “Default document folder”) and uses an interface suitable for a **URL** (e.g. input with link preview), per PRD **FR12** — **default org storage location**, not a substitute for **`Journal`** on other collections.

**Given** I open the `EmployeePersonalInfo` collection,
**When** I view the `employee_id` field,
**Then** it is configured as a 1:1 M2O link to `Employee`, displaying the employee name.

**Technical Notes:**
- `Employee.ProfitCenter` — **omit/hide** from Directus `Employee` collection in Phase 1 (per PRD A2); do not expose in Admin (or any future SPA)
- `Project.Status` is a PostgreSQL USER-DEFINED enum — configure as select-dropdown; confirm enum values (`Active`, `Inactive`, `Archived` — verify against DB)
- **Operator reference presentation:** **`data-admin-surface-requirements.md`** (**NFR14**); Directus binding Architecture **§4.4**
- After configuration, update `schema.json` snapshot

---

### Story 1.4: Register HR Operations & Hide Out-of-Scope (CPQ/CRM/Ticket) Collections

> **PM — backlog deferral:** **Lower priority** than **security wave** (**1-9**, **1-10**, **1-8**, **Epic 2**), **Epic 3**, and **Epic 6**. **`Role` / `RolePermissions` / `UserToRole` → Story 1.9** (not this story). Hiding **CPQ/CRM/ticket** collections (see AC3) is **lowest Phase 1 product value**.

As an **HR Manager** and **Administrator**,
I want HR operational collections (`TimeEntry`, `Leaves`, `Task`, `InternalCost`) registered in Directus, and all out-of-scope CPQ/CRM/ticket tables hidden from navigation,
So that the Admin UI presents only relevant, Phase 1 collections and the interface remains uncluttered.

**Acceptance Criteria:**

**Given** I am logged in as an Administrator,
**When** I open the `TimeEntry` collection,
**Then** `StartDateTime` and `EndDateTime` are datetime fields, and `Employee`, `Project` are M2O dropdowns; **`HoursWorked`** and **`Task`** are **not** required on `TimeEntry` (duration derived; **Project** is the effort anchor — **FR25**).

**Given** a legacy **`Expense`** table still exists in PostgreSQL,
**When** Phase 1 product policy applies,
**Then** it is **hidden** from navigation **or** registered **read-only** for migration — **canonical** employee spend is **FR28** (**`Transaction`/`Invoice` + `Journal`**), not **`Expense`**.

**Given** I navigate to Collection settings as Administrator,
**When** I view the collection list,
**Then** all 13 out-of-scope collections (`product_catalogue`, `offers`, `offer_line_items`, `Deal`, `Quotes`, `QuoteLineItems`, `ProductDependencies`, `SalesScriptRequests`, `ChatLogs`, `KnowledgeSources`, `sla_definitions`, `tickets`, `ticket_updates`) are marked as hidden and do not appear in any role's navigation.
**And** `TestDebug` is also hidden.

**Technical Notes:**
- Legacy **`Expense`**: do **not** build Phase 1 workflows on it (**PRD A6**, **FR28**).
- Hidden collections retain their data; hiding is a display-only setting in Directus
- After configuration, update `schema.json` snapshot
- **`Role` / `RolePermissions` / `UserToRole`:** implemented under **Story 1.9** (security priority)

---

### Story 1.9: Register RBAC database collections (`Role`, `RolePermissions`, `UserToRole`)

As an **Administrator**,
I want the PostgreSQL RBAC tables **`Role`**, **`RolePermissions`**, and **`UserToRole`** registered in Directus with correct field interfaces and labels,
So that **Epic 2** can configure app permissions and **`UserToRole.User`** can be maintained in alignment with IdP **verified email** (**`identity-provider.md`**, **1-8**) and PostgreSQL RLS (**NFR13**, **1-10**).

**Acceptance Criteria:**

**Given** I am logged in as **Administrator**,
**When** I open **`Role`**, **`RolePermissions`**, and **`UserToRole`**,
**Then** each collection is registered with metadata per Architecture **§4.1** (FKs as M2O where applicable), and **only** Administrator (and system roles as designed) can see these collections until Epic 2 finalizes role visibility.

**Given** the collections exist,
**When** ops insert or update **`UserToRole.User`**,
**Then** values use the **same email normalization** as RLS (`lower()` or as specified in Architecture / **`identity-provider.md`**).

**Implementation artifact:** `_bmad-output/implementation-artifacts/1-9-register-rbac-reference-collections-security.md`  
**Normative:** PRD **NFR1** / **NFR13** (with **1-10** extension), Architecture **ADR-13**, **`identity-provider.md`**.

---

### Story 1.10: Directus extension — RLS request context (`app.user_email`)

As a **Developer / Security**,
I want a **Directus extension** that runs on **user-initiated API requests** and executes `SET LOCAL ROLE <RLS_SESSION_ROLE>; SET LOCAL app.user_email = '<authenticated_email>';` (default role **`directus_rls_subject`**; per Architecture **ADR-13** / PRD **NFR13**),
So that PostgreSQL RLS policies on the 12 protected tables evaluate using the **human user’s** email — **including users with the Directus Administrator flag** — not the pooled service DB user’s owner-access path for `items.*` traffic.

**Acceptance Criteria:**

**Given** an authenticated user (any Directus role, **including Administrator**) with a known email and **`UserToRole`** mapping,
**When** they query an RLS-protected collection via the Directus Data Engine,
**Then** row visibility matches the **PostgreSQL RLS** definitions for that email (not the owner bypass path).

**PENDING (explicit):** **Full matrix verification** (Finance / HR / Executive / Employee / **Administrator** test accounts via **SSO `@expertflow.com`** or equivalent) that **Directus RBAC** and **RLS** agree on allowed rows is **not closed** until **Story 1-8** (SSO) and **Epic 2** (role policies) are at least partially configured — document results in this story’s implementation artifact. Until then, status **“RLS effective for authenticated users” = PENDING**.

**Implementation artifact:** `_bmad-output/implementation-artifacts/1-10-directus-rls-user-context-extension.md`  
**Normative:** PRD **NFR13**, Architecture **ADR-13**.

---

### Story 1.5: Configure All Foreign-Key Relationships

As an **Administrator**,
I want every foreign-key relationship in `schema_dump_final.json` configured as a Directus relational field,
So that Finance Managers, HR Managers, and Executives can navigate between related records directly in the Admin UI without manual ID lookups.

**Acceptance Criteria:**

**Given** I open a `Transaction` record in Directus,
**When** I view the fields,
**Then** `OriginAccount` and `DestinationAccount` both render as M2O dropdowns showing `Account.Name`; `Currency` renders as M2O showing `CurrencyCode`; `Project` renders as M2O showing `Project.Name`.

**Given** I open a `BankStatement` record,
**When** I view the `Transaction` field,
**Then** it renders as an M2O dropdown linking to the parent `Transaction` record.

**Given** I open an `Employee` record,
**When** I view the **`Manager`** field (DB name may be `ManagerId`),
**Then** it renders as a self-referential M2O to `Employee` with **human-readable label = manager `email`** (and name) per **NFR14**/**FR22** — not a bare id.

**Given** I open the `Project` collection,
**When** I view a record's related panel,
**Then** I can see the O2M list of `TimeEntry` records linked to this project.

**Given** I view the `Invoice` collection,
**When** I check all relational fields,
**Then** `OriginAccount`, `DestinationAccount`, `Currency`, `Project` resolve by display template per **FR15** (**no** canonical **`Invoice` → `Transaction`** FK; settlement via **`Allocation`** / **`BankStatement`**).

**Given** the implementation uses **Directus** as the data admin surface,
**When** acceptance is validated,
**Then** **`data-admin-surface-requirements.md`** §1 **R1–R3** holds for in-scope FKs (spot-check lists, item views, pickers; hard-refresh browser). **Do not** duplicate those rules in this story — the canonical spec is **`data-admin-surface-requirements.md`**.

**Technical Notes:**
- Configure all M2O fields first (they establish the FK), then O2M/M2M reverse relations
- Verify full relationship map against `schema_dump_final.json` for all 29 in-scope collections
- **Regression / metadata changes:** follow **`data-admin-surface-requirements.md`** §1 **R5** and §3 (today: `apply-m2o-dropdown-templates.mjs`, `collection-display-templates.mjs`, Architecture **§4.4**)
- Run `directus schema snapshot ./schema.json` and commit after completion

---

### Story 1.6: Enable Audit Logging for Finance & Employee PII Collections

As a **Finance Manager** and **HR Manager**,
I want Directus Activity and Revisions logging enabled for all Finance-domain collections **and** for `EmployeePersonalInfo` (per **NFR8**),
So that every create, update, and delete operation on financial records and sensitive HR PII is tracked with a timestamp and user identity, satisfying audit requirements.

**Acceptance Criteria:**

**Given** a Finance Manager creates a new `Invoice` record,
**When** they navigate to Admin → Activity,
**Then** a log entry appears showing: the action (`create`), collection (`Invoice`), the record ID, the acting user, and a timestamp.

**Given** a Finance Manager updates the `Amount` field on an existing `Transaction`,
**When** they check the Revisions panel on that Transaction record,
**Then** the revision history shows the before and after values for the `Amount` field.

**Given** a Finance Manager deletes a `BankStatement` record,
**When** they check Directus Activity,
**Then** a `delete` activity entry is logged with the record ID and user.

**Given** a non-Finance collection (e.g., `TimeEntry`) is updated,
**When** the Activity log is reviewed,
**Then** Activity logging is working for all collections (Directus logs all by default); the Finance Manager's filtered view focuses on Finance collections.

**Given** an HR Manager updates a sensitive field on `EmployeePersonalInfo` (e.g., `cnic`),
**When** Revisions / Activity is inspected for that record,
**Then** the change is logged with user identity and timestamp per **NFR8**.

**Technical Notes:**
- Directus Activity logging is enabled by default; this story verifies the configuration is intact and Finance Manager role has read access to Activity for finance collections; HR Manager access to Activity/Revisions for `EmployeePersonalInfo` changes per **NFR8**
- Collections to verify: `Account`, `BankStatement`, `Transaction`, `Invoice`, `Allocation`, `Accruals`, `Journal`, **`EmployeePersonalInfo`**
- Finance Manager role must have read access to `directus_activity` filtered to relevant collections; HR visibility for PII-related activity per RBAC policy

---

### Story 1.7: Schema Snapshot & Version Control

As a **Developer**,
I want the complete Directus collection configuration exported as a `schema.json` snapshot committed to the repository root,
So that any team member or AI agent can reproduce the exact Directus configuration from scratch with a single apply command and no manual UI steps.

**Acceptance Criteria:**

**Given** a fresh Directus instance connected to `bidstruct4`,
**When** a developer runs `directus schema apply ./schema.json`,
**Then** all 42 collections are registered with correct field configurations, display templates, and relationship definitions — without any manual UI configuration.

**Given** the repository is inspected,
**When** the `projects/internal-erp/directus/schema.json` file is opened,
**Then** it contains valid Directus schema snapshot JSON covering all collections configured in Stories 1.2–1.6.

**Given** a developer makes a configuration change in the Directus Admin UI,
**When** they run `directus schema snapshot ./schema.json` and commit the diff,
**Then** the git diff clearly shows only the changed field or collection configuration as a JSON delta.

**Technical Notes:**
- Command: `docker exec <container> npx directus schema snapshot /directus/schema.json`
- Copy output to `projects/internal-erp/directus/schema.json` in the repo
- Add a `README.md` section in `projects/internal-erp/directus/` documenting the apply and snapshot commands

---

### Story 1.8: External OIDC identity provider (Directus SSO)

As an **Administrator / DevOps**,
I want Directus production login wired to the **OIDC/OAuth IdP** defined in the repo’s **single canonical spec**,
So that vendor-specific IdP details live **only** in **`identity-provider.md`**, and we can **swap IdP later** by updating that file and this story — not the PRD or Architecture narrative.

**Acceptance Criteria:**

**Given** **`identity-provider.md`** names the current IdP and endpoints,
**When** Story 1.8 is implemented in production,
**Then** staff complete login through that IdP (not shared Directus passwords for end users).

**Given** a user signs in via SSO,
**When** the RLS extension sets `app.user_email`,
**Then** the value matches **`UserToRole.User`** for that person (verified email alignment per **`identity-provider.md`**).

**Given** a user completes SSO with the **trusted IdP** and a **verified** email in a **trusted domain** listed in **`identity-provider.md`** (e.g. `@expertflow.com`),
**When** they have **never** been manually created in Directus,
**Then** they **still** receive a Directus session — **JIT provisioning** creates/links `directus_users` per **`identity-provider.md`** (no ops pre-registration required for allowlisted domains).

**Canonical spec:** `_bmad-output/planning-artifacts/identity-provider.md`  
**Implementation artifact:** `_bmad-output/implementation-artifacts/1-8-external-oidc-identity-provider.md`  
**Normative:** PRD **NFR12**, Architecture **ADR-12**.  
**Depends on:** **Story 1-10** for RLS email injection on API calls; **Story 1-9** for **`UserToRole`** maintenance in Admin.

---

## Epic 2: Secure Role-Based Access Control — **[SECURITY PRIORITY — after Stories 1-9 / 1-10 / 1-8]**

> **PM update 2026-03-17:** This epic is **before Epic 3** in `sprint-status.yaml` (security-led). Complete **1-9**, **1-10**, **1-8** first. **Non-Admin RLS vs Directus** matrix remains **PENDING** until extension + SSO + policies land — see **Story 1.10** artifact.

**Goal:** Each team persona (Finance Manager, Executive, HR Manager, Line Manager, Employee) can log into Directus and immediately sees only their permitted collections and records — with item-level scoping enforced at the API layer. No role can access data beyond their mandate.

---

### Story 2.1: Create Directus Roles

As an **Administrator**,
I want five Directus roles created (`finance-manager`, `executive`, `hr-manager`, `line-manager`, `employee`),
So that I can assign users to roles and begin configuring granular permissions for each persona.

**Acceptance Criteria:**

**Given** I navigate to Settings → Roles in Directus Admin,
**When** I view the roles list,
**Then** exactly five custom roles exist: `Finance Manager`, `Executive`, `HR Manager`, `Line Manager`, `Employee` — in addition to the system `Administrator` role.

**Given** I create a test user and assign them the `Employee` role,
**When** they log in,
**Then** they can authenticate successfully (Directus returns a valid auth token) and the session recognizes their role.

**Given** I inspect any newly created custom role,
**When** I check its default permissions,
**Then** all collections start with zero permissions (no access) — permissions will be explicitly granted in subsequent stories.

**Technical Notes:**
- Role names are display labels; internal role IDs are UUIDs generated by Directus
- Each role's `app_access` (**Phase 1 Directus-only speed, PRD §5.13 / Architecture**): `finance-manager`, `executive`, `hr-manager`, `line-manager`, **`employee`** → **`true`** so Employees use **Directus Admin** for time, leave, and expenses (Epic 5). If a **dedicated SPA** is added later (Epic 7), revisit whether `employee` stays `true` (hybrid) or goes `false` (API-only client).

---

### Story 2.2: Configure Finance Manager Permissions

As a **Finance Manager**,
I want full Create, Read, Update, and Delete access to all financial collections, currency data, and organizational reference tables,
So that I can perform every financial operation — from importing bank statements to managing invoices — without hitting permission errors.

**Acceptance Criteria:**

**Given** I am logged in as a Finance Manager,
**When** I navigate to the Directus Admin UI,
**Then** I can see and access: `Account`, `BankStatement`, `Transaction`, `Invoice`, `Allocation`, `Accruals`, `Journal`, `Currency`, `CurrencyExchange`, `LegalEntity`, `ProfitCenter`, `Project`, `CountryLocation`, `Contact`, `Company`, `Seniority`, `Designation`, `department`, `InternalCost`.

**Given** I am logged in as a Finance Manager,
**When** I attempt to create, update, and delete a record in `Invoice`,
**Then** all three operations succeed without permission errors.

**Given** I attempt to read the `Accruals` collection as Finance Manager,
**When** I make the API call `GET /items/Accruals`,
**Then** the response returns Accruals records (not a 403 Forbidden).

**Given** I am logged in with the `hr-manager` role,
**When** I call `GET /items/Accruals`,
**Then** the API returns `403 Forbidden`.

**Technical Notes:**
- Configure collection permissions using Directus Permissions API or Admin UI
- Also grant Finance Manager read access to `directus_activity` (audit log) scoped to Finance collections
- After configuration, export updated `schema.json`

---

### Story 2.3: Configure HR Manager Permissions (Employee Ledger Read + Full HR)

As an **HR Manager**,
I want full CRUD on employee lifecycle collections and **read-only** access to **Employee-ledger** financial rows (`Account`, `BankStatement`, `Transaction`, `Invoice`) while remaining blocked from **Executive-ledger** and Finance-only collections,
So that I can support payroll/HR operations on **Employee** legal-entity books without seeing **Executive** legal-entity amounts (PRD FR33, FR40, FR41).

**Acceptance Criteria:**

**Given** I am logged in as an HR Manager,
**When** I navigate to the `Employee` collection,
**Then** I can list and open **every** `Employee` record (no item-level filter on `Employee`).

**Given** I am logged in as an HR Manager,
**When** I view an `Employee` in Directus,
**Then** the legacy `ProfitCenter` text field is **not** shown (per PRD A2).

**Given** I am logged in as an HR Manager,
**When** I call `GET /items/Account`,
**Then** I receive **only** `Account` rows where `LegalEntity.Type = 'Employee'`.

**Given** I am logged in as an HR Manager,
**When** I call `GET /items/BankStatement`,
**Then** I receive **only** rows where `Account.LegalEntity.Type = 'Employee'`.

**Given** I am logged in as an HR Manager,
**When** I call `GET /items/Transaction`,
**Then** I receive **only** rows where **at least one** of `OriginAccount.LegalEntity.Type` or `DestinationAccount.LegalEntity.Type` equals `'Employee'`, **and neither** leg resolves to `LegalEntity.Type = 'Executive'`. (Matches PostgreSQL RLS `policy_hr` — see Architecture §8.2.)

**Given** a `Transaction` exists where **either** account leg resolves to `LegalEntity.Type = 'Executive'`,
**When** an HR Manager calls `GET /items/Transaction/<id>`,
**Then** the API returns `403 Forbidden` or the record is omitted from list results.

**Given** I am logged in as an HR Manager,
**When** I attempt `POST /items/Transaction` (create) or `PATCH /items/Invoice/<id>` (update),
**Then** the API returns `403 Forbidden` — HR has **read** only on these ledger collections.

**Given** I am logged in as an HR Manager,
**When** I call `GET /items/Accruals` or `GET /items/Allocation`,
**Then** the API returns `403 Forbidden` (PRD **FR41**).

**Given** I am logged in as an HR Manager,
**When** I call `GET /items/CurrencyExchange`,
**Then** the API returns **`200`** (non-sensitive reference — PRD **FR19**).

**Given** I am logged in as an HR Manager,
**When** I call `GET /items/Journal`,
**Then** the API returns **`200`** and results are **limited** to **`JournalLink.collection`** ∈ {`Transaction`, `Invoice`, `Employee`} **with** HR-scoped filters (PRD **FR33**/**FR41**).

**Given** I am logged in as an HR Manager,
**When** I view the Directus Admin UI sidebar,
**Then** `Account`, `BankStatement`, `Transaction`, `Invoice`, **`Journal`** (read-only / scoped), and **`CurrencyExchange`** **may** appear per policy, while `Accruals` and `Allocation` do **not** appear.

**Technical Notes:**
- Apply JSON filters per Architecture §5.3 **HR Manager** block (verify relation field names against `schema.json`). **HR filter on `Transaction`/`Invoice`**: either leg Employee, no leg Executive — matches PostgreSQL RLS.
- **No** item-level filter on `Employee` for `hr-manager`
- **Operator help:** PRD **§4.4** explains **“salary”** vs ledger objects and **RLS** across **`Invoice`**, **`Transaction`**, **`BankStatement`**, and **`Accruals`** (delayed pay — **Finance-only**; HR does **not** open **`Accruals`**) — add to **`Invoice`** (and HR onboarding) **Note** (**NFR14**).
- **PostgreSQL RLS** (NFR13/ADR-13): these Directus filters must **agree** with the existing `policy_hr` / `policy_*_hr_*` RLS policies in `bidstruct4`. Both layers enforce; Directus is the UX gate, RLS is the backstop.
- `DefaultProjectId` help text: *default time/cost project — not used for access control*

---

### Story 2.4: Configure Executive Permissions (Same as Employee — PRD FR20–FR21, FR40)

As an **Executive**,
I want **the same** read access as **any employee** on sensitive data (no special RLS),
So that **Finance / HR / line-manager** tiers remain the **only** elevated visibility paths (**FR21**, **FR40**).

**Acceptance Criteria:**

**Given** I am logged in as an Executive (**only** `executive` role, not Finance/HR/`line-manager`),
**When** I call `GET /items/Project`,
**Then** the request behaves **like** **`employee`** — same collection permissions and item-level filters (reference / active-project rules per Architecture).

**Given** I am logged in as an Executive (**only** `executive`),
**When** I call `GET /items/Transaction`, `GET /items/Invoice`, `GET /items/Account`, or `GET /items/BankStatement`,
**Then** the API returns **`403 Forbidden`** or **empty** results — **same** as **`employee`** (**FR21**/**FR40**).

**Given** I am logged in as an Executive (**only** `executive`),
**When** I call `GET /items/Allocation`, `GET /items/Accruals`, or `GET /items/InternalCost`,
**Then** the API returns **`403 Forbidden`** (**FR41**).

**Given** I am logged in as an Executive (**only** `executive`),
**When** I call `GET /items/Journal`,
**Then** results are **only** those permitted for **`employee`** (e.g. own **FR28** **`Journal`** on **`Transaction`/`Invoice`** per **FR41**), not org-wide.

**Given** I am logged in as an Executive,
**When** I open Directus Insights (P&L or cash flow),
**Then** panels show **only** data I could read via **`items.*`** — **no** RLS bypass (**FR20**).

**Given** I am logged in as an Executive,
**When** I attempt `POST`/`PATCH`/`DELETE` on Finance ledger or HR ops collections,
**Then** the API returns `403 Forbidden` unless a future story delegates write (**FR21**).

**Technical Notes:**
- **Mirror `employee`** Directus policies onto **`executive`** for sensitive collections; diff only where product explicitly needs (e.g. navigation bookmarks).
- **`UserToRole` / PostgreSQL:** map Executive users to **baseline** (e.g. role **117**) — **not** a distinct “Executive SELECT all” policy (**NFR13**).

---

### Story 2.5: Configure Line Manager & Employee Permissions

As a **Line Manager**,
I want read and approval access to `TimeEntry`, `Leaves`, and `Task` records for my direct reports, **and** read access to **subordinates’ payroll-related recurring `Invoice` rows** (and ledger rows Architecture links to them) for **all subordinates** in my reporting hierarchy,
So that I can oversee my team and **Employee-ledger payroll invoices** without org-wide ledger access (**FR33**, **FR40**).

As an **Employee**,
I want CRUD access to my own `TimeEntry`, `Leaves`, and `Task` records **and** to **initiate/read** my **FR28** spend outcomes (**`Transaction`/`Invoice`** + **`Journal`** per **FR41**),
So that I can log my activity and submit spend **without** accessing any other employee's data.

**Acceptance Criteria:**

**Given** I am logged in as a Line Manager,
**When** I call `GET /items/TimeEntry`,
**Then** only TimeEntry records where `Employee.ManagerId = currentUser.employee_id` are returned.

**Given** I am logged in as a Line Manager,
**When** I update the status of a `Leaves` record for my direct report,
**Then** the update succeeds (Line Manager has Update on Leaves for their team).

**Given** I am logged in as a Line Manager and employee **S** is anywhere in my **subordinate tree** (`ManagerId` chain),
**When** I read a **payroll-related recurring `Invoice`** for subordinate **S** (Employee-ledger accounts per BS4) and related ledger rows defined in Architecture,
**Then** I **can** read those rows **and** I **cannot** read **Executive**-ledger rows (`LegalEntity.Type = 'Executive'`) unless I am also Finance or HR (**FR40**).

**Given** I am logged in as a Line Manager,
**When** I call `GET /items/Transaction` for rows **unrelated** to my subordinates’ payroll **`Invoice`** path,
**Then** the API returns `403` / empty — **no** general ledger read (**FR40**).

**Given** I am logged in as an Employee (user `emp-001`),
**When** I call `GET /items/TimeEntry`,
**Then** only TimeEntry records where `Employee = currentUser.employee_id` are returned.

**Given** I am logged in as an Employee,
**When** I attempt `GET /items/TimeEntry` for a different employee's record ID,
**Then** the API returns `403 Forbidden` or an empty result.

**Given** I am logged in as an Employee,
**When** I attempt to access `GET /items/Invoice`,
**Then** the API returns `403 Forbidden`.

**Technical Notes:**
- Requires mapping `currentUser` to their `Employee.id` — add `employee_id` as a custom field on `directus_users`
- Line Manager filter on TimeEntry/Leaves/Task: `{ "Employee": { "ManagerId": { "_eq": "$CURRENT_USER.employee_id" } } }` (direct reports; **FR25**)
- **Subordinate payroll `Invoice`:** RLS + Directus filters per Architecture — recursive `ManagerId` tree, role **118** or equivalent in **`UserToRole`**; identify payroll via recurring **`Invoice`** + **`LegalEntity.Type`**, not a standalone payroll column on **`Employee`**
- Employee filter: `{ "Employee": { "_eq": "$CURRENT_USER.employee_id" } }`

---

### Story 2.6: Hide Restricted Collections & Finalise Navigation

As **every role**,
I want my Directus Admin navigation to show only the collections I am permitted to access,
So that the interface is clean, intuitive, and does not expose the existence of collections I have no business reason to know about.

**Acceptance Criteria:**

**Given** I am logged in as an HR Manager,
**When** I view the left-sidebar navigation in Directus Admin,
**Then** I see HR collections **and** collections HR may **read** per PRD (**`Account`**, **`BankStatement`**, **`Transaction`**, **`Invoice`**, scoped **`Journal`**, **`CurrencyExchange`**) — **not** **`Accruals`**, **`Allocation`**, or **`InternalCost`**.

**Given** I am logged in as any non-Administrator role,
**When** I attempt a direct API call to `GET /items/Accruals` or `GET /items/Allocation`,
**Then** the API returns `403 Forbidden` regardless of how the request was constructed.

**Given** I am logged in as **`line-manager`** or **`employee`**,
**When** I call `GET /items/Transaction`, `GET /items/Invoice`, `GET /items/Account`, or `GET /items/BankStatement`,
**Then** the API returns `403 Forbidden` (FR40).

**Given** I am logged in as **`executive`** (**only** that role),
**When** I call the same `GET` endpoints,
**Then** the API returns **`403 Forbidden`** or **empty** — **same** as **`employee`** (**FR21**/**FR40**).

**Given** I am logged in as any non-Administrator role,
**When** I attempt `GET /items/RolePermissions`,
**Then** the API returns `403 Forbidden`.

**Given** the full RBAC configuration is complete,
**When** a developer runs `directus schema snapshot ./schema.json`,
**Then** the snapshot includes all permission configurations and can be re-applied to a fresh instance to reproduce the exact same access control state.

**Technical Notes:**
- Use Directus "Hidden" flag per collection per role to remove from sidebar
- This story is the final RBAC gate — after completion, run a regression test login for each of the 5 roles to verify navigation and a sample API access denial
- Commit the final `schema.json` with full RBAC configuration

---

## Epic 3: Financial Ledger & Bank Management — **[After Epic 2 in security-led sprint]**

> **PM update 2026-03-17:** This epic follows **Epic 2** in `sprint-status.yaml`. Stories are written as “Finance Manager”; if Epic 2 is not complete yet, **verify with Administrator** (or document temporary full access). Re-validate **FR11** and **FR31–FR41** after RBAC + RLS matrix (**PENDING** — see **Story 1.10**) is closed.

**Goal:** Finance Managers have a complete, auditable financial ledger. They can import bank statements with **`Transaction = NULL` allowed** (zero duplicates guaranteed; **PRD FR6**/**FR10**), **reconcile** to map each line to a `Transaction` (including attaching to an **existing** `Transaction` for split legs; **0–2** cap), **optionally** create **`Allocation`** to **`Invoice`**, attach documents as journal evidence, and manage currencies — all through Directus Admin with automatic audit trail.

> **PRD alignment:** `BankStatement.Transaction` is **nullable at import**; reconciliation sets it. Stories **3.1–3.2** cover dedup + reconciliation + cap hooks per **Architecture**. **Story 3.2b** is a **stub** for **FR46** (multi-bank spreadsheet pipeline) — refine later.

---

### Story 3.1: Bank Statement Import with Deduplication

As a **Finance Manager**,
I want to import raw bank transactions into `BankStatement` **with or without a `Transaction`**, with the system automatically rejecting any duplicate bank line,
So that I can load unreconciled bank data first and map to ledger `Transaction` in a reconciliation step (**FR6**/**FR9**).

**Acceptance Criteria:**

**Given** I create a `BankStatement` record with `Account = 5`, `BankTransactionID = "TXN-ABC-001"`, `Amount`, `Date`, and `Description` — and **no `Transaction` value**,
**When** I submit the record,
**Then** the record is saved successfully with `Transaction = NULL` and appears in the BankStatement collection list (**FR6**).

**Given** I create a `BankStatement` record with `Account = 5`, `BankTransactionID = "TXN-ABC-001"`, required fields, **and** a valid `Transaction` FK,
**When** I submit the record,
**Then** the record is saved successfully and appears in the BankStatement collection list.

**Given** I create a `BankStatement` record with `Account = 5` and `BankTransactionID = "TXN-ABC-001"` and a valid `Transaction`,
**When** I submit a second record with the same `Account = 5` and `BankTransactionID = "TXN-ABC-001"` (any `Transaction`),
**Then** the API returns a `400 Bad Request` with error message: `"Duplicate BankStatement: BankTransactionID 'TXN-ABC-001' already exists for this Account"`.
**And** no duplicate record is persisted in the database.

**Given** I create a `BankStatement` record where `BankTransactionID` is empty/null,
**When** I submit the record,
**Then** the system computes a deduplication hash from `AccountID + Date + Amount + Description` and stores it as the effective uniqueness key.
**And** a second record with the same computed hash is rejected with a duplicate error.

**Given** I create a `BankStatement` with `Account = 5` and `BankTransactionID = "TXN-ABC-001"`,
**And** I create another with `Account = 7` and `BankTransactionID = "TXN-ABC-001"`,
**When** both records are submitted,
**Then** both are accepted (same BankTransactionID but different Accounts = not a duplicate).

**Technical Notes:**
- Implement as a Directus Hook extension: `action: items.create` **ONLY** on `BankStatement` — deduplication does NOT fire on update/reconciliation operations
- Hook location: `projects/internal-erp/directus/extensions/hooks/bank-statement-dedup/` (separate from the 0–2 cap hook in Story 3.2)
- **Validation**: check `Account + BankTransactionID` composite uniqueness; if `BankTransactionID` is null/empty, compute a fallback hash from `AccountID + Date + Amount + Description`
- TypeScript: throw `InvalidPayloadError` on duplicate detection
- Register extension in `docker-compose.yml` volume mount

---

### Story 3.2: BankStatement ↔ Transaction — 3-Option Workflow & 0–2 Cap

As a **Finance Manager**,
I want to **create or change** the `Transaction` on a `BankStatement` using match-existing, spawn-from-`Invoice`, or create-new paths, with sign-based account pre-fill and rejection when a `Transaction` would exceed **two** `BankStatement` rows,
So that every bank line stays ledger-backed and split / bridge cases remain supported (**FR9**/**FR10**).

**Acceptance Criteria:**

**Given** I am logged in as a Finance Manager and open the BankStatement collection,
**When** I filter by `Transaction IS NULL`,
**Then** I see unreconciled `BankStatement` rows awaiting reconciliation (**FR6**).

**Given** I open a BankStatement with `Amount = +1500` and `Account = 7` (Option A — match existing),
**When** I update it to `BankStatement.Transaction = <existing Transaction id>` (and the cap allows it),
**Then** the update succeeds and the Transaction shows the linked BankStatement in its reverse O2M panel.

**Given** I open a BankStatement with `Date = D` and `Amount = A` (same currency as candidate rows),
**When** I request reconciliation suggestions for Option A or Option B,
**Then** the system only lists `Transaction` or `Invoice` candidates whose date falls within **±3 working (business) days** of `D` (weekends excluded) and whose amount is within **±5%** of `A`.

**Given** I open a BankStatement and choose Option B — spawn from Invoice,
**When** I select an Invoice from that filtered suggestion list,
**Then** the system creates a new `Transaction` pre-populated with the Invoice's data and sets `BankStatement.Transaction` to the new Transaction's id.
**And** the BankStatement points at the new Transaction.

**Given** I open a BankStatement with `Amount = +1500` and `Account = 7` (Option C — create new Transaction),
**When** I create a new Transaction for this BankStatement,
**Then** the system pre-populates `Transaction.DestinationAccount = 7` (positive amount = credit, money arrives in this account).
**And** I fill in the remaining fields (`OriginAccount`, `Currency`, `Date`, `Project`, etc.) and save.

**Given** I open a BankStatement with `Amount = -800` and `Account = 3` (Option C — create new Transaction),
**When** I create a new Transaction for this BankStatement,
**Then** the system pre-populates `Transaction.OriginAccount = 3` (negative amount = debit, money leaves this account).
**And** I fill in the remaining fields and save.

**Given** a `Transaction` already has two linked BankStatements,
**When** I attempt to reconcile a third BankStatement to that same Transaction (any option),
**Then** the API returns `400 Bad Request` with message: `"Transaction limit reached: a Transaction may be linked to at most 2 BankStatement records"`.
**And** the third BankStatement’s `Transaction` FK is **unchanged**.

**Given** I am logged in as a Finance Manager,
**When** I navigate to the `Transaction` collection,
**Then** I can create, read, update, and delete Transaction records with canonical fields (`OriginAccount`, `DestinationAccount`, `Amount`, `Currency`, `Description`, `Date`, `Project`) per **FR11**.
**And** **`BankStatementId`** / **`image`** / **`expense_id`** are **not** canonical on `Transaction` (hidden or omitted; bank link is **`BankStatement` → `Transaction`** only).

**Technical Notes:**
- The 0–2 cap is a Directus Hook: `action: items.update` on `BankStatement`, **and** `action: items.create` when the payload sets a **non-null** `Transaction` (skip cap when `Transaction` is null — **FR6**), implemented in `extensions/hooks/bank-statement-limit/` (separate from the dedup hook in Story 3.1)
- Hook runs when assigning or changing **non-null** `BankStatement.Transaction`
- Query: count existing `BankStatement` rows where `Transaction = payload.Transaction` (excluding the current row); reject if count ≥ 2
- **Match window** (Options A & B): implement working-day math (e.g. library or calendar table) for ±3 business days; amount band `A * [0.95, 1.05]`; filter candidates to same currency as the BankStatement row in Phase 1
- **Sign logic** (Options B and C): implemented as a Directus Flow or frontend helper that reads `BankStatement.Amount` before creating the Transaction stub: `Amount > 0` → pre-fill `DestinationAccount`; `Amount < 0` → pre-fill `OriginAccount`
- **Option B (Invoice spawn)**: the Flow creates a Transaction using Invoice fields (`Amount`, `Date`, related Account), then patches the BankStatement; both operations are wrapped in a database transaction to ensure atomicity
- An AI engine performing reconciliation uses the same `PATCH /items/BankStatement/<id>` endpoint — same Hook enforcement applies; sign-based pre-population is a client-side convenience and is not enforced server-side

---

### Story 3.2b (STUB — refine later): Multi-bank CSV / spreadsheet import pipeline

**Status:** **STUB only** — acceptance criteria, tasks, story key, and sprint placement **TBD**; expand when Finance + Engineering prioritize **FR46**.

**PRD:** **FR46** (multi-bank normalization, up to **four** `BankStatement` description fields, batch dedup-before-insert, review-then-import for scripted path, **NFR2** / **NFR7**). **FR8** (fallback hash includes all description fields). **Reference:** `_bmad-output/reference/banking-spreadsheet-import-legacy-source.md`.

**Placeholder intent (not final AC):**
- Schema / Directus: **`BankStatement`** narrative columns per **FR46.1**; dedup hook updated for multi-field hash (**Architecture**).
- Per-house-bank **mapping docs** + normalization path (**FR46.2**).
- **Scripted** import: review CSV + explicit go-ahead before `POST` to Directus (**FR46.4**).
- **No secrets** in notebooks or repo (**FR46.5**).

---

### Story 3.3: Journal Entry & Polymorphic Document Linking

As a **Finance Manager**,
I want to attach any evidence document (PDF, image, email URL) to any financial record by capturing it as a `Journal` entry, whose associated file is stored securely in **Google Cloud Storage (GCS)** and linked via the polymorphic `JournalLink` junction table (`JournalLink.collection` and `JournalLink.item`),
So that I can centralize evidence storage and reference it from any transaction, invoice, or bank statement without being restricted to a single table's attachment field.

**Acceptance Criteria:**

**Given** I am in the `Journal` collection,
**When** I create a new Journal entry,
**Then** I can select `JournalLink.collection` from a dropdown (e.g., `Invoice`, `Transaction`, `BankStatement`, `Employee`) and enter a `JournalLink.item`.

**Given** I navigate to an existing `Invoice`, `Transaction`, or `Employee` record in the Directus Admin UI (including from a mobile phone browser at `bs4.expertflow.com`),
**When** I view the "Journal Entries" related items panel,
**Then** I have an out-of-the-box button to instantly add or remove an attachment. Clicking "Add" opens a drawer allowing me to upload a file—or dynamically take a picture using my phone's camera—which uploads securely to GCS and links to the parent record without leaving the view.

**Given** I create a Journal entry linked to a Transaction,
**And** separately create a Journal entry linked to an Invoice,
**When** I query `GET /items/Journal?filter[JournalLink.collection][_eq]=Transaction`,
**Then** only Transaction-linked Journal entries are returned.

**Given** I upload a PDF receipt as a `document_file` on a Journal entry,
**When** I view the Journal record,
**Then** the file is accessible via the Directus Files panel **for users who may read the referenced parent** (PRD **FR12** visibility inheritance).

**Given** a Journal entry references an **`Invoice`** the caller **cannot** read (e.g. HR user, Executive-ledger invoice),
**When** that user calls `GET /items/Journal/<id>` or requests the linked **asset URL**,
**Then** the API returns **403** / empty / no usable URL — **ResourceURL** and **`document_file`** links MUST NOT bypass parent RBAC/RLS (**FR12**).

**Technical Notes:**
- `JournalLink.collection` + `JournalLink.item` is a M2A JournalLink junction pattern (Directus does not natively support polymorphic M2O)
- Configure `JournalLink.collection` as a select-dropdown including at least: `Invoice`, `Transaction`, `Employee`, `LegalEntity`, `BankStatement`, `Account`, `Project`, `InternalCost` (**omit `Expense`** for new evidence — **FR29**)
- For the related Journal panel on each collection: add an O2M "virtual" panel configured with a filter on `JournalLink.collection = '<CollectionName>'` and `JournalLink.item = <currentItemId>` using Directus M2A or a custom approach
- `document_file` field should use Directus file interface with upload capability
- **Enforce FR12:** hooks on `items.read` for `Journal`, **`Journal` RLS**, and/or **restricted file access** so asset IDs cannot be guessed to leak evidence

---

### Story 3.4: Invoice & Allocation Management

As a **Finance Manager**,
I want full Create, Read, Update, Delete access to `Invoice` and `Allocation` records,
So that I can manage the complete invoicing lifecycle and allocate payments between accounts.

**Acceptance Criteria:**

**Given** I am logged in as a Finance Manager,
**When** I create an `Invoice` with canonical fields per PRD **FR15** (`OriginAccount`, `DestinationAccount`, `Description`, `SentDate`, `DueDate`, `PaymentDate`, `Currency`, `Amount`, `Status`, `Recurrence`, optional `Project`; **no** `employee_id`, **no** persisted `NextIssueDate`),
**Then** the Invoice is saved with a system-generated auto-increment `id` and is visible in the collection list.

**Given** the `Invoice` collection is configured per PRD **FR15**/**FR12**,
**When** I inspect fields,
**Then** there is **no** `image` / inline file field on **`Invoice`**; there is **no** operator-facing M2O from `Invoice` → `Transaction` (legacy omitted); PDFs/scans are added as **`Journal`** rows (`JournalLink.collection='Invoice'`).

**Given** a recurring `Invoice` exists whose **`DueDate`** is exactly equal to today and **`RecurMonths` > 0** (per **FR44**),
**When** the **FR44** scheduled cron job runs,
**Then** a **new** `Invoice` row is created for the next period, its `DueDate` set to `old DueDate + RecurMonths`, and the parent's `RecurMonths` is set to 0.

**Given** I create an `Allocation` linking an `Invoice` to a `Transaction` with an `Amount` and `TransferLoss`,
**When** I view the Allocation record,
**Then** all fields are correctly stored and the M2O links to `Invoice` and `Transaction` resolve to their display templates.

**Given** I am logged in as an HR Manager,
**When** I attempt `GET /items/Allocation`,
**Then** the API returns `403 Forbidden`.

**Given** I am logged in as an Executive (**only** `executive`),
**When** I call `GET /items/Allocation`,
**Then** the API returns **`403 Forbidden`** — same as **`employee`** (**FR21**/**FR41**).

---

### Story 3.5: Accruals Management (Finance-Only)

As a **Finance Manager**,
I want to create, view, and manage `Accruals` entries for project-based fiscal year cost recognition,
So that I can track accrued expenses by project and fiscal year without this data being visible to HR, **`executive`**, or other non-Finance roles (**FR21**/**FR41**).

**Acceptance Criteria:**

**Given** I am logged in as a Finance Manager,
**When** I create an `Accruals` record with `Project`, `Amount`, `Currency`, and `FiscalYear`,
**Then** the record is saved and visible in the `Accruals` collection list.

**Given** I am logged in as any role other than Finance Manager (`executive`, `hr-manager`, `line-manager`, `employee`),
**When** I navigate to the Directus Admin UI,
**Then** the `Accruals` collection does not appear in the navigation sidebar.

**Given** I am logged in as any non-Finance-Manager role,
**When** I make a direct API call `GET /items/Accruals`,
**Then** the API returns `403 Forbidden`.

---

### Story 3.6: Currency Reference & Exchange Rate Management

As a **Finance Manager**,
I want to manage `Currency` reference records and historical `CurrencyExchange` rates,
So that all financial records can be denominated in any currency and converted to USD using the correct historical rate for reporting.

**Acceptance Criteria:**

**Given** I am logged in as a Finance Manager,
**When** I open the `Currency` collection,
**Then** I can create a new currency with `CurrencyCode` and `Name`, and edit or delete existing currencies.

**Given** I am logged in as a Finance Manager,
**When** I create a `CurrencyExchange` record with `Currency = "PKR"`, `Day = 2026-03-01`, `RateToUSD = "0.00358"`, `Year = 2026`, `Month = 3`,
**Then** the record is saved with the unique `Key` field populated (or entered manually).

**Given** I am logged in as an HR Manager or Employee,
**When** I call `GET /items/Currency`,
**Then** I receive a read-only list of currencies (HR/Employee have read access to Currency as a reference lookup).

**Given** I am logged in as an HR Manager,
**When** I call `GET /items/CurrencyExchange`,
**Then** the API returns `403 Forbidden`.

---

### Story 3.7: Rapid Allocation UI (Angular Rebuild)

As a **Finance Manager**,
I want a high-density, keyboard-friendly Angular application to allocate `Invoice` records to `Transaction` records,
So that I can rapidly clear invoices and ensure all financial movements are properly reconciled via transactions.

**Acceptance Criteria:**

**Given** I access the Rapid Allocation UI,
**When** the application loads,
**Then** I see an unreconciled list of `Invoice` records alongside available `Transaction` records.

**Given** I interact with the "Entities" feature (adapted from the Lovable draft),
**When** I allocate an `Invoice` to a `Transaction`,
**Then** I can complete the reconciliation workflow, ensuring the invoice is marked as cleared/allocated.

**Given** I use the dashboard views,
**When** I navigate to the "Cashflow" or "Past earnings" sections,
**Then** I see visual reporting based on the Streamlit draft implementation.

**Given** I interact with the UI,
**When** I use keyboard shortcuts (e.g. arrow keys for navigation, Enter to select),
**Then** I can complete the allocation workflow without relying strictly on the mouse.

**Technical Notes:**
- Implement as a standalone custom App or module (e.g., `apps/rapid-allocation-ui` in Angular).
- Combines the "Entities" reconciliation between Invoices and Transactions from the Lovable draft and the "Cashflow" / "Past earnings" from the Streamlit draft.
- Note: This process has **nothing** to do with `BankStatement` records.
- Connects to the Directus API via the official SDK or REST.

---

## Epic 4: HR Administration & Employee Lifecycle

**Goal:** HR Managers can fully manage the **entire** employee roster, maintain sensitive personal information, configure organizational reference data, and record internal cost movements between Profit Centers — giving HR complete operational control of the workforce. **Financial** privacy for executive vs employee **books** is enforced on **financial collections** via **`LegalEntity.Type`** (not by hiding employee master records).

---

### Story 4.1: Employee Core Profile Management

As an **HR Manager**,
I want to create, view, update, and search **all** `Employee` records,
So that I can manage the full employee lifecycle from onboarding to offboarding with all relevant organizational attributes linked — with `DefaultProjectId` used only as the **default time/cost project**, not for access control.

**Acceptance Criteria:**

**Given** I am logged in as an HR Manager,
**When** I create a new `Employee` with `EmployeeName`, `email`, `employ_start_date`, `status`, `Seniority`, `departmentid`, `DesignationID`, **`Manager`** (M2O → `Employee`; UI shows manager **`email`**), and optionally `DefaultProjectId`,
**Then** the Employee record is saved and appears in the collection list with display template `{{EmployeeName}} ({{email}})`.

**Given** any `Employee` record exists in the database,
**When** I, as an HR Manager, call `GET /items/Employee`,
**Then** that employee **is** returned in the result set (no filter on `DefaultProjectId` / LegalEntity for HR).

**Given** I am logged in as an HR Manager,
**When** I search for an employee by name using Directus search,
**Then** all matching employees are returned regardless of default project or legal entity type.

**Given** I deactivate an Employee by setting `status = 'inactive'`,
**When** I view the employee list,
**Then** the record is still visible (soft state change, not deletion) and the status field reflects the update.

---

### Story 4.2: Employee Personal Information Management

As an **HR Manager**,
I want to create and manage `EmployeePersonalInfo` records linked 1:1 to `Employee`,
So that sensitive personal data (CNIC, NTN, emergency contacts, date of birth) is stored securely and accessible only to HR and the employee themselves.

**Acceptance Criteria:**

**Given** I am logged in as an HR Manager,
**When** I open an `Employee` record and navigate to the linked `EmployeePersonalInfo` panel,
**Then** I can create/edit/view the associated personal info record (CNIC, NTN, phone, DoB, address).

**Given** I am logged in as Employee `emp-001`,
**When** I call `GET /items/EmployeePersonalInfo?filter[employee_id][_eq]=<my_employee_id>`,
**Then** I receive my own personal info record.

**Given** I am logged in as Employee `emp-001`,
**When** I call `GET /items/EmployeePersonalInfo?filter[employee_id][_eq]=<other_employee_id>`,
**Then** the API returns `403 Forbidden` or an empty result.

**Given** I am logged in as a Finance Manager or Executive,
**When** I call `GET /items/EmployeePersonalInfo`,
**Then** the API returns `403 Forbidden`.

**Technical Notes:**
- Configure `cnic` / `ntn` (and similar) with restrictive read permissions or masked display per **NFR11**; document retention decision when Phase 2 policy is defined

---

### Story 4.3: Organizational Reference Data Management

As an **HR Manager**,
I want to create, update, and manage `Seniority`, `Designation`, and `department` reference tables,
So that Employee records can be accurately classified with organizational attributes that drive cost calculations and reporting.

**Acceptance Criteria:**

**Given** I am logged in as an HR Manager,
**When** I create a new `Seniority` record with `Description = "Senior Engineer"` and `Dayrate = 250.00`,
**Then** the record is saved and immediately available as a dropdown option in the `Employee.Seniority` field.

**Given** I create a new `Designation` with `DesignationName = "Principal Consultant"`,
**When** I open an Employee record and edit the `DesignationID` field,
**Then** "Principal Consultant" appears in the dropdown.

**Given** I am logged in as a Line Manager or Employee,
**When** I call `GET /items/Seniority` or `GET /items/department`,
**Then** I receive the read-only list (these roles have read access to reference tables).

**Given** I am logged in as a Line Manager,
**When** I attempt `POST /items/Seniority`,
**Then** the API returns `403 Forbidden` (Line Managers are read-only on reference data).

---

### Story 4.4: Internal Cost Transfer Management

As a **Finance Manager**,
I want to create and maintain `InternalCost` records for **project-to-project** internal allocations,
So that inter-project cost / effort attribution is tracked (canonical model per PRD **FR30**; future monthly roll-up from **`TimeEntry`** per **FR43** — **no** `TimeEntryId` on `InternalCost`).

**Acceptance Criteria:**

**Given** I am logged in as a Finance Manager,
**When** I create an `InternalCost` record with `FromProject` and `ToProject` (M2O to `Project`), `Currency`, `Date`, and `Amount`,
**Then** the record is saved and both project fields resolve to human-readable project labels per **`data-admin-surface-requirements.md`**.

**Given** the `InternalCost` collection is configured per PRD **FR30**,
**When** I inspect collection fields in Directus,
**Then** there is **no** canonical relational field from `InternalCost` → `TimeEntry` (legacy `TimeEntryId` omitted or non-editable pending DB migration).

**Given** a future **FR43** monthly job has run for a calendar month,
**When** I query `InternalCost` for that period,
**Then** there is **at most one** row per distinct **`(FromProject, ToProject)`** pair for that month (idempotent upsert behavior — implementation detail in Architecture / story).

**Given** I am logged in as an HR Manager,
**When** I call `GET /items/InternalCost`,
**Then** the API returns `403 Forbidden`.

---

## Epic 5: Operational HR Tracking

**Goal:** The day-to-day HR operations loop is closed: Employees can log time, submit leave requests, assign tasks, and file expenses. Line Managers can approve or reject. HR and Finance have full visibility. All operations enforce own-record scoping at the API layer.

---

### Story 5.1: Time Entry Logging & Team Visibility

As an **Employee**,
I want to create time entries against active projects and tasks,
So that my working hours are recorded accurately against the correct project for invoicing and reporting.

As a **Line Manager**,
I want to view time entries for all my direct reports,
So that I can monitor team utilization and validate billed hours.

**Acceptance Criteria:**

**Given** I am logged in as an Employee,
**When** I create a `TimeEntry` with `Project`, `StartDateTime`, `EndDateTime`, `Description`,
**Then** the record is saved with my `Employee.id` automatically set as the `Employee` FK.

**Given** I am logged in as an Employee,
**When** I call `GET /items/TimeEntry`,
**Then** only records where `Employee = my_employee_id` are returned.

**Given** I am logged in as a Line Manager,
**When** I call `GET /items/TimeEntry`,
**Then** only records where `Employee.ManagerId = my_employee_id` are returned.

**Given** I am logged in as an HR Manager,
**When** I call `GET /items/TimeEntry`,
**Then** all TimeEntry records are returned (HR has read-all access).

---

### Story 5.2: Leave Request Submission & Approval

As an **Employee**,
I want to submit a leave request specifying the type, start date, and end date,
So that my absence is formally recorded and routed to my manager for approval.

As a **Line Manager**,
I want to approve or reject leave requests from my direct reports,
So that the team calendar reflects confirmed absences and scheduling can be adjusted.

**Acceptance Criteria:**

**Given** I am logged in as an Employee,
**When** I create a `Leaves` record with `Type = "Annual"`, `StartDate = 2026-04-01`, `EndDate = 2026-04-05`,
**Then** the record is saved with my `Employee.id` as the `Employee` FK and is visible when I query my own leaves.

**Given** I am logged in as an Employee,
**When** I call `GET /items/Leaves`,
**Then** only my own leave records are returned.

**Given** I am logged in as a Line Manager,
**When** I call `GET /items/Leaves`,
**Then** only leave records for my direct reports are returned.

**Given** I am logged in as a Line Manager,
**When** I update a `Leaves` record to add a `Status` field value of `"Approved"`,
**Then** the update succeeds and the Employee can see the updated status on their record.

**Technical Notes:**
- `Leaves` table in the existing schema does not have a `Status` field — this story requires adding a `status` field to the Leaves table/collection in Directus (with values: `Pending`, `Approved`, `Rejected`). Confirm whether this requires a schema migration or Directus virtual field.

---

### Story 5.3: Task Assignment & Status Tracking

As a **Line Manager**,
I want to create tasks and assign them to team members with due dates,
So that I can track deliverables and ensure accountability for project-level work items.

As an **Employee**,
I want to update the status of tasks assigned to me,
So that my manager and HR have visibility into task progress without me needing Admin access.

**Acceptance Criteria:**

**Given** I am logged in as a Line Manager,
**When** I create a `Task` with `Name`, `Description`, `Status = "Open"`, `Project`, `DueDate`, `Employee = <direct_report_id>`,
**Then** the Task is saved and the assigned Employee can see it when they query `GET /items/Task`.

**Given** I am logged in as an Employee,
**When** I call `GET /items/Task`,
**Then** only tasks where `Employee = my_employee_id` are returned.

**Given** I am logged in as an Employee,
**When** I update a Task's `Status` field to `"In Progress"`,
**Then** the update succeeds.

**Given** I am logged in as an Employee,
**When** I attempt to update the `Employee` or `Project` field on a Task,
**Then** the API returns `403 Forbidden` (Employees can only update `Status`).

---

### Story 5.4: Employee spend (FR28) — `Transaction` / `Invoice` + `Journal`

As an **Employee**,
I want to submit spend (receipt, amount, currency, optional project, company vs personal payment) **in Directus**,
So that the system **immediately** creates the correct **`Transaction`** or **`Invoice`** and attaches receipts per **FR12**/**FR28**/**FR29** — **without** a canonical **`Expense`** row.

**Acceptance Criteria:**

**Given** I am logged in as an Employee with **`DefaultProjectId`** set (**FR22**),
**When** I run the **FR28** workflow with **company-paid** account and **no** duplicate “similar” **`Transaction`** exists (**Architecture** dedup rules),
**Then** a **`Transaction`** is created with **`Project`** = my selection **or** **`DefaultProjectId`**, and I can read it per **FR41**.

**Given** the same, but a **similar** **`Transaction`** **already** exists,
**Then** the flow **does not** create a second **`Transaction`** (Finance handles manually).

**Given** I submit as **paid personally**,
**When** the flow completes,
**Then** an **`Invoice`** (reimbursement / AP shape per **Architecture**) is created with **`Project`** = selection **or** **`DefaultProjectId`**.

**Given** I attach a receipt file,
**When** the flow completes,
**Then** a **`Journal`** row exists with **`JournalLink.collection`** ∈ {`Transaction`, `Invoice`}, **`JournalLink.item`** = created ledger row, **`document_file`** set — **FR29**.

**Given** Finance needs to contest a bad submission,
**Then** **`finance-manager`** can **edit/void** the **`Transaction`/`Invoice`** (no separate expense approval collection required for Phase 1).

**Technical Notes:**
- Implement with **Directus Flow** or extension (no Lovable required).
- **`Seniority`** day rate + **FR43** monthly **`InternalCost`** are separate stories; **FR25** **Active** project filter on **`TimeEntry`**.
- Deep-dive: **`_bmad-output/planning-artifacts/employee-time-expense-requirements-and-plan.md`**.

---

## Epic 6: Executive & Finance Insights Dashboards

**Goal:** Finance Managers can instantly see the audit completeness of the ledger via a live Completeness Score. **Executives** may use Insights for **UX**-scoped P&L **only** where **FR21**/**FR40** allow row access (often **empty** until Finance publishes aggregates — **FR20**). **Story 6.3** (**STUB**): **FR47** cash flow (**past `Transaction` + forward `Invoice`**; **no** **`BankStatement`**); Finance + Executive **same** dashboard definition (**FR47.1**); **NFR1**/**NFR13**-compliant org-wide reporting path per PRD.

---

### Story 6.1: Finance Completeness Score Dashboard

As a **Finance Manager**,
I want a Directus Insights dashboard that shows the percentage of `Transaction` records that have at least one linked `Journal` entry,
So that I can monitor audit evidence coverage and identify unlinked transactions that need documentation before the Monthly Close.

**Acceptance Criteria:**

**Given** I am logged in as a Finance Manager,
**When** I navigate to Directus Insights,
**Then** a panel labelled "Ledger Completeness Score" is visible showing a percentage value (e.g., "73% of Transactions have Journal evidence").

**Given** 10 Transaction records exist and 7 have at least one linked Journal entry,
**When** the dashboard loads,
**Then** the Completeness Score displays "70%".

**Given** a Finance Manager links a Journal entry to a previously unlinked Transaction,
**When** the dashboard is refreshed,
**Then** the Completeness Score updates to reflect the new count.

**Given** I am logged in as an HR Manager or Executive,
**When** I navigate to Directus Insights,
**Then** the "Ledger Completeness Score" panel is not visible (Finance-only dashboard).

**Technical Notes:**
- Implement as a Directus Insights panel with a custom query counting Transactions with at least one Journal entry (`SELECT COUNT(DISTINCT t.id) FROM "Transaction" t JOIN "Journal" j ON j."JournalLink.collection" = 'Transaction' AND j."JournalLink.item" = t.id`)
- Dashboard restricted to `finance-manager` role via Directus Insights permissions
- NFR5: must return within 5 seconds for typical monthly dataset

---

### Story 6.2: Executive Profit Center P&L Dashboard

As an **Executive**,
I want a Directus Insights dashboard showing my Profit Center's monthly and annual Profit/Loss figures,
So that I can make data-driven business decisions about my unit's financial performance without requiring a Finance Manager to generate a manual report.

**Acceptance Criteria:**

**Given** I am logged in as an Executive for `ProfitCenter = "APAC"` (**baseline** user — not Finance),
**When** I navigate to Directus Insights,
**Then** P&L panels **only** reflect rows I am **allowed** to read under **FR21**/**FR40** (typically **no** raw ledger — panels may show **empty** or non-sensitive aggregates unless policy grants more).

**Given** a panel is filtered by my assigned ProfitCenter,
**When** the underlying query runs,
**Then** **RLS and Directus RBAC** still apply — **no** bypass (**FR20**).

**Given** I am logged in as an Executive for a different ProfitCenter,
**When** I view the same dashboard layout,
**Then** default filters use **my** assigned ProfitCenter for **UX** only; **visibility** remains capped by **FR21**.

**Given** I am logged in as an HR Manager,
**When** I navigate to Directus Insights,
**Then** the P&L dashboard is not visible.

**Technical Notes:**
- Panels **must** use the same DB session / RLS path as Directus **`items.*`** — Executive sees **only** permitted rows (**FR20**, **FR21**, **NFR13**). If Executives lack ledger read, use **Finance-published** aggregate snapshots or **role-gated** materialized views in a later story.
- NFR5: panels must return within 5 seconds for typical monthly data volumes
- Consider adding a date-range filter control to the dashboard for flexible reporting

---

### Story 6.3 (STUB — refine later): Cash flow report (Directus Insights — FR47)

**Status:** **AC drafted** — implement SQL / Insights per **PRD FR47.8** (resolved 2026-03-16) + **Architecture** §10.5.

**PRD:** **FR47** (+ **FR20**/**FR21**/**NFR1**/**NFR13** for org-wide panel). **Reference:** `_bmad-output/reference/cashflow-looker-reports-legacy-source.md` (+ **PM corrections**). **Implementation artifact:** `_bmad-output/implementation-artifacts/6-3-finance-cash-flow-reporting-dashboard.md`.

**Placeholder intent (from FR47 / FR47.9):**
- **Directus Insights** first; **alternate** reporting tool **if** Insights lacks required **user** control (**FR47.9.4**).
- **`finance-manager`** + **`executive`** — **same** cash dashboard (**org-wide** — **FR47.1**); **NFR1**/**NFR13**.
- **Defaults:** **24m** past, **24m** forward, **monthly** grain; **user-adjustable** where supported (**FR47.9**).
- **Past:** **`Transaction`**; **exclude** **`BankStatement`**. **Forward:** **`Invoice`** Planned/Sent; **`DueDate`** + **FR47.7**.
- **Sign / Salary / recurrence:** **FR47.4–47.7** unchanged.

**Acceptance criteria:** **`6-3-finance-cash-flow-reporting-dashboard.md`** (includes spike + escape hatch).

**Technical notes:** **NFR5** applies. **Deferred:** **ProfitCenter owner** scoped slice (**Phase 2+**, **FR47.8**).

---

## Epic 7: Employee Self-Service Portal — **[DEFERRED — optional SPA track]**

> **PM 2026-03-17:** Phase 1 delivers employee outcomes via **Directus Admin + Epic 5** (PRD §5.13–5.14). The stories below are **preserved** for a **future** dedicated SPA (e.g. Lovable/Vite/React); **do not treat as Phase 1 scope** until this epic is re-opened.

**Goal (when / if built):** Employees use a mobile-friendly SPA to log time against smart-sorted active projects, confirm daily activity, submit leave requests, and upload expense receipts — **only** via the Directus REST API (no direct DB).

---

### Story 7.1: SPA scaffold with Directus authentication *(deferred)*

As an **Employee**,
I want to log in to a web portal with my Directus credentials and receive a session token that is used for all subsequent API calls,
So that I can securely access only my own data through a clean, mobile-friendly interface.

**Acceptance Criteria:**

**Given** I navigate to the employee SPA URL,
**When** I enter my Directus email and password and click "Login",
**Then** the SPA authenticates against `POST /auth/login` on the Directus API, receives an access token, and stores it in memory (not localStorage) for the session.

**Given** I am authenticated,
**When** any SPA page makes an API call,
**Then** the `Authorization: Bearer <token>` header is included in every request.

**Given** my session token expires,
**When** the SPA detects a `401 Unauthorized` response,
**Then** the SPA automatically attempts a token refresh via `POST /auth/refresh` before retrying the request.

**Given** I click "Logout",
**When** the action completes,
**Then** the token is invalidated via `POST /auth/logout`, the session is cleared, and I am redirected to the login screen.

**Technical Notes:**
- Scaffold in `projects/internal-erp/lovable-spa/` using Vite + React + Tailwind
- Use the official `@directus/sdk` TypeScript client
- Token storage: memory only (do not persist to localStorage for security)
- SPA communicates ONLY with Directus REST API — no direct DB connections

---

### Story 7.2: Active project list for time logging *(deferred)*

As an **Employee**,
I want the time logging screen to show only active projects, sorted with my Profit Center's projects first and then global projects by recent activity,
So that I can quickly find the right project without scrolling through irrelevant or inactive options.

**Acceptance Criteria:**

**Given** I am on the Time Logging screen,
**When** the project list loads,
**Then** only `Project` records where `Status = 'Active'` are displayed — inactive or archived projects are excluded.

**Given** my Directus user profile has assigned `profitCenter` matching **"APAC"** (from `directus_users` — **not** from `Employee.ProfitCenter`) and active Projects exist for both APAC and Global,
**When** the project list renders,
**Then** APAC projects appear at the top of the list, followed by Global/other projects.

**Given** two projects within the same group (e.g., both APAC),
**When** they are ordered within their group,
**Then** the project with the most recent `TimeEntry.StartDateTime` for any employee appears first.

**Given** no active projects exist for my user-assigned ProfitCenter,
**When** the project list loads,
**Then** I see all active global projects sorted by recent activity with an empty state message for "Your ProfitCenter projects".

**Technical Notes:**
- API call: `GET /items/Project?filter[Status][_eq]=Active&fields=id,Name,ProfitCenter.*`
- Client-side sort: (1) match `Project.ProfitCenter` to **`$CURRENT_USER.profitCenter`** (or equivalent from token/session — **never** `Employee.ProfitCenter`), (2) sort by most recent TimeEntry date from a secondary `GET /items/TimeEntry?filter[Project][_in]=<ids>&sort=-StartDateTime&limit=1&groupBy=Project`
- The Employee role's Directus permission scopes Project access to Active projects already

---

### Story 7.3: Daily confirmation sparkline *(deferred)*

As an **Employee**,
I want a "Daily Confirmation" view that shows yesterday's captured time entries as a sparkline timeline, with a single "Confirm All" button,
So that I can verify my ambient time tracking with one tap and avoid contextual drift in my logged hours.

**Acceptance Criteria:**

**Given** I open the SPA on a weekday,
**When** the Daily Confirmation screen loads,
**Then** I see all of my `TimeEntry` records from the previous calendar day rendered as a horizontal timeline/sparkline grouped by Project.

**Given** my previous day has 3 TimeEntry records totalling 7.5 hours,
**When** I tap "Confirm All",
**Then** each of the 3 TimeEntry records is updated with a `confirmed = true` flag (requires adding this field to TimeEntry) and a success toast notification appears.

**Given** I tap "Confirm All" and all entries update successfully,
**When** I navigate back to the Daily Confirmation screen,
**Then** the confirmed entries show a visual confirmed state (e.g., green checkmark) and the "Confirm All" button is replaced with "All Confirmed".

**Given** there are no time entries for the previous day,
**When** the Daily Confirmation screen loads,
**Then** an empty state message is shown: "No time entries found for yesterday. Log your time to get started."

**Technical Notes:**
- Requires adding a boolean `confirmed` field to the `TimeEntry` collection in Directus (schema migration needed)
- API: `GET /items/TimeEntry?filter[Employee][_eq]=<me>&filter[StartDateTime][_between]=<yesterday_start>,<yesterday_end>`
- Confirm action: `PATCH /items/TimeEntry/<id>` with `{ confirmed: true }` for each entry
- Sparkline rendered as a simple horizontal bar chart (no external chart library required — CSS-based is fine)

---

### Story 7.4: Leave request form *(deferred)*

As an **Employee**,
I want to submit a leave request from the SPA by selecting the leave type, start date, and end date, and view my current leave balance,
So that I can manage my time off without needing Directus Admin access or contacting HR directly.

**Acceptance Criteria:**

**Given** I navigate to the "Leaves" section of the SPA,
**When** the screen loads,
**Then** I see my previously submitted leave requests with their current status (`Pending`, `Approved`, `Rejected`).

**Given** I fill in a leave request form with `Type = "Annual"`, `StartDate = 2026-04-07`, `EndDate = 2026-04-11`,
**When** I submit the form,
**Then** a `POST /items/Leaves` call creates the record with my `employee_id` and the form shows a success confirmation.

**Given** the leave balance calculation: total `Approved` leave days in the current calendar year,
**When** the Leaves screen renders,
**Then** a summary shows "Used: X days | Remaining: Y days" based on approved Leaves records for the current year.

**Given** I submit a leave request with `EndDate` before `StartDate`,
**When** I click submit,
**Then** client-side validation prevents the submission and shows an error: "End date must be after start date".

**Technical Notes:**
- Leave balance is calculated client-side from `GET /items/Leaves?filter[Employee][_eq]=<me>&filter[Status][_eq]=Approved` — no server-side calculation needed in Phase 1
- Annual leave allowance (e.g., 20 days) is a configuration constant in the SPA for Phase 1; dynamic config via Directus settings is a future enhancement

---

### Story 7.5: Employee spend UI *(deferred — must mirror FR28)*

> **If** a future SPA is built, it **SHALL NOT** use a canonical **`Expense`** collection. **Mirror PRD FR28/FR29:** `POST` / Flow-equivalent creates **`Transaction` or `Invoice`**, then **`Journal`** with **`JournalLink.collection`** ∈ {`Transaction`, `Invoice`}.

As an **Employee**,
I want to submit spend with a receipt from the SPA,
So that Finance sees the same ledger objects as **Directus FR28**.

**Acceptance Criteria:** *Deferred — define when Epic 7 reopens; align with **`employee-time-expense-requirements-and-plan.md`***.

**Technical Notes:**
- File upload: `POST /files`, then **`Journal`** linked to created **`Transaction`/`Invoice`** (**FR12**)
- Use Directus `@directus/sdk` or call the same backend Flow the Admin UI uses

