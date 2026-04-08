# A12 — Non-canonical column cleanup (applied)

**Schema:** `BS4Prod09Feb2026` (from `DB_SEARCH_PATH__0`)

## What ran

Executable script (idempotent-ish: re-run skips missing columns):

`scripts/run_a12_noncanonical_migration.py`

### 1. Data cleared (non-canonical per PRD §3)

| Table | Action |
|--------|--------|
| `CurrencyExchange` | `UPDATE` set `Key`, `Month`, `Year`, `Day` to NULL (236 rows) |
| `InternalCost` | `UPDATE` set `TimeEntryId`, `ToPC` to NULL (24 rows) |

### 2. Columns dropped

- `Invoice` — `Transaction`, `image`
- `Transaction` — `BankStatementId`, `expense_id`, `image`
- `BankStatement` — `Transaction`
- `InternalCost` — `TimeEntryId`, `ToPC`, `FromPC`
- `Employee` — `ProfitCenter`
- `CurrencyExchange` — `Key`, `Month`, `Year`, `Day`

Foreign keys on those columns were dropped automatically before `DROP COLUMN`.

### 3. Views — `BankStatement.Transaction` removed

Dropped and recreated in the ERP schema:

- `v_reconcile_queue`
- `v_bankstatement_reconciliation`

New definitions **do not** join `BankStatement` → `Transaction` (column gone). `v_reconcile_queue` exposes `Transaction_ID` / account columns as **NULL** and `Status` as **`Unlinked`** until a future linking model replaces this.

### 4. Directus metadata

`directus_fields` / `directus_relations` rows for the removed fields were deleted where present.

## Follow-up

- Reload **canonical** `CurrencyExchange` data from your external source. Canonical columns: **`Day`** (date), **`Currency`**, **`RateToUSD`** (consider `numeric` migration for the rate). **`Day`** was re-added via `scripts/add_currency_exchange_date_column.py` after A12 drops.
- Reconcile UIs that depended on live `BankStatement` → `Transaction` joins must use the new ledger/bank design (e.g. Epic 3 / FR6–FR10).
- Refresh `schema_dump_final.json` from the database when convenient.
- Run **`python scripts/sync_directus_from_postgresql.py`** so Directus matches PostgreSQL (see `docs/sync-directus-from-postgresql.md`).
- Run **`python scripts/purge_stale_directus_ui.py`** to scrub orphan fields / preset widths and fix list-form metadata; then restart Directus and hard-refresh the browser.
