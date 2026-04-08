---
project: Internal ERP & HR
status: Discovery
stack: Directus-first (Phase 1); optional dedicated SPA deferred
---

# 📑 Project Vision: Expertflow Internal ERP
This is a Phase 1 implementation focused strictly on the core back-office automation for Expertflow.

## 1. Executive Summary
Replacement of the legacy internal back-office stack with a secure, scalable architecture using **Directus** as the primary platform for **backend and user-facing workflows** in Phase 1 (**speed over a separate employee app**). Focus is on Accounting and HR modules. A **dedicated employee SPA** (historically discussed as Lovable or similar) is **out of Phase 1 scope** unless PM re-opens that track (see PRD §5.14).

## 2. Scope & Boundaries (Phase 1)
- **Accounting (ERP)**: Real-time financial ledger, transaction tracking, and automated financial report generation.
- **HR System**: **Payroll as recurring `Invoice`** (Employee/Executive **`LegalEntity`**), employee onboarding, and time/holiday/expense tracking — **via Directus Admin** (+ extensions as needed).
- **Exclusions**: CPQ and CRM are strictly out of scope for this phase and will be managed as separate technical contexts.

## 3. Implementation Strategy
- **Directus Admin (all Phase 1 personas)**: Finance, HR, Executives, Line Managers, and **Employees** use Directus for data entry, workflows, and audit — **single client surface for velocity**.
- **Readable references:** The internal **data administration surface** (Phase 1: Directus) MUST follow **`_bmad-output/planning-artifacts/data-admin-surface-requirements.md`** (**PRD NFR14**); swap the admin product without dropping that contract.
- **Directus extensions (optional)**: Custom interfaces or hooks where Admin UX is insufficient; still same security boundary (Directus API).
- **Deferred**: Dedicated **employee SPA** for polished mobile/self-service UX — same Directus REST API when/if built.
- **Security**: Migration from manual PostgreSQL RLS to Directus-managed RBAC to allow for safe "vibecoding" sessions.

## 4. Target Users & Access Control
The project logic is driven by a strict "Privacy by Role" model, ensuring that sensitive data is only visible to those who absolutely require it for their business function.

### 4.1 Administrative Roles (Directus Admin)
- **Finance Manager (Global)**: Full visibility into all financial data, ledgers, and salaries across all regions and hierarchies (inc. Executives).
- **Executive (Profit Center Manager)**: **Same RLS as any employee** on sensitive data — **no** special database visibility; optional **Directus Insights** only where row access already allows (**PRD FR20–FR21, FR40**).
- **HR Manager**: Manages employee lifecycle, holidays, and **Employee-ledger** financial data (**payroll = recurring `Invoice`** on **`LegalEntity.Type = 'Employee'`** accounts). PRD **§4.4** maps **“salary”** to the ledger chain; **`Accruals`** is **Finance-only** (HR reads **`Invoice` / `Transaction` / `BankStatement`**, not **`Accruals`**). **STRICTLY BLOCKED** from **Executive-ledger** amount-bearing rows (`LegalEntity.Type = 'Executive'`) and from non-HR financial domains.
- **Line Manager**: Operational oversight for their team; holiday and time approvals; **may read subordinates’ payroll-related recurring `Invoice` rows** (and linked ledger rows per **PRD FR33/FR40**) — **payroll is only `Invoice`**, not another datastore.

### 4.3 Collection-Level Restrictions
- **Finance-Only Access**: Tables including `Accruals` and `Allocation` are strictly isolated to the Finance Manager role; **`executive`**, HR, line managers, and employees have **no** default read (**PRD FR41**).

### 4.2 End-User Roles (Phase 1 — Directus Admin)
- **Employee**: Uses **Directus Admin** with the `employee` role (after Epic 2) for personal records, time, leave, tasks, and expenses. **FR35–FR39** (dedicated SPA UX) are **deferred**; equivalent outcomes are targeted via **collections, layouts, and optional extensions** first.

## 5. Security & Permission Mandates (RBAC)
- **Corporate identity (final product)**: Staff sign in to **Directus** through the **external OIDC/OAuth IdP** defined in **`_bmad-output/planning-artifacts/identity-provider.md`** (PRD **NFR12**, Architecture **ADR-12**, Epic 1 **Story 1.8**). **Trusted-domain JIT:** e.g. **Google Workspace** users with verified **`@expertflow.com`** email must be able to log in **without** manual Directus user creation — details and allowlist **only** in that file. Local development may use other auth; production must not rely on shared passwords for end users.
- **Dual-layer Zero-Trust**: Directus RBAC is the primary API/UX enforcement layer. **PostgreSQL RLS** (existing policies from the **pre-Directus** era) is retained as a **database-level backstop** — the Directus extension passes the authenticated email via `SET LOCAL app.user_email` for **every** logged-in user (**including Directus Administrator**) on `items.*` data access — row visibility follows **`UserToRole`**, not an admin bypass. See PRD **NFR1** (revised), **NFR13**, Architecture **ADR-07** (revised), **ADR-13**.
- **Hierarchical Isolation**: The system must enforce that HR can access standard salaries but is blocked from Executive tiers and global financial ledgers.
- **Regional Compliance**: Ensure the system supports regional data isolation if required for different Expertflow offices.
## 6. Success Metrics & Strategic Objectives

### 6.1 Business KPIs
- **Reporting Velocity**: Transition from manual/spreadsheet-heavy reporting to **Instant Directus Insights**. Target: Zero manual data transformation for Monthly Close.
- **Operational Leanness**: 100% elimination of variable per-user licensing costs for internal back-office functions.
- **Data Fidelity**: Zero-drift between the database schema and accounting documentation.

### 6.2 User Success Criteria
- **Finance Manager**: **"Decoupled Atomic Ledger"**.
    1. **Bank Mirroring**: Import from e-banking is a simple upload that updates `BankStatement`. System ensures **Zero-Duplication** by validating against a unique `BankTransactionID` (or composite hash if unavailable). **Pre-requirement**: Import spreadsheets must contain pre-split entries; the system treats each row as an atomic record.
    2. **Active Mapping**: A secondary processing step generates/updates `Transaction` records linked to specific `Account` IDs based on `BankStatement` metadata analysis. **Relationship Constraint**: A single `Transaction` can correspond to at most two `BankStatement` entries.
    3. **Universal Journal**: Any attachment (image, email, PDF) can be registered as a `Journal` entry and linked to any internal object without an exclusive relationship to a specific table.
- **Executive**: **Same data access as employees** for ledgers; Insights P&L **only** if permitted by RLS or Finance-published aggregates — **no** bypass of other roles’ privacy (**PRD FR20–FR21**).
- **HR Manager**: Secure, role-restricted management of non-executive employee lifecycles and standard payroll data.
- **Employee**: **Frictionless tracking (Phase 1 via Directus)**. Time, leave, and expenses are captured in **Directus** with sensible defaults and RBAC. **Ideal UX** (smart project ordering, daily confirmation sparkline, mobile-first SPA) remains documented in **FR36–FR39 / Epic 7** for a **future** dedicated app if needed.

## 7. Risk Mitigation & Implementation Constraints

### 7.1 Data Integrity & Security
- **Unique Bank Scoping**: Duplicate prevention hashes must combine `AccountID` + `BankTransactionID` to prevent collisions across different banking institutions.
- **Aggregation Guardrails**: Insights and aggregates **must** respect **RLS** — **no** role (including **`executive`**) may infer hidden rows through dashboards (**PRD FR20, NFR13**).
- **Audit Readiness**: Implement a "Completeness Score" dashboard for Finance to monitor the ratio of `Transaction` records linked to `Journal` evidence.
