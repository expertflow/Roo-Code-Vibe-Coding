# Employee time & expense — functional requirements & plan (Directus-first)

> **Note:** Please verify against `antigravity-implementation-history.md` for alternative implemented methodologies (e.g., *Mobile Expense Capture App*, *Google Calendar Integration for Time Tracking*), as previous Antigravity session plans may supersede or contradict these requirements.


**Status:** **Decisions locked (PM 2026-03-16+)** — aligned with main PRD **FR22**, **FR25**, **FR28**, **FR29**, **FR41**, **FR43**.  
**Reference:** `_bmad-output/reference/employee-time-expense-legacy-source.md`  
**Stack:** **Directus only** for Phase 1 (Admin, **Flows**, extensions). **No Lovable** unless a later increment explicitly reopens a SPA — **not** required for this scope.

---

## 1. Principles

| # | Principle |
|---|-----------|
| P1 | **No canonical `Expense` collection** for employee spend: submission **materializes** as **`Transaction`** (company card) or **`Invoice`** (personal / reimbursement), plus **`Journal`** receipt evidence (**FR12**). |
| P2 | **Default project** for effort and for spend when the user omits project: **`Employee` M2O → `Project`** — implemented as **`DefaultProjectId`** in PRD **FR22** (or **Architecture** adds equivalent FK if the column is missing). **Not** used for RLS (**FR40**). |
| P3 | **Open projects** in pickers: **`Project.Status = Active`** (or equivalent **Architecture** flag). |
| P4 | **Time → `InternalCost`:** **Monthly batch only** (**FR43**); **no** per-**`TimeEntry`** save allocation in Phase 1. |
| P5 | **Day rate** for **`InternalCost`** amount: **`Seniority.DayRate`** (PRD **FR24.1**; DB column name **MAY** differ — **Architecture** maps). |
| P6 | **Company-card `Transaction`:** create **immediately** **if and only if** **FR28.1** finds **no** duplicate (**same user, same company card `Account` leg, same `Project`, same `Currency`, same calendar **`Transaction.Date`, exact `Amount`** — **Architecture** §10.1). |
| P7 | **Personal payment:** create **`Invoice` immediately**; **Finance** may contest / adjust / void afterward (no pre-approval gate). |

---

## 2. Time tracking — functional requirements

| ID | Requirement |
|----|----------------|
| **T1** | **Employee** SHALL **create** / **read** / **update** own **`TimeEntry`** (**FR25**): **Description**, **StartDateTime**, **EndDateTime**, **Employee**, **Project**. |
| **T2** | **Hours** SHALL be **derived** from **EndDateTime − StartDateTime** (no required persisted **`HoursWorked`**). |
| **T3** | **`Project`** picker SHALL list **only open/active** projects (**Architecture** matches filter to schema). |
| **T4** | **`InternalCost`** from time SHALL be produced **only** by the **monthly** job (**FR43**), **not** on each **`TimeEntry`** save. |
| **T5** | Monthly job: for each relevant **`TimeEntry`** aggregation, **amount** = **hours × day rate** from the employee’s **`Seniority`** (**P5**). **`FromProject`** = employee’s **`DefaultProjectId`**; **`ToProject`** = **`TimeEntry.Project`** (per **FR30** / **Architecture**). |
| **T6** | **Line manager** / **HR** access to **`TimeEntry`** unchanged (**FR25** / **FR33**). |

---

## 3. Employee spend / reimbursement — functional requirements

| ID | Requirement |
|----|----------------|
| **E1** | **Employee** SHALL submit via **Directus** (**Flow** / extension / form): **receipt file**, **amount**, **currency**, **optional Project**, **payment type** (company-paid account vs personal). |
| **E2** | **Company-paid path:** **immediately** create **`Transaction`** **if** **P6** dedup passes; else **do not** duplicate (**Finance** handles edge cases). |
| **E3** | **Personal path:** **immediately** create **`Invoice`** (AP / reimbursement — **account legs** per **Architecture**). |
| **E4** | **`Project`** on created **`Transaction`/`Invoice`** = user-selected **`Project`** **or** **`Employee.DefaultProjectId`** (**FR22**). **HR** SHALL maintain **`DefaultProjectId`** for employees who use these flows (**required** for sensible defaults). |
| **E5** | **Receipt** SHALL be **`Journal`** with **`JournalLink.collection`** = **`Transaction`** or **`Invoice`** and **`JournalLink.item`** = created row (**FR28**/**FR29**/**FR41**). **Legacy `JournalLink.collection = 'Expense'`** is **not** used for new builds. |
| **E6** | **Employee** read scope for **`Journal`**: evidence on **`Transaction`/`Invoice`** **they initiated** via **E1** (**Architecture** implements attribution, e.g. user stamp + RLS). |
| **E7** | **HR** / **Finance** visibility on resulting rows per **FR33** / **FR40**; **Finance** full **CRUD** on **`Transaction`/`Invoice`**. |

---

## 4. Delivery plan (Directus)

| Phase | Deliverable |
|-------|-------------|
| **1** | **`TimeEntry`** + **Active-only** project M2O (hook, extension, or saved view). |
| **2** | **FR43** monthly **`InternalCost`** job: **Seniority** day rate × hours; **FromProject** = **`DefaultProjectId`**, **ToProject** = time project. |
| **3** | **FR28** **Flow**: intake → **`Transaction` or `Invoice`** + **`Journal`** file; **dedup** hook for **E2**. |
| **4** | RLS / item filters for **employee-attributed** **`Transaction`/`Invoice`** and **`Journal`** parents (**FR41**). |

---

## 5. Schema note — `Employee` → `Project`

**PM decision:** The **default project for effort and internal-cost “from” side** and for **default spend project** is a **single** **`Employee` M2O → `Project`**. The PRD field name remains **`DefaultProjectId`** (**FR22**). If the physical FK is absent, **add** it in **Architecture** / migration (same semantics — **not** a second parallel FK).

---

## 6. Resolved Q&A (archive)

| Topic | Decision |
|--------|-----------|
| Internal cost timing | **Monthly** only (**FR43**). |
| Day rate | **`Seniority` only**. |
| Default project | **`Employee.DefaultProjectId`** (M2O **Project**); add column if missing. |
| Ledger creation | **Immediate** **`Transaction`/`Invoice`**; Finance contests later. |
| Company card dedup | Create **only if no similar `Transaction`**. |
| Lovable | **Avoid**; **Directus** even if uglier. |

---

*Story breakdown: Epic 5 (time + spend); refine **Story 5.4** and RBAC examples that still mention **`Expense`**.*

