# BankStatement allocation (legacy source) ↔ PRD alignment & notes

**Source (verbatim archive):** [`bank-statement-allocation-legacy-source.md`](./bank-statement-allocation-legacy-source.md)  
**Normative requirements:** [`../planning-artifacts/prd-ExpertflowInternalERP-2026-03-16.md`](../planning-artifacts/prd-ExpertflowInternalERP-2026-03-16.md) — **FR6**, **FR9**, **FR10**, **FR11**, **FR15**, **FR16**, **FR45**

This note records how the **archived** one-pager relates to the **current** PRD after reconciliation policy updates (nullable `BankStatement.Transaction` until mapped; **FR45.3** heuristics **±10%** amount and **±4 months** date vs legacy **±5%** text).

---

## 1. Queue definition — **aligned** with **FR6** / **FR45.1**

| Legacy source | Current PRD |
|---------------|-------------|
| List `BankStatement` where **no `Transaction`** **or** `Transaction` lacks **both** account legs. | **FR6:** `BankStatement.Transaction` **MAY be NULL** after import; **reconciliation SHALL** set it. **FR45.1:** queue includes **both** unreconciled (NULL FK) **and** incomplete stub transactions. |

---

## 2. Two `BankStatement` rows → one `Transaction` — **FR10**

The legacy doc does not spell out split/bridge pairs; **FR10** explicitly allows **up to two** `BankStatement` rows per **`Transaction`**. Reconciliation **Option A** can attach a **second** bank line to an **existing** `Transaction` when Finance confirms it is the same cash movement.

---

## 3. `Allocation` is **optional** (**FR16** / **FR45.6**)

| Legacy source | Current PRD |
|---------------|-------------|
| End state: allocate to Invoice **if** such an invoice exists. | **FR45.6:** Every `BankStatement` **must** resolve to a **`Transaction`**; linking that `Transaction` to an **`Invoice`** via **`Allocation`** is **MAY**, not **SHALL** — many settlements have no invoice match. |

---

## 4. Invoice suggestion heuristics — **PRD supersedes** legacy percentages

| Legacy source | Current PRD (**FR45.3**) |
|---------------|-------------------------|
| Roughly **±5%** on amount; no date window stated. | **±10%** on amount (symmetric band vs `Transaction` / `BankStatement` amount, same currency, Phase 1). **±4 calendar months** between an agreed **`Invoice`** date field (**Architecture** picks anchor — e.g. `SentDate` or `DueDate`) and **`BankStatement.Date`** (or `Transaction.Date`). |

**Later phase:** **AI-assisted similarity** (amount, text, counterparties) **MAY** replace or tighten these fixed bands — not required for Phase 1 beyond documenting intent.

---

## 5. Stub `Transaction` from bank row — **FR45.2** / **FR9** Option C

Unchanged: sign-based first leg, absolute amount, copy `Date` / `Description`; **`Currency`** per **Architecture** (**FR11**).

---

## 6. Platform

Legacy reference described a **spreadsheet-era** operator UI. **FR45** targets **Directus** (saved view, extension, Flow) per **NFR14**.

---

## Summary

| Topic | Status |
|-------|--------|
| Nullable `BankStatement.Transaction` until reconciliation | **PRD** (**FR6**/**FR10**) |
| 0–2 bank lines per `Transaction` | **PRD** (**FR10**) |
| `Allocation` optional | **PRD** (**FR45.6**) |
| Invoice matcher ±10% + ±4 months | **PRD** (**FR45.3**); legacy archive still says ±5% in body — **archive is not normative** |
| AI refinement | **Future** / Architecture |

---

## Suggested follow-ups

1. **Implementation story:** Hooks for dedup on create (NULL `Transaction` OK) + cap when `Transaction` set.  
2. **Architecture:** Confirm `Invoice` date field used for ±4 month window.  
3. **Later epic:** AI similarity matcher for suggestions.
