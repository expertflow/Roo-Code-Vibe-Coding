# Sync Directus metadata from PostgreSQL (canonical)

Directus stores field/collection metadata in the same database as the ERP schema (here: **`BS4Prod09Feb2026`**, tables `directus_fields`, `directus_collections`, `directus_relations`). After **DDL changes** (A12 column drops, `CurrencyExchange.Day`, etc.), run this so the Data Studio matches PostgreSQL.

## Script

From repo root (Cloud SQL proxy on `127.0.0.1:5432`, `bs4_dev` + `BS4_DEV_PASSWORD` in `directus/.env`):

```bash
python scripts/sync_directus_from_postgresql.py --dry-run
python scripts/sync_directus_from_postgresql.py
```

## What it does

1. **Prune (all ERP-backed collections):** For **every** `directus_fields.collection` that matches a **non-`directus_*`** table in the ERP schema, deletes field rows whose `field` is **not** a real PostgreSQL column on that table.  
   - This is **broader** than “registered in `directus_collections` only” (so leftover metadata after DDL is removed even for tables that have field rows but aren’t in the 24 registered collections).  
   - Keeps **O2M** `one_field` names listed in `directus_relations`, and rows with `special` containing `no-data`.
2. **Add (registered collections only):** Inserts missing `directus_fields` only for collections that exist in **`directus_collections`** **and** have a matching table (avoids auto-exposing every `pg_tables` row as a Data Model collection).
3. **Presets:** Scrubs **`directus_presets.layout_options.tabular.widths`** so keys match live columns (removes width entries for dropped columns).
4. **Templates:** Updates known stale **`directus_collections.display_template`** values (e.g. **CurrencyExchange**).

## Coverage vs “no ghost fields in the UI”

| Area | Covered by sync |
|------|------------------|
| Item/detail fields from **`directus_fields`** for any collection that maps to an ERP physical table | Yes — orphans removed |
| Tabular list **column width** keys in **`directus_presets`** | Yes — invalid keys removed |
| **`display_template`** placeholders for removed columns | Only rows we maintain in script; others — edit in Directus |
| Collections **without** a physical table in the ERP schema (extensions / virtual) | Not validated against PG |
| **`directus_*`** system tables | Excluded from ERP `user_tables` list — not pruned by this PG column walk |
| Browser / **`CACHE_SCHEMA`** stale API shape | Restart Directus + hard-refresh / clear site data (see below) |

## After running

- **Restart the Directus container** after DB metadata changes. If fields still look wrong, add **`CACHE_SCHEMA=false`** to `directus/.env` (see `.env.example` comment), restart again, then **hard-refresh** the browser (Ctrl+Shift+R) or **clear site data** for your Directus origin — bookmarks can cache column lists in the client.
- **`python scripts/purge_stale_directus_ui.py`** — same orphan + preset scrub logic, plus **CurrencyExchange**-specific form ordering and labels. Safe to run after **`sync`**.

### API: clear cache (optional)

With an admin static token, you can call **`POST /utils/cache/clear`** (see [Directus cache docs](https://directus.io/docs/configuration/cache)) instead of toggling `CACHE_SCHEMA`.

## Related

- `scripts/add_currency_exchange_date_column.py` — adds `Day` + one field row (also covered by sync for other gaps).
- `projects/internal-erp/directus/docs/sql/migrate-a12-noncanonical-cleanup.md` — DB-side A12 changes.
