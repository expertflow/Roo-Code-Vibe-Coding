# Story 1.2 — Financial core collections (implementation companion)

Use this checklist while configuring Directus **Admin** for **`_bmad-output/implementation-artifacts/1-2-register-financial-core-collections.md`**.

**Source of truth for DB columns:** repo root `schema_dump_final.json`.

**Architecture:** `_bmad-output/planning-artifacts/architecture-BMADMonorepoEFInternalTools-2026-03-15.md` §4.1 (interfaces), §4.3 (display templates).

---

## 1. Collection display names (examples)

| DB table           | Suggested collection label     |
|--------------------|--------------------------------|
| Account            | Account                        |
| BankStatement      | Bank Statement                 |
| Transaction        | Transaction                    |
| Invoice            | Invoice                        |
| Allocation         | Allocation                     |
| Accruals           | Accruals                       |
| Journal            | Journal                        |
| Currency           | Currency                       |
| CurrencyExchange   | Currency Exchange Rates        |

---

## 2. Required display templates (AC)

| Collection | Template |
|------------|----------|
| **Account** | `{{Name}} [{{LegalEntity.Name}}]` |
| **Invoice** | `INV-{{id}} · {{Amount}} {{Currency.CurrencyCode}}` |

Set other financial collections to something readable (e.g. **Transaction** — see architecture: `TXN-{{id}} · {{Amount}} · {{Date}}`).

---

## 3. Field hints from `schema_dump_final.json` (interfaces)

Map PostgreSQL types per architecture §4.1:

- **`integer`** (FK to another table) → **M2O** to that collection (relationships may be refined in Story **1.5**; for 1.2 you can still set labels and basic interface).
- **`numeric`** → **input-decimal** (e.g. `Invoice.Amount`).
- **`date`** → **datetime** (or date-only if you prefer — align with team; epics cite **datetime** for invoice dates).
- **`text`** / **`character varying`** → **input** (or **textarea** for long text).
- **`USER-DEFINED`** → **select-dropdown** (confirm choices from DB if any).

### Invoice (highlights)

- Intended Finance fields: `OriginAccount`, `DestinationAccount`, `Currency`, `Project`, `Transaction` → FK integers → M2O targets as named.
- `Amount` → numeric → input-decimal.
- `Status` → text → select-dropdown (populate from data or agreed enum).
- `SentDate`, `DueDate`, `PaymentDate` → date → datetime.
- Current DB still contains legacy extras (`employee_id`, `image`); keep them hidden in Directus until formal schema cleanup.

### Account

- `LegalEntity`, `Currency` → M2O.
- `Name`, `Details` → input / textarea.

### Journal

- `ReferenceType` → **select-dropdown** with at least Phase 1 targets (per epic AC):  
  `Invoice`, `Transaction`, `BankStatement`, `Expense`  
  Optionally add other in-scope link targets used in practice: e.g. `Allocation`, `Accruals`, `InternalCost` — align with Finance; **Story 3.3** adds the custom polymorphic picker (ADR-06).
- `ReferenceID` → integer (raw ID until custom interface).
- `ResourceURL`, `document_file`, `EntryType` → input as appropriate.

---

## 4. Verification

- [ ] All 9 collections visible with labels.
- [ ] Invoice display template + field labels/interfaces match AC.
- [ ] Account display template matches AC.
- [ ] Journal `ReferenceType` dropdown choices set.
- [ ] No secrets committed; snapshot workflow deferred to **Story 1.7** unless you export early for backup.

---

## 5. Automated apply (preferred)

Idempotent script (relations + collection meta + field interfaces):

`projects/internal-erp/directus/scripts/apply-story-1-2-financial-meta.mjs`

See **README.md** § “Story 1.2 — Financial core collections”. Run `--dry-run` first.

## 6. After configuration

```bash
# From a machine with Directus CLI + env pointing at this instance (optional until 1.7):
# npx directus schema snapshot ./schema.json
```

Canonical repo location for `schema.json` is defined in **ADR-04** / Story **1.7**.
