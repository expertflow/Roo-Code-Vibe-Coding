# Persona & Feature Documentation
**Project**: Expertflow Internal ERP
**Current Phase**: Phase 1 (Directus-First Administration)

This document ties our target personas to the actual, live schema implemented in Directus. It serves as both the architectural feature map and the baseline for initial user documentation.

---

## 1. Finance Manager (Global)
*Responsible for the global decoupling of atomic ledgers, bank reconciliation, and overarching financial compliance.*

### 🛠️ Implemented Features
* **General Ledger Management**: Full Read/Write/Update on `Transaction` and `Invoice` collections.
* **Bank Reconciliation Workflow**:
  * **Import & Deduplication**: Imports external bank statements (e.g., MCB, UBS, Wise via CSV/PDF) directly into the `BankStatement` collection (a 1:1 mirror of the bank's view). An active deduplication hook inherently prevents duplicate entries using a composite key (`Account` + `Date` + `Amount` + `Description`).
  * **Auto-Matching**: Automatically maps the `CorrespondantBank` by matching the first 20 characters of statement descriptions against historical transactions.
  * **Three-Option Reconciliation**: Operates a strict resolution flow to map statements to `Transactions`: *(A) Match an existing transaction within ±3 days*, *(B) Spawn a new transaction straight from an `Invoice`*, or *(C) Create a new transaction with intelligent Account suggestions*. Furthermore, enforces a strict cardinality limit (max 2 bank statements can link to 1 transaction).
* **Automated Currency Features**: View system-calculated converted values per row (`USDAmount` fields) powered by the `CurrencyExchange` mechanism.
* **Cost Allocation Elements**: 
  * Granular cost tracking is managed by linking `Invoice` or `Transaction` records directly to a `Project` (which then rolls up into a overarching Profit Center).
  * External routing occurs when one leg of the invoice/transaction is linked to an `Account` of type "internal".
* **Internal Cost Shifts**: Managed via the `InternalCost` collection. This allows allocating effort (e.g. time tracking) from one `Project` directly to another `Project`, bypassing standard ledger `Account` elements entirely.
* **Year-End Demarcation (Accruals)**: The `Accruals` collection is utilized strictly for end-of-year Revenue and Cost demarcations (WIP, PoC, Deferrals) required for annual tax and profit declarations. *Note: These are completely separate from Cost Center operations and are strictly isolated.*
* **Allocation Engine**: Employs the `Allocation` collection to seamlessly establish many-to-many (m:n) links between forward-looking `Invoices` and actualized `Transactions`.
* **Annual Tax Export via External System**: Annually exports local Pakistani transactions (revenue from local clients) and local operational costs (rent, electricity, laptops, etc.) from the BS4 ERP to a dedicated third-party instance of `manager.io` (running at `https://ef-finance.expertflow.com/`). This standalone application is used exactly once a year exclusively for Annual Pakistani Tax declarations.
* **Financial Reporting Dashboards (Streamlit)**: Live Streamlit reports ([LegalEntity Summary](https://finance-dashboard-253025248502.europe-west6.run.app/LegalEntity_Summary)) providing high-level financial reporting that fulfills [BMAD FR47](prd-ExpertflowInternalERP-2026-03-16.md#fr47-cash-flow-report--directus-insights-or-successor) and [Epic 6.3](epics-ExpertflowInternalERP-2026-03-16.md#epic-6-dashboards-and-reporting). The implementation rationale is mapped in the [Lovable Reporting Endpoints Plan](antigravity-implementation-history.md#session-bc693bc0-c575-4790-bd59-57617af09bf9). These reports encompass:
  * **Monthly Forward-Looking Cashflow**: Summing expected inflows/outflows from the `Invoice` collection.
  * **Historical Annual Profits**: Summing past `Transaction` inflows and outflows grouped by year. *(Note: This historical view is currently missing `Accruals` integration, which will be incorporated in a later phase).*
  * *Future Roadmap*: As dictated by the project roadmap, these standalone Streamlit reports will eventually be copy-pasted and rebuilt into a native Angular format.
* **Rapid Allocation UI (React/Lovable)**: A specialized interface (now live at [https://rapid-allocation-ui-253025248502.us-central1.run.app/](https://rapid-allocation-ui-253025248502.us-central1.run.app/)) dedicated to quickly matching `Invoices` to `Transactions`. Key views include:
  * *Link Selection Workflow*: A split-screen UI to select and map unallocated Invoices directly against unallocated Transactions to derive exact differences.
  * *Entity Balance Sheet ("Who owes whom")*: A global view sorting all Legal Entities, displaying the net difference between their `Invoice` sum and their `Transaction` sum to expose outstanding debts or credits dynamically.

### 💡 Proposed New Features
* **Completeness Dashboard**: A Directus Insights panel showing the ratio of `Transaction` records lacking `Journal` attachments.
* **Rapid Allocation UI (Angular Migration)**: In a later stage, the live React/Lovable UI will be migrated to a native Angular solution. This is a purely architectural rebuild and does not change the core use-case or UX for invoice-to-transaction matching.
---

## 2. HR Manager
*Manages the employee lifecycle, payroll distributions, and organizational structure modeling everything uniformly through financial ledger collections.*

### 🛠️ Implemented Features
* **Employee Lifecycle (Legal Entities)**: A new employee is onboarded as a `LegalEntity` of type 'Employee' (or 'Director'). Every employee entity receives two dedicated ledgers via the `Account` table: a **Salary Account** and a **Leaves Account**.
* **Ledger-Based Payroll Processing**:
  * Employs the `Invoice` collection by modeling base salaries as monthly recurring invoices linked to the employee's Salary `Account`.
  * Physical salary payouts are tracked as `Transactions` that debit the owed salary invoice.
* **Ledger-Based PTO (Leaves as Currency)**: 
  * PTO is managed using the exact same ledger logic. The employee's Leaves `Account` receives an annually recurring `Invoice` where the "currency" is simply PTO Days (e.g., allocating 25 days/year).
  * Consuming a leave generates a `Transaction` that debits from those available PTO days.
  * Different PTO types (Sick, Maternity, Umrah, Holiday) are dynamically tracked and viewed using standard `Project` cost allocations mapped to the PTO transactions.
* **Country-Specific Local Processing (Pakistan)**:
  * *Monthly Exports*: Generates exports of all local salaries sent to (a) the local bank to authorize PKR fund releases and (b) the state software for local salary declarations.
  * *Annual Exports*: Exports local salaries, employee expenses, and provident fund data to the external `manager.io` tax application (`https://ef-finance.expertflow.com/`) utilized strictly once per year for Annual Pakistani Tax declarations.

### 💡 Proposed New Features
* **Unified HR Onboarding Interface (UX)**: A single simplified HR interface for entering new employee data that automatically orchestrates the creation of all five underlying database records: the `Employee` record, a `LegalEntity` (type: Employee), a **Salary Account**, a **PTO Account**, and a **Recurring Invoice** (Base Salary). This abstracts the complex ledger structure outlined in [PRD Terminology — "Salary" / payroll](prd-ExpertflowInternalERP-2026-03-16.md#44-terminology--salary--payroll-for-hr-and-operators) matching the goals of [Epic 5 / HR onboarding](epics-ExpertflowInternalERP-2026-03-16.md).
* **Automated Leave & Salary Run Generation**: A custom Directus Operation/Flow that scans recurring `Invoice` templates and physically generates the monthly salary and annual PTO batch invoices.
* **Strict Executive RLS Validation View**: A dashboard confirming that HR cannot view the specific `Transaction` financial records linked to Director/Executive level entities.

---

## 3. Executive (Profit Center Manager)
*Drives strategic decisions and monitors project-level Profit & Loss, while governed strictly by Row Level Security (RLS).*

### 🛠️ Implemented Features
* **Secure P&L Visibility**: Can view financial records in `Transaction`, `BankStatement`, and `Invoice` *only* where the linked `Project` falls under their profit center.
* **Standard Operating Access**: Inherits standard employee workflows for their own personal data tracking, seamlessly subjected to the same baseline RLS.

### 💡 Proposed New Features
* **Executive Insights P&L Dashboard**: Dedicated charts on the Directus home screen grouping approved `Transaction` amounts by `Project`.

---

## 4. Line Manager
*Operates their specific team, handling approvals, tracking output, and monitoring localized payroll expenses.*

### 🛠️ Implemented Features
* **Team Approvals**: Read/Update access to `Leaves` and `TimeEntry` submitted by subordinates.
* **Subordinate Oversight**: Can view the `Task` inputs of their team.
* **Team Cost Visibility**: Authorized to read the payroll-related `Invoice` collections strictly mapped to their team members.

### 💡 Proposed New Features
* **Pending Actions Dashboard**: A custom Directus Panel showing "Leaves Awaiting Approval" and "Unreviewed Timesheets".

---

## 5. Employee
*The standard user managing back-office requirements effortlessly.*

### 🛠️ Implemented Features
* **Self-Service Expenses**: Ability to log out-of-pocket expenses and company card transactions via a dedicated [Mobile Expense Capture App](../../projects/internal-erp/expense-app/) (**Live Instance**: [https://expertflowerp.web.app/](https://expertflowerp.web.app/)). This separate UX uses a camera-first approach to natively capture receipts, which then materialize as an `Invoice` or `Transaction` in the ledger, with the receipt image linked securely as a `Journal` record. See the [Mobile Expense Capture App Implementation Plan](antigravity-implementation-history.md#session-c0de723a-11e4-42e5-939c-f4a62a31bb0b) for technical details.
* **Omnichannel Time & PTO Tracking**:
  * *Google Calendar Integration (Live)*: Employees can track time natively via a proprietary Google Workspace Calendar Add-on (see [Antigravity implementation plan](antigravity-implementation-history.md#implementation-plan-google-calendar-integration-for-time-tracking) and [source code](../../projects/internal-erp/google-apps-script/TimeTracking.js)). This fulfills the intent of [Epic 5 / Story 5.1 & 5.4](epics-ExpertflowInternalERP-2026-03-16.md#story-51-time-entry-logging--team-visibility). It maps calendar events (start/end times) directly to target work projects or PTO categories.
  * *Directus / Mobile UX*: Alternatively, time tracking and leave requests are managed via a dedicated Employee interface, specifying the time frame and the target project.
* **Automated Time Ledger Translation**:
  * *PTO Projects*: If a PTO time period spans non-working hours (weekends, public holidays), a background process intercepts the entry to calculate the *net* amount of time for PTO debits, determining the actual PTO consumed.
  * *Standard Projects*: Conversely, if someone works on a customer project over the weekend, the *gross* hours are charged continuously to the target project.
  * *Ledger Conversion*: The time tracking tool automatically spins up an internal financial movement (`InternalCost` or `Transaction` depending on final schema optimization) crediting the Employee's Project and debiting the target Project/PTO account.
* **Personal Data Checking**: Read access to their own `EmployeePersonalInfo`.

### 💡 Proposed New Features
* **Expense Status Notifications**: Simple Directus Flow to email/notify the employee when an `Expense` is fully reimbursed in the ledger.
* **Leave Quota Panel**: A visual indicator showing remaining sick / vacation days on their default Directus dashboard.
