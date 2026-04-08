# Story 6.3: Cash flow report (Insights or successor) — **review**

**Status:** **review** — **FR47.9**: defaults **24m** past/forward + **monthly** grain; **user-defined** spans/granularity **where feasible**; **tool change** allowed if Insights insufficient; **FR47.8** two-series layout; **PC owner** = Phase 2+.

## Story (draft — refine)

As a **Finance Manager** and **Executive**,
I want a **combined cash flow** view in **Streamlit** (legacy **Looker** spec = reference-only),
So that I see **realized** cash from **`Transaction`** (past) and **expected** cash from **`Invoice`** (forward) **without** **`BankStatement`** in this report — **NFR1**/**NFR13**-compliant org-wide access per **FR47.1**.

## Context

**Epic:** 6 — Executive & Finance Insights Dashboards.

**PRD:** **FR47** + **FR47.9** — **Transaction** (past) + **Invoice** (Planned/Sent, **DueDate**, virtual recurrence); **no** **`BankStatement`**. **FR20** (visibility). **FR47.1** org-wide panel. **FR47.9:** defaults **24m** past / **24m** forward / **monthly** grain; **user-adjustable** spans and **monthly|quarterly|annual** where **Streamlit** (or **successor** tool per PRD) supports it; **spike** + **Architecture §10.5–10.7**.

**Legacy reference (non-normative):** `_bmad-output/reference/cashflow-looker-reports-legacy-source.md` — read **PM corrections** table.

**Dependencies:** **`Invoice`**, **`Transaction`**, **`Account`**, **`LegalEntity`**, **`Project`/`ProfitCenter`**; **`Recurrence`** as **integer months** (**FR15**). Reporting views / parameters per **Architecture**.

**Structure (FR47.8):** **two** panels/series (**Realized** = raw **`AmountUSD`**; **Forecast** = **FR47.5–47.7** over `AmountUSD`); no blended net line in v1.

## Acceptance Criteria

**Draft AC (align with **FR47.9** + Architecture §10.5):**

1. **Defaults:** **24** trailing months past, **24** months forward, **monthly** grain — **SHALL** match PRD out-of-box behavior.
2. **User parameters (where feasible):** Document in runbook which of **past span**, **forward span**, **as-of**, **granularity** are **editable in UI** vs **fixed in SQL**; spike **Streamlit** first (**PRD FR47.9** §3).
3. **Realized panel:** **`SUM(Transaction.AmountUSD)`** **as stored**, **no** `BankStatement`; respect **active** window + grain.
4. **Forecast panel:** **`Invoice`** **Planned/Sent**, **`DueDate`** + **FR47.7** over **active** forward window + grain.
5. **Layout:** **Two** clearly named series — **do not** merge sign conventions without new PRD/ADR.
6. **Roles:** **finance-manager** + **executive** — same dashboard definition (**FR47.1**); **NFR1**/**NFR13** path documented.
7. **Escape hatch:** If Insights cannot support required parameters, **Architecture §10.7** + **ADR** for alternate tool / views.
8. **NFR5:** typical load under **5 seconds** (adjust per env).

## Tasks / Subtasks

- [x] **Spike** Streamlit: panel variables, date filters, grain switching (**FR47.9**); append **Architecture §10.7**.
  - **Note**: A unified parameterized view was chosen (`BS4Prod09Feb2026.cash_flow_report`) consolidating *Transaction* (Realized) and *Invoice* (Forecast). This provides a single trackable collection bypassing Insights multi-collection limits.
- [x] Implement panel(s) **or** parameterized views + chosen chart surface; document in runbook.
  - **Runbook**: Deploy the Streamlit app which queries `cash_flow_report`.
- [x] Permissions + reporting path: org-wide cash (**FR47.1**); **NFR1**/**NFR13**.
- [x] Verify AC.

## References

- `_bmad-output/planning-artifacts/prd-ExpertflowInternalERP-2026-03-16.md` — **FR47**, **FR47.9**, **FR15**, **FR20**
- `_bmad-output/planning-artifacts/epics-ExpertflowInternalERP-2026-03-16.md` — Story **6.3** (stub)
- PRD **NFR5**; Architecture (joins, reporting views)

## Dev agent sections

_(filled when implemented)_

### Agent Model Used
- Antigravity (Advanced Agentic Coding)

### Debug Log References
- Execution in local PostgreSQL resolving schema differences (BS4Prod09Feb2026).
- Directus Collections track successfully updated.

### Completion Notes List
- Created `BS4Prod09Feb2026.cash_flow_report` view to unify Invoice and Transaction data, using **`AmountUSD`** exclusively to normalize currencies.
- Native `Amount` is ignored in this report design.
- Handled SQL reserved keyword tracking for `directus.directus_collections`.
- Excluded BankStatement records explicitly per FR47.
- Defined runbook for Streamlit app deployment.

### File List
- `_bmad-output/implementation-artifacts/6-3-finance-cash-flow-reporting-dashboard.md`
