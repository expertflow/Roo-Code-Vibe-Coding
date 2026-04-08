---
stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8]
inputDocuments:
  - projects/internal-erp/vision.md
  - docs/governance.md
  - projects/internal-erp/STTMMappingBidstruct4 (1).xlsx
  - schema_dump_final.json
  - _bmad-output/planning-artifacts/prd-ExpertflowInternalERP-2026-03-16.md
  - _bmad-output/planning-artifacts/identity-provider.md
  - _bmad-output/planning-artifacts/data-admin-surface-requirements.md
workflowType: 'architecture'
project_name: 'BMADMonorepoEFInternalTools'
user_name: 'Andreas'
date: '2026-03-16'
---


# Architecture Decision Document

> **Note:** Please verify against `antigravity-implementation-history.md` for alternative implemented methodologies (e.g., *HR Data Architecture*, *Strict CRUD Enforcement*), as previous Antigravity session plans may supersede or contradict these requirements.

_This document builds collaboratively through step-by-step discovery. Sections are appended as we work through each architectural decision together._

## 1. Project Context Analysis

### 1.1 Requirements Summary
**Functional Focus**: Decoupled financial ledger management and ambient HR time-tracking.
**Security Focus**: Financial sensitivity driven by **`LegalEntity.Type`** on records reached via **`Account` → `LegalEntity`**; collection-level blacklisting for non-finance roles. **`Employee.DefaultProjectId`** is **not** a visibility control (time/cost default only); **`Employee.ProfitCenter`** is not used in Phase 1 product surface.

### 1.2 Scale & Complexity Indicators
- **Data Domain**: 42 Existing Tables in `bidstruct4` requiring Directus mapping.
- **Complexity Level**: Medium-High (due to security constraints).
- **Primary Domain**: Backend API + Admin Orchestration.

### 1.3 Technical Constraints & Dependencies
- **Database**: PostgreSQL (`bidstruct4`) at `localhost:5432` via Cloud SQL Proxy.
- **Deduplication**: Collision-resistant **atomic-line** key (**PRD FR8**): `AccountID` + `Date` + `Amount` + normalized `Description` + `BankTransactionID` (in hash when present); **`BankTransactionID` may repeat** per account.
- **Relationship** (**PRD FR6/FR10**): **`BankStatement.Transaction` MAY be NULL** at import; **reconciliation** sets it to exactly one **`Transaction`**. A **`Transaction`** may be referenced by **zero, one, or two** **`BankStatement`** rows (second leg links to an **existing** `Transaction` when appropriate); **no** `Transaction.BankStatementId` FK; Hook rejects a third link attempt. Linking **`Transaction`** to **`Invoice`** is **optional** via **`Allocation`**.

## 2. Starter Template Evaluation

### 2.1 Primary Technology Domain
**API/Backend & Admin**: Directus (Node.js / Headless CMS)
**Phase 1 user-facing layer**: **Directus Admin UI** + **in-repo Directus extensions** (modules, interfaces, hooks) — **speed path; single deployable.**  
**Deferred (optional)**: Dedicated employee SPA (historically discussed as Lovable or monorepo Vite/React) — same Directus REST API; not required for Phase 1.

### 2.2 Selected Starter: Directus v11.16.0 (Dockerized — Google Cloud)
**Rationale**: 
- **Zero Licensing Cost**: Satisfies the governance requirement to avoid per-user fees.
- **Schema-First**: Perfectly wraps the existing `bidstruct4` PostgreSQL schema with minimal configuration.
- **Google Cloud Native**: Directus runs as a Docker container deployed to **Google Cloud Run**. Local development uses the same Docker image via `docker compose`, ensuring 100% environment parity with production.

**Interim / shared-access path (BMAD-documented, does not change ADR-10):** Until **Cloud Run** is the live production surface, the repo may use **Compute Engine VM + Docker Compose** with a **Cloud SQL Auth Proxy** container on the same Docker network — same **Dockerfile** as local, **Secret Manager** and **`PUBLIC_URL` / OAuth** rules unchanged. Runbook: **`projects/internal-erp/directus/docs/gcp-directus-deployment.md`**. Cross-reference: Epic 1 **Story 1.1** artifact and **`migration-plan-postgres-directus-cloud-wave1.md`** Wave 0.

### 2.3 Architectural Foundations Provided
- **Language**: TypeScript (Node.js runtime).
- **Styling**: Directus extension defaults; Tailwind only if an extension bundle requires it.
- **Build Tooling**: Docker (Deployment); extension bundling per Directus conventions.
- **Database**: Native PostgreSQL integration.

### 2.4 Integration Pattern (Phase 1 — Directus-centric)
- **Primary tier**: **Directus Admin UI** for Finance, HR, Executive, **and Employee** self-service (RBAC-scoped collections). Mobile receipt capture uses standard file fields and/or a **small extension** — no second app platform.
- **Extensions tier**: **Directus extensions** in `projects/internal-erp/directus/extensions/` for hooks, custom interfaces, or module pages when Admin alone is insufficient.
- **Communication layer**: All surfaces use the **Directus REST API** only (NFR1 / Zero-Trust).
- **Deferred tier**: Optional **separate employee SPA** (e.g. Lovable) if UX feedback demands it later; not part of Phase 1 velocity goals (PRD §1, §5.13–5.14).

## 3. Specific Architectural Decisions

### 3.1 Database Connectivity & Secret Management (ADR)
**Decision**: Use persistent **Cloud SQL Auth Proxy** for local development, combined with strict `.env` file segregation and Secret Manager integration for handling database credentials.

**Context & Problem**:
Development must occur against the real production schema (`bidstruct4`) to avoid environmental drift. However, doing so requires securely handling sensitive credentials (passwords, connection strings) across the team and during AI-assisted development sessions ("Vibecoding"). 

**Option Chosen (Option B Modified)**:
Every development environment will use `cloud-sql-proxy` to securely connect to the Google Cloud SQL instance at `127.0.0.1:5432`. This ensures 100% environment parity.

**Secret Management Constraints (Vibecoding Guardrails)**:
To ensure passwords are never stored in trackable files or passed directly in chat:
1. **Strict Local Isolation**: All database credentials (`DB_PASSWORD`, `SECRET`, `KEY`) must be stored exclusively in local `.env` files.
2. **Repository Exclusion**: The `.env` template file (and any variations like `.env.local`) will be strictly ignored via `.gitignore`.
3. **Environment Injection**: Start scripts (`start-dev.sh`, `docker-compose.yml`) must read from the `.env` file directly. Passwords will never be hardcoded as script arguments.
4. **Production Standard**: For the deployed environment (Google Cloud Run), credentials will be mounted natively via **Google Cloud Secret Manager**, never exposed in plain text within environment variables.

### 3.2 User identity — external OIDC/OAuth IdP (production)

**Decision (ADR-12):** In **production**, **human users** authenticate to **Directus** only via an **external OIDC/OAuth identity provider** defined in **`identity-provider.md`** (canonical spec). **Do not** duplicate vendor names, issuer URLs, or OAuth client setup in this Architecture document — change IdP only by editing **`identity-provider.md`** § *Current configuration* and re-running **Story 1.8**.

**Contract:**
- IdP supplies **verified email**; Directus links/creates `directus_users`; PostgreSQL RLS uses the same email via `app.user_email`; **`UserToRole.User`** MUST match (see **`identity-provider.md`** contract table).
- **Domain-trusted JIT:** Allowlisted domains (e.g. **`expertflow.com`** in **`identity-provider.md`**) MUST support **first SSO login without manual `directus_users` creation**; default Directus role for new users per that file until Epic 2 RBAC.
- **Local / break-glass:** per **`identity-provider.md`** and PRD **NFR12**.

**Rationale:** Single document for IdP churn; PRD **NFR12** remains stable when the vendor changes.

---

## 4. Directus Collection & Relationship Configuration (ADR)

### 4.1 Collection Registration Strategy

**Decision**: All 42 tables in `bidstruct4` will be registered as Directus collections using the **Directus Schema Snapshot** approach. Changes are tracked as `schema.json` in version control and applied via `directus schema apply`.

**Phasing**: Phase 1 activates and fully configures the 29 in-scope collections. The remaining 13 (CPQ, AI tools, ticketing, TestDebug) will be registered as hidden/inactive to prevent accidental access.

**Field Interface Mapping**:

| PostgreSQL Type | Directus Interface |
|---|---|
| `integer` (FK) | `m2o` relational select |
| `text` | `input` (single-line) or `textarea` |
| `numeric` | `input-decimal` |
| `date` | `datetime` |
| `boolean` | `toggle` |
| `interval` | `input` (stored as ISO 8601 duration string) |
| `USER-DEFINED` (enum) | `select-dropdown` (values defined in field config) |
| `jsonb` | `input-code` (JSON editor) |
| `uuid` | `input` (read-only, system-generated) |
| `character varying` | `input` |

### 4.2 Relationship Configuration

All relationships below are configured as Directus relational fields using the existing FK structure from `schema_dump_final.json`. No schema modifications to `bidstruct4` are required.

**BankStatement ↔ Transaction** (**PRD FR6–FR10, 2026-03-17**):
- **`BankStatement.Transaction` MAY be NULL** on import create; reconciliation sets the FK (ADR-05). On update, when `Transaction` is non-null, **cap** rules apply. **Deduplication** runs on `action: items.create` for `BankStatement` (**atomic-line** key per **FR7**/**FR8** — not `Account + BankTransactionID` alone). **Cap** runs whenever `Transaction` is set: at most **two** `BankStatement` rows per `Transaction`.
- **Association paths** (create or change `BankStatement.Transaction`):
  - **Option A** — Select an existing Transaction within the **reconciliation match window**: **±3 working days** of BankStatement `Date` (weekends excluded) and **±5%** of BankStatement `Amount` (same currency only in Phase 1).
  - **Option B** — Select an existing Invoice within the same window; the system creates a new Transaction pre-populated from Invoice data, then links the BankStatement.
  - **Option C** — Create a new Transaction, pre-populated using sign logic: `Amount > 0` (credit) → `Transaction.DestinationAccount = BankStatement.Account`; `Amount < 0` (debit) → `Transaction.OriginAccount = BankStatement.Account`.
- A Transaction may be referenced by **zero, one, or two** BankStatement rows (zero = ledger-only Transaction with no bank mirror yet). A third link attempt is rejected.
- **`BankStatement` narrative fields (PRD FR46.1):** Schema / Directus **SHALL** expose up to **four** description-line fields for multi-column bank exports; FR8 fallback hash **SHALL** include whichever fields exist for that row.
- **Deduplication Hook** (`action: items.create` on `BankStatement`): rejects duplicate **atomic lines** (full **FR8** key); **`BankTransactionID` informational**, may repeat. Implemented in `extensions/hooks/bank-statement-dedup/`.
- **Cap Hook** (`action: items.update` on `BankStatement`, and `action: items.create` on `BankStatement`): validate **`Transaction` present** and count existing `BankStatement` rows for that Transaction (excluding current row on update); reject if count ≥ 2. Implemented in `extensions/hooks/bank-statement-limit/`.

**Bank statement import (Story 3-1, ADR-16):** Finance operators upload a file, select **`Account`** (house bank), then **Import**. A **registry** maps `Account` id → **Python** parser module (~12 layouts). A **Directus extension** (or endpoint) runs the parser under a **hardened subprocess** (no shell, timeouts, temp-dir cleanup, upload size limits) and **`POST`s** normalized rows as the authenticated Finance user so **RLS** and **hooks** apply identically to manual entry. **Generic deduplication** remains the **`items.create`** hook on `BankStatement`; parsers do not embed dedup logic.

**Dedup key (PRD FR7/FR8, 2026-03-26):** **`BankTransactionID`** is **informational**; **multiple `BankStatement` rows MAY share the same `Account` + `BankTransactionID`**. The create hook rejects duplicates by an **atomic-line** key: **`Account` + `Date` + `Amount` + normalized merged `Description` (+ `BankTransactionID` in the hash input)** — exact normalization in hook implementation / story tests. **Do not** enforce **`UNIQUE (Account, BankTransactionID)`** in PostgreSQL for this product rule. *Example (UBS CSV):* drop batch **summary** rows; import only **atomic** lines; **footnotes** column omitted from stored narrative if Finance policy says so.

**Journal Polymorphic Pattern**:
- `JournalLink.collection` (text) + `JournalLink.item` (integer) implement a M2A JournalLink junction pattern.
- Directus does not natively support polymorphic M2O. Implementation: a Directus **Custom Interface** extension provides a UI picker that first selects the reference type (dropdown of collection names), then an item picker for that collection. Backend validation via Hook ensures `JournalLink.collection` is a valid collection name.

**`LegalEntity.DocumentFolder` (PRD FR12):** Retain as **canonical** — URL to the **default organization-level document folder** (e.g. GDrive/GCS). This is **not** per-row evidence; integrations and operators use it as a **storage root**. **Per-object** files remain **`Journal`** rows linked to the specific parent.

### 4.3 Display Templates

| Collection | Display Template |
|---|---|
| `Employee` | `{{EmployeeName}} ({{email}})` |
| `Project` | `{{Name}} — {{Status}}` |
| `Account` | `{{Name}} [{{LegalEntity.Name}}]` |
| `Invoice` | `INV-{{id}} · {{Amount}} {{Currency.CurrencyCode}}` |
| `Transaction` | `TXN-{{id}} · {{Amount}} · {{Date}}` |
| `LegalEntity` | `{{Name}} ({{Type}})` |
| `Currency` | `{{CurrencyCode}} — {{Name}}` |

### 4.4 Relational field presentation — Directus binding (ADR-14)

**Product-agnostic contract:** **`data-admin-surface-requirements.md`** is the **single canonical** BMAD specification for **human-readable references** in **any** internal data-administration UI (lists, detail views, pickers). It is **not** Directus-specific; swapping Directus for another admin product **does not** remove that contract — only this **Directus binding** section is replaced.

**Decision (ADR-14):** Phase 1 implements **`data-admin-surface-requirements.md`** §§1–2 using **Directus** as follows.

**Directus implementation rules (non-negotiable for implementation agents):**

1. **Relation shape:** Each FK MUST have a Directus **relation row** plus an m2o-type **interface** (prefer **`select-dropdown-m2o`** in Directus 11.x) and **`special` includes `m2o`**. Plain `input` on an integer FK is **forbidden** for in-scope collections (it surfaces raw IDs in item views). Legacy **`interface: m2o`** alone is treated as non-compliant; upgrade to **`select-dropdown-m2o`** via repo scripts.
2. **Templates (three places kept in sync):**
   - **`meta.options.template`** — M2O picker / search
   - **`meta.display`:** `related-values`
   - **`meta.display_options.template`** — same string as the picker (list rows, item layout, previews)
3. **Collection display templates:** §4.3 table + per-collection labels; extended mappings live in repo **`projects/internal-erp/directus/scripts/lib/collection-display-templates.mjs`**.
4. **Automation:** After **any** change that adds or alters FKs, relations, or Directus field metadata, run (or extend and re-run):

   `node projects/internal-erp/directus/scripts/apply-m2o-dropdown-templates.mjs`

   Use **`--force`** on that script to re-PATCH every relation-backed FK when item/detail views still show raw PKs while metadata appears correct (see **`projects/internal-erp/directus/README.md`** Story 1.5).

   Story-specific metadata also uses **`lib/m2o-readable-meta.mjs`** via **`apply-story-1-2-financial-meta.mjs`** and **`apply-story-1-3-org-hr-meta.mjs`**. See **`projects/internal-erp/directus/README.md`** (Epic 1 **Story 1.1–1.10** in numeric order; PM delivery order may differ — epic *Implementation sequencing*).

**Rationale:** Stated in **`data-admin-surface-requirements.md`** (operator safety, auditability).

**Note:** **REST API** behavior vs **Admin UI** is split per **`data-admin-surface-requirements.md`** §1 **R4**.

---

## 5. RBAC Architecture (ADR)

### 5.1 Role Design

**Decision**: Five Directus roles are created. The legacy `Role`, `RolePermissions`, and `UserToRole` PostgreSQL tables are **actively used by PostgreSQL RLS policies** (defense-in-depth per ADR-13/NFR13) **and** serve as reference data. Directus RBAC is the **primary UX-layer** enforcement; PostgreSQL RLS is the **database-layer backstop**. Both must agree; neither alone is sufficient.

| Directus Role | Admin Panel Access | IP Restrictions |
|---|---|---|
| `finance-manager` | Full Admin UI | Internal network only (future) |
| `executive` | Read-only dashboards | Internal network only |
| `hr-manager` | Admin UI (HR collections only) | Internal network only |
| `line-manager` | Admin UI (team view only) | Internal network only |
| `employee` | **Directus Admin** (Phase 1 speed path — **app access enabled**, permissions limit visible collections) **and/or** extension module pages | Internal network only (recommended); align with org policy |

### 5.2 Permission Matrix

| Collection | finance-manager | executive | hr-manager | line-manager | employee |
|---|---|---|---|---|---|
| `Account` | CRUD | — | R (Employee LE only) | R (subord. payroll **`Invoice`** path — **FR40**) | — |
| `BankStatement` | CRUD | — | — | — | — |
| `Transaction` | CRUD | **—** | R (Employee LE only) | R (subord. payroll **`Invoice`** path — **FR40**) | — |
| `Invoice` | CRUD | **—** | R (Employee LE only) | R (subord. payroll **`Invoice`** — **FR40**) | — |
| `Allocation` | CRUD | — | — | — | — |
| `Accruals` | CRUD | — | — | — | — |
| `Journal` | CRUD | — | — | — | — |
| `CurrencyExchange` | CRUD | — | — | — | — |
| `Currency` | CRUD | R | R | R | R |
| `Project` | CRUD | R (same as employee) | R | R (own team) | R (active, scoped) |
| `LegalEntity` | CRUD | R | R | — | — |
| `ProfitCenter` | CRUD | R | R | — | — |
| `Employee` | R | R (own / same as employee) | CRUD (all rows) | R (own team) | R (own record) |
| `EmployeePersonalInfo` | — | R (own) | CRUD | R (own team — ops / leave; **not** payroll — payroll is **`Invoice`**) | R (own) |
| `TimeEntry` | R | — | R | R (own team) | CRUD (own) |
| `Leaves` | R | — | CRUD | RU (own team) | CR (own) |
| `Task` | R | — | R | CRUD (own team) | RU (own) |
| `Expense` | — | — | — | — | — *(legacy / non-canonical — **hide** or read-only; **FR28** replaces)* |
| `InternalCost` | CRUD | — | — | — | — |
| `Seniority` | CRUD | — | CRUD | R | R |
| `Designation` | CRUD | — | CRUD | R | R |
| `department` | CRUD | — | CRUD | R | R |
| `Contact` | CRUD | R | R | — | — |
| `Company` | CRUD | R | — | — | — |
| `CountryLocation` | CRUD | R | R | — | — |

### 5.3 Item-Level Permission Filters

The following item-level filter conditions are configured in Directus permissions:

**Executive** — **FR21 / FR40** (**same as `employee`** for sensitive data — **no** separate RLS tier):

- **No** blanket read on `Transaction`, `Invoice`, `Allocation`, `Accruals`, `InternalCost`, or unrestricted `Journal`.
- Use the **same** Directus collection permissions and item-level filters as **`employee`** unless the user also holds **`line-manager`**, **`hr-manager`**, or **`finance-manager`**.
- **Insights (FR20):** dashboard queries **must** respect RLS — **no** bypass.

**Line manager — subordinate payroll `Invoice` (FR33/FR40):** **Payroll** is **recurring `Invoice`** on **`LegalEntity.Type` ∈ {`Employee`, `Executive`}** accounts (BS4); **no** second datastore for payroll. In addition to team `TimeEntry` / `Leaves` / `Task` filters, **`line-manager`** receives **read** on **subordinates’ payroll-related recurring `Invoice` rows** and on **ledger rows** the schema story links to those invoices (e.g. **`Transaction`**, **`BankStatement`**, **`Journal`**) — reporting tree via **`Employee` → `Manager`** (**FR22**; DB column may be **`ManagerId`**), **recursive** where PRD requires. **`Employee` / `EmployeePersonalInfo`**: team **operational** read only; **not** a parallel payroll field path outside **`Invoice`**. **Does not** grant Executive-ledger (`LegalEntity.Type = 'Executive'`) access.

**HR Manager** (on `Employee`):
- **No item-level filter** — full CRUD on all `Employee` rows. **`Employee.DefaultProjectId`** is **operational only** (time/cost default). **`Employee.ProfitCenter`** hidden from collection UI (Phase 1).

**HR terminology:** what people call **“salary”** maps to **recurring `Invoice`** (contract) plus **`Transaction`** (disbursement), **`BankStatement`** (transfer proof), and **`Accruals`** when pay/recognition is delayed — all **RLS-governed**; **`Accruals`** is **Finance-only** (no HR read). Full chain in PRD **§4.4**. Surface in Directus **`Invoice`** notes / training.

**HR Manager** (read on `Account`, `BankStatement`, `Transaction`, `Invoice`) — **FR33 / FR40**:
- **`Account`** — only rows where `LegalEntity.Type = 'Employee'`:
```json
{ "LegalEntity": { "Type": { "_eq": "Employee" } } }
```
- **`BankStatement`** — `Account` resolves to Employee ledger:
```json
{ "Account": { "LegalEntity": { "Type": { "_eq": "Employee" } } } }
```
- **`Transaction`** and **`Invoice`** — **either** leg Employee, **no** leg Executive:
```json
{
  "_and": [
    { "_or": [
      { "OriginAccount": { "LegalEntity": { "Type": { "_eq": "Employee" } } } },
      { "DestinationAccount": { "LegalEntity": { "Type": { "_eq": "Employee" } } } }
    ]},
    { "OriginAccount": { "LegalEntity": { "Type": { "_neq": "Executive" } } } },
    { "DestinationAccount": { "LegalEntity": { "Type": { "_neq": "Executive" } } } }
  ]
}
```

**Financial visibility — `LegalEntity.Type` (PRD FR40 — four RLS tiers)**

`LegalEntity.Type` canonical values: **`Employee`**, **`Executive`**, **`Internal`**, **`Client`**, **`Partner`**, **`Supplier`**.

| Collection | Who may read | Path | Notes |
|---|---|---|---|
| `Account` | `finance-manager` (unrestricted); `hr-manager` (Employee LE only); `line-manager` (subord. payroll **`Invoice`** path only) | Direct `LegalEntity` M2O | No **`executive`** tier |
| `BankStatement` | same as `Account` | `Account` → `LegalEntity` | |
| `Transaction` | `finance-manager` (unrestricted); `hr-manager` (either leg Employee, no leg Executive); `line-manager` (linked to subord. payroll **`Invoice`** only) | `OriginAccount` / `DestinationAccount` → `LegalEntity` | RLS story aligns `policy_hr` + **manager** policies |
| `Invoice` | same as `Transaction` | same as `Transaction` | |
| `Allocation` / `Accruals` / `Journal` / `CurrencyExchange` | `finance-manager` only (FR41); **`CurrencyExchange`** read MAY extend per FR19 | N/A | |

**Baseline** (`employee` **and** `executive` without other roles): **zero** read on amount-bearing financial collections except where **FR41** allows own **`Expense`** journals.

**PostgreSQL `public` / Default role (RLS)** — users mapped neither Finance nor HR in `UserToRole`: `SELECT` on `Transaction`, `Invoice`, and `Allocation` is allowed only when **neither** `OriginAccount` **nor** `DestinationAccount` resolves to `LegalEntity.Type` **`Employee`** or **`Executive`** (equivalently: **exclude** the row if **either** leg is Employee or Executive). Single-account tables (`Account`, `BankStatement`): exclude if that account’s `LegalEntity` is Employee or Executive. Legacy policies that checked only one FK must be updated (PRD FR40, NFR13).

**Forbidden:** using `Employee.DefaultProjectId`, `Employee.ProfitCenter`, or joins through `Employee` for **ledger** visibility.

**Finance Manager:** no `LegalEntity.Type` item-level filter (full access). **`Journal`**, **`Allocation`**, **`Accruals`**, **`CurrencyExchange`**: Finance Manager only (PRD FR41).

**Employee** (on `TimeEntry`, `Leaves`, `Task`):
```json
{ "Employee": { "_eq": "$CURRENT_USER.employee_id" } }
```
*(**FR28** ledger rows: item filters per **FR41** / attribution — not this generic template.)*

**Line Manager** (on `TimeEntry`, `Leaves`, `Task`):
```json
{ "Employee": { "ManagerId": { "_eq": "$CURRENT_USER.employee_id" } } }
```

### 5.4 Collection Visibility (Navigation Hiding)

Collections **hidden** from Admin UI for **hr-manager** (Finance Manager has full navigation to configure):
- `Accruals`, `Allocation`, `CurrencyExchange`, `Journal` — **finance-manager** only (PRD FR41)

**hr-manager** **may** see `Account`, `BankStatement`, `Transaction`, `Invoice` in navigation **read-only**, subject to FR33 filters (Employee-ledger rows only).

Collections visible to **`Administrator`** system role only:
- `RolePermissions`, `UserToRole`, `Role`

---

## 6. Project Structure (ADR)

### 6.1 Monorepo Layout

**Decision**: The existing monorepo at `D:/VibeCode/BMADMonorepoEFInternalTools` will adopt the following structure for the ERP project:

```
/
├── projects/
│   └── internal-erp/
│       ├── directus/                  # Directus backend configuration
│       │   ├── docker-compose.yml
│       │   ├── .env.example           # Template (no secrets, committed)
│       │   ├── schema.json            # Directus schema snapshot (versioned)
│       │   ├── extensions/
│       │   │   └── hooks/
│       │   │       ├── bank-statement-dedup/   # import-time deduplication (create only)
│       │   │       └── bank-statement-limit/   # 0–2 BankStatements per Transaction (cap)
│       │   └── uploads/               # Directus file storage (gitignored)
│       └── lovable-spa/               # (Optional / deferred) Employee SPA — not required Phase 1
├── docs/
│   └── governance.md
├── schema_dump_final.json             # Source of truth for existing schema
└── _bmad-output/
    └── planning-artifacts/
```

### 6.2 Environment Configuration

**`.env.example`** (committed to repo, no secrets):
```env
DB_HOST=127.0.0.1
DB_PORT=5432
DB_DATABASE=bidstruct4
DB_USER=directus
DB_PASSWORD=              # Set locally — NEVER commit actual value
SECRET=                   # Random 32-char string — NEVER commit
KEY=                      # Random 32-char string — NEVER commit
DIRECTUS_URL=http://localhost:8055
```

**Production** (Google Cloud Run): all values injected via Secret Manager at deploy time. Docker image contains no credentials.

---

## 7. Deployment Architecture (ADR)

### 7.1 Local Development

```
Developer Machine
├── cloud-sql-proxy (sidecar)     → Cloud SQL (bidstruct4 @ GCP)
│   └── Listens on 127.0.0.1:5432
└── docker compose up
    ├── directus:11.x              → port 8055
    │   └── connects to 127.0.0.1:5432 via host.docker.internal
    └── (optional) redis           → port 6379 (for Directus cache, if needed)
```

### 7.2 Production (Google Cloud)

```
Google Cloud Run
├── Directus container (main)
│   ├── Env vars injected from Secret Manager
│   └── User login (production): External IdP (`identity-provider.md`) → OIDC/OAuth → Directus (NFR12)
└── Cloud SQL Auth Proxy (sidecar)
    └── Connects to Cloud SQL (bidstruct4)

Google Cloud Storage            → Directus file uploads bucket
Google Cloud Secret Manager     → DB_PASSWORD, SECRET, KEY, OAuth client secrets (SSO)
Google Cloud Artifact Registry  → Directus Docker image
External IdP (see `identity-provider.md`) → Staff authentication (production)
```

**Rationale**: Cloud Run provides serverless horizontal scaling with zero idle cost. The Cloud SQL Auth Proxy sidecar eliminates VPC peering complexity and provides IAM-based authentication to the database.

---

## 8. PostgreSQL RLS — Defense-in-Depth (ADR-13)

### 8.1 Mechanism

**Two PostgreSQL logins (defense-in-depth for RLS):**

| Role | Use | RLS |
|------|-----|-----|
| **`sterile_dev`** | **Directus runtime** (`DB_USER` in `.env`) | **No** `policy_owner_access_*` — not listed on those policies (they are `TO bs4_dev` only). With `FORCE ROW LEVEL SECURITY` on the 12 protected tables, ERP row visibility follows **`TO PUBLIC`** / Finance / HR policies and **`app.user_email`** + **`UserToRole`**. |
| **`bs4_dev`** | **Break-glass / migrations / DBA / psql** (not Directus in production) | Has blanket **`policy_owner_access_*`** (`USING (true)`) on RLS-enabled tables so unscoped work still succeeds when no per-user context is set. |

Directus MUST connect as **`sterile_dev`** (or another runtime user with the same grant pattern — **not** `bs4_dev`) so that a missing or broken extension does **not** silently grant full ERP row visibility via owner-access policies.

For **authenticated user** access to **collection data** (`items.*` API path), a **custom Directus extension** MUST apply **the same RLS context for every logged-in user, including Directus Administrators** (PM decision — no admin bypass for ERP row visibility):

1. Read the authenticated user's **email** from `directus_users` (SSO or local auth — normalized per **`identity-provider.md`**)
2. Issue `SET LOCAL ROLE <RLS_SESSION_ROLE>;` (default **`directus_rls_subject`**, env **`RLS_SESSION_ROLE`**) — **not** `public` (that name is not a PostgreSQL role). The session uses a dedicated **NOLOGIN** role **granted to `sterile_dev`** (and optionally `bs4_dev` for tooling); RLS policies written **`TO PUBLIC`** then apply. Bootstrap: `projects/internal-erp/directus/docs/sql/create-rls-session-role.sql`. Runtime grants: **`projects/internal-erp/directus/docs/sql/setup-sterile-dev.sql`**.
3. Issue `SET LOCAL app.user_email = '<email>';` (or `set_config(..., true)`) — RLS policies read via `current_setting('app.user_email', true)`
4. At transaction end (commit/rollback), `SET LOCAL` automatically resets — no cleanup needed

**When the extension does not run** on a connection as **`sterile_dev`**, there is **no** owner-access pass-through for ERP tables — row access is whatever the remaining policies allow (typically **no** sensitive financial rows without Finance/HR + `UserToRole`). **Internal/system** traffic that truly requires full visibility should use **`bs4_dev`** (or superuser) deliberately, not the Directus pool user.

**Operational note:** `bs4_dev` retains owner-access policies for migrations, one-off SQL, and emergency access; it MUST NOT be configured as Directus `DB_USER` in environments where PostgreSQL RLS is the authoritative ERP row gate.

### 8.2 RLS-Protected Tables (12)

| Table | RLS Logic | PG Roles Checked |
|-------|-----------|-----------------|
| `Account` | Open select; Finance/HR CRUD via `UserToRole` + `auth_crud()` | Finance, HR |
| `BankStatement` | **Finance-only (ADR-16):** app roles with Finance tier (`UserToRole` / role **115**) — full CRUD as policies allow; **no** HR or line-manager **`SELECT`** on bank lines in Phase 1 import track. Public/baseline: exclude sensitive legs as for other finance tables. Break-glass **`bs4_dev`** unchanged. | Finance |
| `Transaction` | Finance: full; HR: either leg Employee, no leg Executive; Line manager: subordinate-linked rows only (story); Public: exclude if **either** leg is `Employee` or `Executive` | Finance, HR, (+ manager) |
| `Invoice` | Same pattern as `Transaction` (both legs) | Finance, HR, (+ manager) |
| `Allocation` | Finance: full; HR: DestinationAccount Employee only; Public: exclude if **either** leg is `Employee` or `Executive` | Finance, HR |
| `Accruals` | Finance: full (no HR/public write policies for sensitive rows) | Finance |
| `Journal` | Finance: full | Finance |
| `Employee` | HR: full CRUD; Public: no access | HR |
| `LegalEntity` | Open select; CRUD via `auth_crud()` | (all via function) |
| `Role` | Open select; owner access | (admin) |
| `RolePermissions` | Open select; owner access | (admin) |
| `UserToRole` | Open select; owner access | (admin) |

### 8.3 Tables to Remove RLS From (10)

These do not contain sensitive data; access control is Directus RBAC only:

`Currency`, `CurrencyExchange`, `ProfitCenter`, `Project`, `Seniority`, `CountryLocation`, `Company`, `Contact`, `Deal`, `TestDebug`

**Action:** `ALTER TABLE "BS4Prod09Feb2026"."<table>" DISABLE ROW LEVEL SECURITY;` and drop associated policies. This should be a story task (Epic 1 or Epic 2).

### 8.4 PostgreSQL Role Table (live security data)

| id | Name | Purpose |
|----|------|---------|
| 115 | Finance | Full financial access; RLS grants unrestricted CRUD on all financial tables |
| 116 | HR | Employee-ledger access; RLS restricts to `LegalEntity.Type = 'Employee'` rows |
| 117 | Default | Baseline; public read **excludes** any amount-bearing row where **any** account leg is `Employee` or `Executive` (both FKs on `Transaction`/`Invoice`/`Allocation`) |
| 118 | Line Manager *(optional / story)* | Extends baseline with **SELECT** on subordinate **payroll recurring `Invoice`** (and linked ledger rows) per **FR40** — implement via RLS + `UserToRole` or `ManagerId` subtree predicates |

**`UserToRole`** maps **IdP-verified user emails** (see **`identity-provider.md`**) to these roles. Both Directus RBAC roles and PostgreSQL `UserToRole` entries must be maintained for each user. **`executive`** is **not** a PostgreSQL RLS tier — map Executives to **117** (or equivalent) unless they are also Finance (**115**) or HR (**116**).

### 8.5 `auth_crud()` Function

Existing PostgreSQL function `BS4Prod09Feb2026.auth_crud(table_name, operation)` checks `RolePermissions.AccessCondition` + CRUD booleans for write operations. Retained as-is; Directus RBAC provides the primary CRUD gate, `auth_crud()` is the backstop.

---

## 9. Architecture Decisions Summary

| # | Decision | Rationale |
|---|---|---|
| ADR-01 | Directus v11 OSS (self-hosted, Docker) | Zero per-user licensing; native PostgreSQL; AI-legible REST API |
| ADR-02 | Cloud SQL Auth Proxy for all DB connectivity | Environment parity; no credential exposure; IAM auth |
| ADR-03 | `.env` file isolation + Secret Manager in prod | Vibecoding safety; secrets never in repo or chat |
| ADR-04 | Directus Schema Snapshot (`schema.json`) in VCS | Reproducible, portable, AI-readable schema state |
| ADR-05 | BankStatement two-step workflow (import with null Transaction → reconcile by setting Transaction FK); **dedup on create** = **atomic-line** key (**FR7**/**FR8**); 0–2 per Transaction enforced via Hook on update and on create when Transaction is non-null | Cannot be expressed as Directus RBAC alone; dedup and cap are procedural |
| ADR-06 | Journal polymorphic pattern via JournalLink.collection + JournalLink.item | Avoids exclusive FK coupling; maximum flexibility for evidence linking |
| ADR-07 | **Dual-layer Zero-Trust**: Directus RBAC (API/UX primary) **+ PostgreSQL RLS** (database backstop) | Prevents frontend bypass; defense-in-depth even if Directus is misconfigured; reuses proven legacy RLS |
| ADR-08 | **Revised:** Executive has **no** special item-level scope — same as `employee`; optional **Insights** UX filters only (**FR20**) |
| ADR-09 | **Phase 1:** All user-facing clients (Admin, extensions; **optional future SPA**) communicate via Directus REST API only | Single security boundary; Directus token auth per user; no direct DB from clients |
| ADR-10 | Production deployment on Google Cloud Run | Serverless scaling; Cloud SQL Proxy sidecar; Secret Manager integration |
| ADR-11 | **Four RLS tiers (PRD FR40):** Finance (full), HR (Employee LE, no Executive leg), **line manager** (subordinate **payroll recurring `Invoice`** + linked rows), baseline employee — **`executive` = baseline**, not a fifth tier; Insights **no** RLS bypass (**FR20**) | PRD FR20/FR21/FR33/FR40/FR41 |
| ADR-12 | **Production:** External OIDC/OAuth IdP per **`identity-provider.md`**; **Story 1.8** implements; **trusted-domain JIT** (no manual `directus_users` for allowlisted SSO) per that file | PRD NFR12; swap IdP by editing one doc + story, not scattered specs |
| ADR-13 | **PostgreSQL RLS via `SET LOCAL ROLE <RLS_SESSION_ROLE>; SET LOCAL app.user_email`** (default role **`directus_rls_subject`**) on **`items.*`** for **every** authenticated user (**including Directus Administrator** — no ERP row bypass). **Directus connects as `sterile_dev`** (no `policy_owner_access_*`); **`bs4_dev`** is break-glass only with owner-access policies for migrations / unscoped tooling. 12 sensitive tables keep RLS + `FORCE ROW LEVEL SECURITY`; 10 non-sensitive tables may drop RLS. | PRD NFR13; `Role`/`UserToRole`/`RolePermissions` are live security data |
| ADR-14 | **Directus binding** for **`data-admin-surface-requirements.md`**: human-readable references (M2O + `related-values` + templates); scripts in `projects/internal-erp/directus/scripts/`; see §4.4 | Canonical **product** rules in **`data-admin-surface-requirements.md`** — admin stack swappable without weakening R1–R3 |
| ADR-15 | **FR28 / FR43 / FR47** (PRD 2026-03-16+): company-card **dedup**; reimbursement **`Invoice`** seed pair; **`Seniority.DayRate`**; **`DefaultProjectId`** enforcement; cash **FR47.9** defaults (**24m** past/forward, **monthly** grain) with **user-adjustable** spans/grain **where Insights (or successor) allows**; **two-series** layout; **tooling escape hatch** if Insights insufficient | Implementation defaults + spike outcomes recorded in §10.5 / §10.7 |
| ADR-16 | **`BankStatement` Finance-only visibility** (Story 3-1): HR and line-manager **no** read on `BankStatement`; **Directus RBAC** + **PostgreSQL RLS** aligned. **Import:** file + **`Account`** + Import; **registry** → **Python** parsers (~12 house banks); extension **`POST`s** rows as Finance user; **dedup** stays generic on `items.create`. **PM** confirms PRD override vs prior FR33/FR40 matrix cells for this collection. | Confidentiality of bank lines; single hook path for dedup |

---

## 10. PRD-aligned implementation defaults (2026-03-16)

Normative requirements remain in **`prd-ExpertflowInternalERP-2026-03-16.md`**. This section records **implementation-facing** choices.

### 10.1 FR28 — Company-card `Transaction` dedup (before insert)

Treat as **duplicate** (block auto-create) when an existing **`Transaction`** matches **all** of:

| # | Rule |
|---|------|
| D1 | **Same authenticated user** as the submitter (Directus `user_created` or equivalent stamp on the new row’s comparison set — use **same** field for both sides). |
| D2 | **Same company-paid `Account`** on the **`Transaction`** leg defined for card spend (document which FK — `OriginAccount` vs `DestinationAccount` — holds the selected company card account for **FR28**). |
| D3 | **Same `Project`**. |
| D4 | **Same `Currency`**. |
| D5 | **Same calendar date** on **`Transaction.Date`** (Phase 1: submission date). Timezone: **company default** in config, else **UTC**. |
| D6 | **Exact amount match** on **`Transaction.Amount`** at DB precision (e.g. **2 decimal places** for major currency units). |

**Hooks:** implement EXISTS query or Flow guard; **Finance** may still create manual duplicates if needed.

### 10.2 FR28 — Personal reimbursement `Invoice`

- **Seed / config:** maintain **two `Account` UUIDs** (or stable keys): **`ACCOUNT_EMPLOYEE_REIMBURSEMENT_PAYABLE`** pattern (employee **`LegalEntity.Type = Employee`**) and **`ACCOUNT_INTERNAL_REIMBURSEMENT_CLEARING`** (**`Internal`**).
- **`Invoice`:** set **`OriginAccount`/`DestinationAccount`** per Finance direction of liability (which side is employee); **both** legs **MUST** satisfy **FR28.2** semantics in PRD.
- **Default `Status`:** **`Planned`** unless Finance configures **`Sent`**.

### 10.3 FR24.1 / FR43 — `Seniority` day rate

- **Directus field label:** **`DayRate`**.
- **DB column:** map from existing **`Seniority`** table (add column in migration if missing). **Type:** `numeric` / `decimal`; **semantics:** reporting-currency **per calendar day**.
- **FR43 job:** `Amount = sum(hours) * DayRate` per aggregated pair/month (hours from **`TimeEntry`**).

### 10.4 FR22 — `Employee.DefaultProjectId`

- **Migration:** ensure **nullable** FK remains valid for legacy rows; **product** enforcement is **hook/Flow** (PRD **FR22** bullet — block **TimeEntry** + **FR28** when null).
- **Optional later:** `NOT NULL` after data cleanup.

### 10.5 FR47 — Cash dashboard (defaults vs user parameters)

**PRD:** **FR47.9** is normative for **user-defined** windows and **granularity**.

| Setting | Phase 1 **default** | Target UX (in order of preference) |
|--------|---------------------|-------------------------------------|
| Past span | **24** trailing calendar months | **User-adjustable** via Insights variables / filters / panel config **if supported** |
| Forward span | **24** calendar months | Same |
| As-of date | Dashboard “today” or panel default | Expose when tool supports a **single** anchor for both series |
| Granularity | **Monthly** (`date_trunc` month or equivalent) | **Quarterly** / **annual** roll-ups **when** the reporting layer can parameterize grouping (**later** if Insights blocks it) |

- **Panel A — Realized:** `SUM(Transaction.Amount)` **as stored**, grouped by **active grain**, filtered to **selected past window**.
- **Panel B — Forecast:** **`Invoice`** **FR47.2** + virtual recurrence **FR47.7** over **selected forward window**, same **grain**.
- **Do not** merge into one series without a **new** ADR + Finance sign-off.
- **Spike (Story 6.3 / Architecture):** document what is **native Insights** vs **extension** vs **DB view + parameters** vs **non-Insights** tool (**PRD FR47.9** §§3–4).

### 10.7 FR47 — Tooling decision log *(append after spike)*

_Use this subsection to record: Insights capability matrix, chosen approach, and any **ADR** revision if the cash UI moves off Insights._

### 10.6 Legacy `Expense` / Architecture doc hygiene

- **RBAC matrix (§5.2)** row **`Expense`**: **deprecated** for Phase 1 product flows; hide collection or read-only legacy. **Baseline `Journal` text (§5.3)** referencing **`Expense`**: replace with **FR28** **`Transaction`/`Invoice`** evidence per PRD **FR41** (update when editing permissions).


