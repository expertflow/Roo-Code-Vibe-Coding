# Cash flow Looker reports — legacy source (traceability)

**Origin:** User-provided export; original filename: `CashflowLooker reports.md`  
**Reporting platform:** Spec written for **Looker**; **Phase 1 product** implements equivalent behavior in **Directus Insights** (or approved in-repo extension) — **Looker** is **not** required.  
**Normative product text:** **`prd-ExpertflowInternalERP-2026-03-16.md`** **FR47** (extends **FR20**).  
**Story stub:** **Epic 6 — Story 6.3** (refine after product clarifications).

---

# Cashflow Looker forecast

create a Cashflow forecast, that shows for each of the upcoming months the invoices that are either in Status Planned or Sent. Take as date the Invoice.DueDate.

If I say Legalentity type, I mean Invoice.Project.LegalEntity.Type.

If the OriginAccount.LegalEntity.Type is Internal, the amount should be negative, if not it should be positive.

Sum all invoices for LegalEntity.Type Employees and Executives into one big "Salary block" (these should all be of a negative amount).

For all invoice.Reccurrence = "1", create a virtual copy of that invoice for the next twelve months for this view.
For all invoice.Recurrence = "12", create a new virtual copy one year after the Due date of that Invoice.

---

## PM / product corrections (supersede ambiguous legacy lines)

The following **replace or narrow** the informal lines above for **Phase 1**; **normative text** is **PRD FR47**.

| Legacy line | Correction |
|-------------|------------|
| “Legalentity type … `Invoice.Project.LegalEntity.Type`” | **`Project` → `ProfitCenter` only**; **`LegalEntity`** may have **zero or many** **`Project`**s. **`LegalEntity.Type`** for invoice rules (**Salary**, sign) comes from **`Invoice.OriginAccount` / `DestinationAccount` → `LegalEntity` → `Type`** (see **FR47.4**). |
| Recurrence `"1"` / `"12"` strings | **`Recurrence`** is an **integer = months between occurrences** (**1** = monthly, **12** = annual, **N** = every N months — **FR15**, **FR47.7**). |
| Invoice-only forecast | **Cash report = `Transaction` (past) + `Invoice` (forward)**; **`BankStatement` excluded** (**FR47**). |
| (implied) per-role slices | **Phase 1:** **Finance + Executive** share the **same org-wide** panel; **ProfitCenter owner** = **Phase 2+** (**FR47.8**). |
| Window / layout | **PRD FR47.8–47.9:** **two** labeled series (**Realized** vs **Forecast**); **defaults** **24m** past / **24m** forward / **monthly** grain; **user-defined** spans + **monthly|quarterly|annual** **where the reporting tool allows**; **may** move off **Directus Insights** if insufficient (**FR47.9.4**). |
