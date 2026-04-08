# Reference materials (`_bmad-output/reference/`)

| Document | Purpose |
| -------- | ------- |
| [`bank-statement-allocation-legacy-source.md`](./bank-statement-allocation-legacy-source.md) | Archived verbatim notes for bank reconciliation / allocation (input history for **FR45**). |
| [`bank-statement-allocation-prd-alignment.md`](./bank-statement-allocation-prd-alignment.md) | How that archive relates to the PRD; **normative rules** are in the PRD only. |
| [`banking-spreadsheet-import-legacy-source.md`](./banking-spreadsheet-import-legacy-source.md) | Archived notes for multi-bank CSV/spreadsheet → `BankStatement` import (input history for **FR46**). |
| [`cashflow-looker-reports-legacy-source.md`](./cashflow-looker-reports-legacy-source.md) | Legacy **Looker** notes; **FR47**/**FR47.9** — cash view (past **`Transaction`** + forward **`Invoice`**), configurable windows/grain where tool allows; **no** **`BankStatement`**; **PM corrections** + PRD. |
| [`employee-time-expense-legacy-source.md`](./employee-time-expense-legacy-source.md) | Legacy **employee** time + spend notes (imported); **no AppSheet**. **PRD FR22/FR25/FR28/FR29/FR41/FR43** now carry normative rules; this file + **`../planning-artifacts/employee-time-expense-requirements-and-plan.md`** are supporting detail. |
| [`migration-plan-postgres-directus-cloud-wave1.md`](../planning-artifacts/migration-plan-postgres-directus-cloud-wave1.md) | **Cloud + schema + RBAC** migration waves — Finance/HR first (**ledger + bank + cash**); time/leave/CRM/tickets later. |
| [`canonical-schema-prd-story-traceability.md`](../planning-artifacts/canonical-schema-prd-story-traceability.md) | **Rapid canonical DB** plan + **PRD↔Architecture↔story** matrix; non-canonical field inventory (**Speed A/B**). |

Normative requirements: **`../planning-artifacts/prd-ExpertflowInternalERP-2026-03-16.md`**.
