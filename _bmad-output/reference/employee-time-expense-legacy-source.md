# Employee app — time and expense (legacy source)

**Origin:** Imported from user export `# Employee Appsheet App - Time and Expen.md` (2026).  
**Normative product direction:** See **`../planning-artifacts/employee-time-expense-requirements-and-plan.md`** and the main PRD — this file is **historical / intent** only.  
**Note:** Original text referred to a separate mobile stack; **Phase 1 delivery** targets **Directus** (Admin, Flows, extensions). Ignore legacy **AppSheet** naming.

---

## Time tracking

Employee creates a **TimeEntry** with their **Employee**. They choose a **project** (only **open** projects should be shown), select **date and time**, and add a **description**.

**Background execution (policy TBD):**

Immediately upon **TimeEntry** creation, **or** on a **monthly** basis, create an **internal cost allocation** from the employee’s **default / home project** to the **project** on the **TimeEntry**, multiplying **hours** by the **day rate** of the **seniority level** of that employee.

---

## Expense tracking (legacy wording)

- Employee takes a **picture** of a receipt.
- Employee enters **amount** and **currency**.
- Employee **optionally** allocates to a **project** (if not chosen, allocate to **default project**).
- Employee specifies **how they paid** (chooses an **account** — e.g. **company credit card** vs **personal funds**).

**Execution (legacy):**

- If **company card** → create **`Transaction`**.
- If **personal funds** → create an **AP invoice** from the employee to the company.

Link **invoice** or **transaction** to that **project**, or if not chosen to the project related to the employee’s **LegalEntity**.

Attach picture to **`Journal`** of either the **invoice** or **transaction**.

---

## Product correction (2026 — PM)

There is **no** canonical **`Expense`** collection for this flow: **submission SHALL materialize** as either a **`Transaction`** or an **`Invoice`**, with **receipt evidence** on **`Journal`** linked to that ledger row (**`JournalLink.collection` = `Transaction` | `Invoice`**). **`InternalCost`** from time is **monthly** only; day rate from **`Seniority`**; default project via **`Employee.DefaultProjectId`** (M2O **Project**). **Locked detail:** **`../planning-artifacts/employee-time-expense-requirements-and-plan.md`**.

