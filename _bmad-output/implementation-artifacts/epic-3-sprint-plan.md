# Epic 3 — Sprint plan (Financial ledger & bank)

**Planned:** 2026-03-24 (Scrum Master — `bmad-sm` / Sprint Planning **[SP]**).  
**Normative epic:** `_bmad-output/planning-artifacts/epics-ExpertflowInternalERP-2026-03-16.md` — **Epic 3**.

## Dependency (PM)

- **Epic 2** (Directus roles + permissions + nav) is the **intended** prerequisite. Until it is done, **Finance Manager** AC may be verified as **Administrator** or with **documented** temporary access — see epic header note (2026-03-17).
- **RLS / Story 1-10** matrix remains the **authority** for row visibility; re-check **FR11**, **FR31–FR41** after Epic 2.

## Execution order (recommended)

| Seq | Story key | Name | Notes |
|-----|-----------|------|--------|
| 1 | `3-1-bank-statement-import-deduplication` | Bank statement import + dedup (+ **3-1a** Finance-only RLS, **3-1b/c** file+Account import + Python parsers, **3-1d** hook) | See story file for sub-slices; **FR6** / **FR8**; policy conflict vs Architecture flagged in story. |
| 2 | `3-2-bankstatement-reconciliation-three-option-workflow` | Reconciliation A/B/C + 0–2 cap | Depends on **3-1**; hook `bank-statement-limit`; match windows per epic. |
| 3 | `3-3-journal-entry-polymorphic-document-linking` | Journal polymorphic + **FR12** | Evidence links; can proceed in parallel with **3-4** after **3-2** is underway if capacity allows — epic doc lists **3-3** before **3-4**. |
| 4 | `3-4-invoice-allocation-management` | Invoice + **Allocation** | Supports Option B in **3-2**; Finance-only on **Allocation** per AC. |
| 5 | `3-5-accruals-management-finance-only` | Accruals | Finance-only visibility (**FR21** / **FR41**). |
| 6 | `3-6-currency-exchange-rate-management` | **Currency** + **CurrencyExchange** | Reporting currency baseline. |

**Out of this sprint (stub):** **Story 3.2b** — multi-bank CSV pipeline (**FR46**) — refine when prioritized.

## Tracking

- **Sprint record:** `_bmad-output/implementation-artifacts/sprint-status.yaml` (`development_status` keys above).
- **Existing hooks (brownfield):** Architecture references `extensions/hooks/bank-statement-dedup/` and `bank-statement-limit/` — **3-1** / **3-2** may be **verify + harden** as much as **greenfield**.

## Next BMAD steps

1. **`bmad-create-story` [CS]** — Prepare **`3-1-bank-statement-import-deduplication`** (first in sequence).
2. **`bmad-dev-story` [DS]** — Implement / verify against the story file.
3. Repeat **CS → DS** for **3-2**, then **3-3**, **3-4**, **3-5**, **3-6**.

Invoke **`bmad-help`** if Epic 2 vs Epic 3 ordering should change (e.g. **Correct Course [CC]**).
