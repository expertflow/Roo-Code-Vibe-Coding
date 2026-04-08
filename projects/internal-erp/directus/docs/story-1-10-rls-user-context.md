# Story 1-10 — RLS user context (`app.user_email`)

## Policy (PM / product)

**Directus Administrator does not bypass** PostgreSQL RLS for **Data Engine** (`items.*`) access. Any logged-in user, including Admin, gets:

1. `SET LOCAL ROLE <RLS_SESSION_ROLE>` — default **`directus_rls_subject`**. PostgreSQL has **no** role named `public` (`PUBLIC` in `GRANT`/`POLICY` is a keyword). Create the role once: **`docs/sql/create-rls-session-role.sql`**. Directus **`DB_USER`** MUST be **`sterile_dev`** (grants: **`docs/sql/setup-sterile-dev.sql`**) so the pool user is **not** covered by `policy_owner_access_*` (`TO bs4_dev` only). **`bs4_dev`** = break-glass / migrations only.
2. `set_config('app.user_email', <normalized email>, true)` (same as `SET LOCAL`)

So **row visibility** on RLS-protected ERP tables follows **`UserToRole`** + RLS for that **`directus_users.email`**. **`bs4_dev`** owner-access policies apply **only** to **`bs4_dev`** connections, not to **`sterile_dev`** (Directus).

## When the hook does **not** run

- No `accountability.user` (anonymous request, some static-token flows, internal knex without user).
- `RLS_USER_CONTEXT_ENABLED=false` (break-glass only).

Connections as **`bs4_dev`** keep **owner-access** visibility — intended for migrations / emergency SQL. Connections as **`sterile_dev`** without the hook do **not** get that pass-through on ERP tables.

## Schema / “create new tables”

Directus **Settings → Data Model** and migrations often use routes or knex calls **outside** `items.*` filters. DDL and metadata can still work with the service account. **Viewing/editing rows** in collections goes through `items.*` and is RLS-scoped.

## Env

| Variable | Default | Meaning |
|----------|---------|--------|
| `RLS_USER_CONTEXT_ENABLED` | on | Set `false` only for controlled break-glass |
| `RLS_SESSION_ROLE` | `directus_rls_subject` | Unquoted Postgres identifier; must exist and be granted to **`sterile_dev`** (Directus `DB_USER`) |

## `UserToRole` writes blocked in Admin?

Normal when RLS policies deny **INSERT** for that **`app.user_email`**. Use **`psql` as `bs4_dev`** (break-glass) or DBA to insert rows — **`docs/sql/seed-user-to-role.example.sql`**, **`docs/story-1-8-google-sso.md`** §7.

## Example: `andreas.stuber@expertflow.com` + Finance “see all”

| Layer | Requirement |
|-------|-------------|
| **SSO** | Story **1-8** — email on `directus_users` |
| **PostgreSQL** | **`UserToRole`**: `User` = `andreas.stuber@expertflow.com`, **`RoleName`** → **`Role`** row RLS maps to **Finance** (id **115** per Architecture §8.4) |
| **Directus** | Epic **2** — `finance-manager` (or Admin **plus** the same email in `UserToRole` if you use Admin for UX but RLS still keys off email) |

## Restart

After changing the extension:

```bash
docker compose restart directus
```

---

## Troubleshooting: "permission denied for table directus_activity"

**See [`docs/troubleshooting-rls-permissions.md`](./troubleshooting-rls-permissions.md) for full diagnosis steps.**

**Short answer:** The extension does `SET ROLE directus_rls_subject` on every item mutation. If `directus_rls_subject` lacks grants on the `directus` schema, Directus's internal writes (activity log, revisions, presets) fail.

**Fix** (run as `bs4_dev`):

```sql
GRANT USAGE ON SCHEMA directus TO directus_rls_subject;
GRANT ALL ON ALL TABLES IN SCHEMA directus TO directus_rls_subject;
GRANT ALL ON ALL SEQUENCES IN SCHEMA directus TO directus_rls_subject;
```

This is included in **`docs/sql/create-rls-session-role.sql`** and **`docs/sql/grant-rls-subject-erp-schema.sql`**. Re-run after Directus upgrades that may add new system tables.
