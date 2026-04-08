# Bank Statement Format Specification: UBS e-banking (CSV)

| Attribute | Value |
|-----------|-------|
| **Bank** | UBS Switzerland AG |
| **System** | e-banking (Standard Export) |
| **Parser ID** | `ubs_ebanking_csv` |
| **Associated Accounts** | 7, 8, 9 (and others on request) |
| **Updated** | 2026-03-25 |

## File Structure

The file is a semicolon-delimited CSV (`UTF-8` with BOM or `ISO-8859-1`, though `UTF-8` is preferred).

### Metadata Header
The first 8–9 lines contain global account info:
- `Account number:;...`
- `IBAN:;...`
- `Valued in:;...`
- `Opening balance / Closing balance`

### Data Columns
The header row starts with `Trade date` and ends with `Footnotes`. Important columns for BMAD:
- `Trade date`: Payment execution date.
- `Debit` / `Credit`: Summary amounts for simple transactions.
- `Individual amount`: The **atomic** line amount for multi-payment or complex transactions.
- `Transaction no.`: Unique identifier (e.g., `ZD...` or `013...`).
- `Description1`, `Description2`, `Description3`: Narrative parts merged using ` | ` separator.

---

## Technical Interpretation Rules (Story 3.1)

### 1. Multi-line Transaction Handling
UBS exports "multi e-banking order" transactions across multiple rows sharing the same `Transaction no.`:
- **Summary Row**: Contains total debit/credit, merged date, and general description. *This row is dropped to avoid double counting.*
- **Atomic Rows**: Contain `Individual amount` and payment-specific recipient info. *These rows are imported.*
- **Logic**: If multiple rows share a `Transaction no.`, keep only rows with `Individual amount`. If only one row exists for an ID, use `Debit`, `Credit`, or `Individual amount`.

### 2. Column Mapping
| Source Column | BMAD Field | Transformation |
|---------------|------------|----------------|
| `Transaction no.` | `BankTransactionID` | Trimmed string |
| `Trade date` | `Date` | Trimmed `YYYY-MM-DD` ISO string |
| Derived | `Amount` | Prefers `Individual amount`, falls back to `Debit`/`Credit` |
| `Description[1-3]` | `Description` | Merged with ` | ` separator and trimmed |

### 3. Excluded Data
- `Trade time`, `Booking date`, `Value date`, `Balance`: Not stored in `BankStatement` (can be inferred or used for reconciliation in Story 3.2).
- `Footnotes`: Legacy data, not imported.
- Currency is assumed to match the `Account` currency in the database.

---

## Test Fixtures
- Sample: `bank-import/tests/fixtures/ubs_sample.csv` (Small)
- Large Batch 2024-2026: `bank-import/tests/fixtures/ubs_ebanking_large_2026.csv` (provided by USER, 1028 lines).

---

## Reference Implementation
Python Parser: `projects/internal-erp/directus/bank-import/parsers/ubs_ebanking_csv.py`
Directus Hook: `projects/internal-erp/directus/extensions/bank-statement-dedup/` (Handling FR8 deduplication key).
