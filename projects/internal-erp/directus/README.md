# Internal ERP — Directus (local)

Phase 1 backend: Directus v11 against the existing `bidstruct4` PostgreSQL database.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) (Docker Desktop on Windows/macOS, or Docker Engine on Linux)
- [Google Cloud SQL Auth Proxy](https://cloud.google.com/sql/docs/postgres/connect-auth-proxy) installed and authenticated
- Access credentials for `bidstruct4` (user/password or IAM — per your org setup)

## 1. Database connectivity (ADR-02)

All DB traffic goes through **Cloud SQL Auth Proxy** — see architecture **ADR-02** in:

`../../../_bmad-output/planning-artifacts/architecture-BMADMonorepoEFInternalTools-2026-03-15.md`

Start the proxy on the **host** so it listens on `**127.0.0.1:5432`** (default). Example (adjust instance connection name):

```bash
cloud-sql-proxy --port 5432 PROJECT:REGION:INSTANCE
```

Keep this terminal running while developing.

## 2. Configure environment

```bash
cp .env.example .env
# Edit .env: set KEY, SECRET, DB_*, ADMIN_*
```

- `**KEY` / `SECRET**`: required by Directus; use long random strings.
- `**DB_HOST**`: leave as `host.docker.internal` when using this `docker-compose.yml` (container → host proxy).
- On **Linux**, `extra_hosts: host.docker.internal:host-gateway` in `docker-compose.yml` routes that hostname to the host.

Do **not** commit `.env`. Secrets in production use Secret Manager (ADR-03).

**Production (final product):** Staff **MUST** sign in via the **external OIDC/OAuth IdP** documented in `**_bmad-output/planning-artifacts/identity-provider.md`** (PRD **NFR12**, architecture **ADR-12**, Story **1.8**). **Trusted-domain JIT:** allowlisted corporate email domains (e.g. **`@expertflow.com`** via Google Workspace) must support **first login without** a pre-created Directus user — see that file. Vendor-specific steps live **only** there. Local email/password admin is for development only, not the production default for users.

## 3. Run Directus

From this directory:

```bash
docker compose build
docker compose up
```

The service **builds** a small image on top of `directus/directus:11.12.0` so **mixed-case PostgreSQL schema names** work (see Troubleshooting).

Open [http://localhost:8055](http://localhost:8055) and sign in with `ADMIN_EMAIL` / `ADMIN_PASSWORD`.

**Startup command:** The compose file runs `**bootstrap` OR `migrate:latest`** (whichever is needed), then starts the server. First boot creates Directus system tables; later boots skip install and only apply pending migrations.

## Layout


| Path          | Purpose                                                                       |
| ------------- | ----------------------------------------------------------------------------- |
| `docs/`       | Story checklists, **GCP deploy** (`gcp-directus-deployment.md`), SSO (`story-1-8-…`) |
| `scripts/`    | Idempotent Directus metadata automation (Epic 1 — see **Story 1.2+** below)   |
| `extensions/` | Directus extensions (hooks, interfaces) — future stories                      |
| `uploads/`    | Local file storage (gitignored contents)                                      |

## Epic 1 — implementation stories (numeric order)

Sections **Story 1.1–1.10** below are in **numeric order** for lookup. **Delivery / dependency order** may differ — e.g. **`Role` / RLS / SSO`** (**1.9**, **1.10**, **1.8**) often runs before **1.5–1.7**; see `_bmad-output/planning-artifacts/epics-ExpertflowInternalERP-2026-03-16.md` (*Implementation sequencing*).

## Story 1.1 — Docker Compose & Google Cloud Run setup

**Baseline:** **Prerequisites**, **§1 Database connectivity (ADR-02)**, **§2 Configure environment**, and **§3 Run Directus** (above) cover Cloud SQL Auth Proxy, `.env`, and `docker compose up`.

**Colleagues on GCP (Compute Engine VM):** **`docs/gcp-directus-deployment.md`** (full `gcloud` + VM steps), **`docker-compose.gcp-vm.example.yml`**, **`.env.gcp-vm.example`**, **`scripts/gcp-vm-bootstrap.sh`** (install Docker on Ubuntu VM).

**Verify / AC:** `_bmad-output/implementation-artifacts/1-1-docker-compose-google-cloud-run-setup.md`.

## Story 1.2 — Financial core collections (labels, templates, M2O)

Implements **FR2** metadata for the nine finance tables via the REST API (collections, relations, field interfaces).  
Config + relations are validated in-repo against `schema_dump_final.json` (no running Directus required).

**Prerequisite:** Directus is up and collections exist (database tables already present; sync/introspect in Admin if needed).

From repo root (or this directory):

```bash
# Preview API calls only
node projects/internal-erp/directus/scripts/apply-story-1-2-financial-meta.mjs --dry-run

# Apply (use your admin credentials)
set DIRECTUS_URL=http://127.0.0.1:8055
set DIRECTUS_ADMIN_EMAIL=you@example.com
set DIRECTUS_ADMIN_PASSWORD=***
node projects/internal-erp/directus/scripts/apply-story-1-2-financial-meta.mjs
```

Or use a **static token** instead of email/password: `set STATIC_TOKEN=...`.

**Verify in Admin:** AC 1–4 in `_bmad-output/implementation-artifacts/1-2-register-financial-core-collections.md`.  
**Tests:** `node --test projects/internal-erp/directus/scripts/story-1-2-config.test.mjs`  
**Canonical `schema.json` snapshot:** Story **1.7** (optional early `npx directus schema snapshot` for backup).

## Story 1.3 — Organizational & HR core collections (labels, templates, M2O)

Implements **FR2** metadata for **11** org/HR tables (`LegalEntity`, `ProfitCenter`, `Project`, `CountryLocation`, `Contact`, `Company`, `Employee`, `EmployeePersonalInfo`, `Seniority`, `Designation`, `department`).  
Depends on **Currency** (Story 1.2) for **CountryLocation.Currency**.

```bash
node projects/internal-erp/directus/scripts/apply-story-1-3-org-hr-meta.mjs --dry-run
set DIRECTUS_URL=http://127.0.0.1:8055
set DIRECTUS_ADMIN_EMAIL=you@example.com
set DIRECTUS_ADMIN_PASSWORD=***
node projects/internal-erp/directus/scripts/apply-story-1-3-org-hr-meta.mjs
```

**Verify:** `_bmad-output/implementation-artifacts/1-3-register-organizational-hr-core-collections.md` (AC 1–4).  
**Companion doc:** `docs/story-1-3-org-hr-collections.md`  
**Tests:** `node --test projects/internal-erp/directus/scripts/story-1-3-config.test.mjs`

## Story 1.4 — HR operations & hide out-of-scope collections (deferred)

**PM — backlog:** HR ops collections (`TimeEntry`, `Leaves`, …) + navigation hygiene for CPQ/CRM/ticket tables. **`Role` / `RolePermissions` / `UserToRole` are Story 1.9**, not 1.4.

**When scheduled:** after security wave, **1.5–1.7**, **Epic 2+** per epic *Implementation sequencing*.

**Artifact:** `_bmad-output/implementation-artifacts/1-4-register-hr-operations-rbac-reference-collections.md`.

## Story 1.5 — All foreign-key relationships (M2O / O2M)

**Epic 1 — FR3.** Wire every in-scope FK from **`schema_dump_final.json`** through Directus **`/relations`** + readable M2O templates.

- **Relations source:** `scripts/lib/story-1-2-config.mjs`, `story-1-3-config.mjs`, `story-1-9-config.mjs` → merged in **`scripts/lib/erp-relations.mjs`**.
- **Apply / upgrade UI:** run **`apply-m2o-dropdown-templates.mjs`** (creates missing relation rows + **`select-dropdown-m2o`** + **`related-values`**).

```bash
cd projects/internal-erp/directus/scripts
node apply-m2o-dropdown-templates.mjs --dry-run
set DIRECTUS_URL=http://127.0.0.1:8055
set DIRECTUS_ADMIN_EMAIL=you@expertflow.com
set DIRECTUS_ADMIN_PASSWORD=***
node apply-m2o-dropdown-templates.mjs
# Record/detail view still shows bare PKs (e.g. Transaction.OriginAccount = 2)? Re-apply meta:
node apply-m2o-dropdown-templates.mjs --force
```

_(If you only use Google SSO, use a **static token** or run as a user that can still call the API.)_

**401 `INVALID_CREDENTIALS` with `STATIC_TOKEN`:** The value must be the **raw token** Directus shows **once** after you generate it — **Save** the user first (a common mistake is generating the token but forgetting **Save**). No `Bearer ` prefix in the env var (the script adds it). Regenerate if unsure. **`KEY` / `SECRET` rotate** in `.env` can invalidate old tokens — generate a new one.

**Isolate the problem:** run **`node scripts/verify-directus-auth.mjs`** (same `DIRECTUS_URL` + token or email/password). If **`/users/me`** fails with 401, the token or URL is wrong for this server. If **`/users/me`** works but **`apply-m2o`** still 401s, compare env between the two terminals. Optional: **`node scripts/verify-directus-auth.mjs --relations`** (hits `/relations?limit=1`). Raw check (PowerShell, token not echoed to history if you paste carefully):

PowerShell (after `STATIC_TOKEN` and `DIRECTUS_URL` are set): `curl.exe -s -H "Authorization: Bearer $env:STATIC_TOKEN" "$($env:DIRECTUS_URL.TrimEnd('/'))/users/me"` — or paste the token once: `curl.exe -s -H "Authorization: Bearer <token>" "http://127.0.0.1:8055/users/me"`.

**Verify / task list:** `_bmad-output/implementation-artifacts/1-5-configure-all-foreign-key-relationships.md`.  
**Then:** Story **1.6** (audit verification) → Story **1.7** (commit **`schema.json`**) — below.

## Story 1.6 — Audit logging (Finance + `EmployeePersonalInfo`)

**Epic 1 — NFR8.** Directus **Activity** and **Revisions** are **enabled by default**; this story is **verification** that finance and PII collections emit usable audit trails. **Finance Manager / HR Manager** read access to Activity via filtered policies is **Epic 2** — use an **Administrator** (or equivalent) for **1.6** AC smoke tests.

**Checklist:** `_bmad-output/implementation-artifacts/1-6-enable-audit-logging-finance-employee-pii.md`

1. Create or edit an **`Invoice`** → **Activity** shows **create** / **update** with collection, item, user, time.
2. Edit **`Transaction`** (e.g. amount) → open the item’s **Revisions** / history → before/after visible.
3. **`EmployeePersonalInfo`** — same pattern on a safe test field if your data policy allows.
4. **`BankStatement`** — delete only if you have a disposable row and policy allows; otherwise skip and note in the artifact.

## Story 1.7 — Schema snapshot (`schema.json`)

**Epic 1 — reproducible metadata.** Canonical file: **`projects/internal-erp/directus/schema.json`** (commit to Git).

**Prereq:** `docker compose up` from **`projects/internal-erp/directus`** (same `.env` as normal dev).

**Windows (PowerShell):**

```powershell
cd projects\internal-erp\directus
.\scripts\snapshot-schema.ps1
# optional custom name: .\scripts\snapshot-schema.ps1 my-schema.json
```

**Linux / macOS:**

```bash
cd projects/internal-erp/directus
chmod +x scripts/snapshot-schema.sh   # once
./scripts/snapshot-schema.sh
```

**Manual (any OS):**

```bash
cd projects/internal-erp/directus
docker compose exec -T directus npx directus schema snapshot /tmp/schema-export.json
docker compose cp directus:/tmp/schema-export.json ./schema.json
docker compose exec -T directus rm -f /tmp/schema-export.json
```

**Apply (dangerous on shared DB — review Directus docs first):** copy the file **into** the container, then apply:

```bash
docker compose cp ./schema.json directus:/tmp/schema-apply.json
docker compose exec -T directus npx directus schema apply /tmp/schema-apply.json
```

Use only when you intend to overwrite metadata on **that** database.

**Verify / tasks:** `_bmad-output/implementation-artifacts/1-7-schema-snapshot-version-control.md`.

**GCP migration kickoff** (backup + cutover order): **`docs/gcp-migration-kickoff-checklist.md`**.

## Story 1.8 — Google Workspace SSO (OIDC) + `@expertflow.com` JIT

**PRD NFR12 / ADR-12.** Canonical rules: **`_bmad-output/planning-artifacts/identity-provider.md`**.

**Runbook (step-by-step):** **`docs/story-1-8-google-sso.md`** — Google Cloud OAuth client, redirect URIs, **`PUBLIC_URL`**, minimal **`directus_roles`** row for **`AUTH_GOOGLE_DEFAULT_ROLE_ID`**, env vars (templates in **`.env.example`**).

After editing `.env` (especially **`AUTH_*`**): **recreate** the container so `env_file` is re-read — `restart` alone keeps the old environment.

```bash
docker compose up -d --force-recreate
```

Check: `docker compose exec directus printenv` should show `AUTH_PROVIDERS`, `AUTH_GOOGLE_ISSUER_URL`, etc.

**Verify:** `_bmad-output/implementation-artifacts/1-8-external-oidc-identity-provider.md`.

**Open:** **JIT smoke** — first-time **`@expertflow.com`** user with **no** prior **`directus_users`** row — **`docs/story-1-8-google-sso.md`** §6b (tracked in sprint + **`1-8-external-oidc-identity-provider.md`**).

## Story 1.9 — RBAC tables (`Role`, `RolePermissions`, `UserToRole`)

Security prerequisite: PostgreSQL RBAC tables exposed in Directus for **`UserToRole.User`** (email, aligned with **`identity-provider.md`** / RLS **`app.user_email`**) and **`RolePermissions`**. **Epic 2** configures **`directus_roles`** and who may see these collections.

```bash
node projects/internal-erp/directus/scripts/apply-story-1-9-rbac-meta.mjs --dry-run
set DIRECTUS_URL=http://127.0.0.1:8055
set DIRECTUS_ADMIN_EMAIL=you@example.com
set DIRECTUS_ADMIN_PASSWORD=***
node projects/internal-erp/directus/scripts/apply-story-1-9-rbac-meta.mjs
```

**Second command** — refresh M2O templates (adds **`RolePermissions.Role`** and **`UserToRole.RoleName`** relations if missing). Run this **as its own line** (same `DIRECTUS_*` env vars as above):

```bash
node projects/internal-erp/directus/scripts/apply-m2o-dropdown-templates.mjs
```

**Windows PowerShell:** do **not** type `then` before the second command — that is shell syntax on Linux/macOS only. Use two separate lines, or one line with `;` between the two `node ...` commands.

**Verify:** `_bmad-output/implementation-artifacts/1-9-register-rbac-reference-collections-security.md`.  
**Companion doc:** `docs/story-1-9-rbac-collections.md`  
**Tests:** `node --test projects/internal-erp/directus/scripts/story-1-9-config.test.mjs`

## Story 1.10 — RLS session (`app.user_email`) hook extension

**PRD NFR13 / ADR-13:** For **every authenticated** user (including **Directus Administrator**), Directus runs `SET LOCAL ROLE <RLS_SESSION_ROLE>` (default **`directus_rls_subject`**) and sets **`app.user_email`** from **`directus_users.email`** (lowercased) on each **`items.query` / `items.read` / create / update / delete** — ERP rows follow **`UserToRole`** + PostgreSQL RLS; **no** admin bypass on this path.

- **DB users:** Directus **`DB_USER`** MUST be **`sterile_dev`** (no `policy_owner_access_*`). Use **`bs4_dev`** only for break-glass / migrations / `psql` (see Architecture **§8.1**). One-time: **`docs/sql/create-rls-session-role.sql`** + **`docs/sql/setup-sterile-dev.sql`** + **`docs/sql/grant-rls-subject-erp-schema.sql`**.

- **Code:** `extensions/rls-user-context/` (mounted by `docker-compose` → `/directus/extensions`).
- **Disable (break-glass / debug only):** `RLS_USER_CONTEXT_ENABLED=false` in `.env`.
- **Developers:** schema/metadata flows may use other code paths; **browsing collection data** uses the hook. Broad ERP visibility requires a matching **`UserToRole`** row (e.g. Finance **115**) for your email — same as any operator (see `docs/story-1-10-rls-user-context.md`).

After pulling the extension, **restart** Directus (`docker compose restart directus`).

**Verify:** `_bmad-output/implementation-artifacts/1-10-directus-rls-user-context-extension.md` (matrix still **PENDING** until **1.8** + **Epic 2** + test users).

**RLS blocked your `UserToRole` insert?** Expected for many admins — seed via SQL as **`bs4_dev`** (break-glass), not as Directus **`DB_USER`**: **`docs/sql/seed-user-to-role.example.sql`** and **`docs/story-1-8-google-sso.md`** §7.

**Directus `INTERNAL_SERVER_ERROR` on save:** `column rp.RoleName does not exist` on **`Invoice`** / **`Transaction`** — a PostgreSQL RLS **INSERT/UPDATE/DELETE** policy references **`"RolePermissions"`** as `rp` but uses **`rp."RoleName"`**. The RBAC table **`"RolePermissions"`** has **`"Role"`** (FK), not **`"RoleName"`**; **`"RoleName"`** is on **`"UserToRole"`**. Run **`docs/sql/fix-rls-invoice-transaction-finance-dml.sql`** as break-glass **`bs4_dev`** (replaces bad DML policies and adds Finance DML aligned with **`fix-rls-policies-v2.sql`** / **Accruals**). **Local (PowerShell):** start Cloud SQL Auth Proxy on **`127.0.0.1:5432`**, `cd projects\internal-erp\directus`, then **`.\scripts\run-fix-rls-invoice-dml.ps1`**. Uses **`psql`** from PATH if installed; **otherwise** pulls **`postgres:16-alpine`** and runs **`psql`** inside Docker (reaches the proxy via **`host.docker.internal`** — Docker Desktop on Windows/macOS). Password: **`$env:BS4_DEV_PASSWORD`** or **`BS4_DEV_PASSWORD=...`** in **`directus/.env`**. **Save** **`.env`** before running. **`.\scripts\run-fix-rls-invoice-dml.ps1 -VerifyEnvOnly`** prints password **length** only. **`-NoDocker`** forces native **`psql`** only. **Cursor / cloud agents usually cannot use your proxy** — run on your PC.

**`INTERNAL_SERVER_ERROR`: `Cannot read properties of undefined (reading 'match')`** when **creating/saving `Invoice`** — usually **not** RLS. The **`Invoice.image`** column is **`varchar`** (text), but Directus can still retain **file**-oriented **`meta`** (**`special`**, **`display`**, **`validation`**) because **`PATCH /fields` merges** with existing rows and often **drops `null`** — spreading old meta in a script is not enough. **Check the `image` field’s *Interface* tab** (not only *Schema*): must be **Input**, **Special** empty, **Validation** empty of broken regex. **Fast reset:** from **`projects/internal-erp/directus`**, `node scripts/fix-invoice-image-field-meta.mjs` (same env vars as Story 1.2). **Full:** `node scripts/apply-story-1-2-financial-meta.mjs` (rebuilds `image` meta without re-inheriting file validation/display). **Isolate:** **`RLS_USER_CONTEXT_ENABLED=false`** + restart; if it still fails, not the RLS hook. **`docker compose logs directus`** for the stack trace.

**Invoice form cleanup:** PostgreSQL already assigns **`Invoice.id`** via **`nextval('invoice_id_counter'::regclass)`**; it should **not** be shown as an editable field during create. Current source-of-truth docs / mapping also do **not** rely on **`Invoice.employee_id`** or **`Invoice.image`** for the intended Finance workflow; treat them as **legacy DB columns** until a formal schema cleanup story drops them. To make Directus match the intended UX now, run **`node scripts/fix-invoice-form-meta.mjs`** from **`projects/internal-erp/directus`**: hides **`id`** (and marks it readonly), hides **`employee_id`**, hides **`image`**. This is **safe UI cleanup**; dropping the SQL columns is a separate schema change because Story **1.2** metadata and current schema dumps still include them.

**Hide editable `id` fields everywhere:** Directus can expose raw **`id`** fields on create forms even when operators should never type them. Story apply scripts now default plain **`id`** fields to **hidden + readonly** for finance / org-HR / RBAC metadata runs. For the current instance, run **`node scripts/fix-all-id-fields-meta.mjs`** from **`projects/internal-erp/directus`** to patch all existing collections in-place.

**Drop legacy `Transaction.expense_id`:** The repo’s schema drift report marks **`Transaction.expense_id`** as an extra DB-only field not in the intended mapping. Directus Story **1.2** metadata no longer creates the **Transaction → Expense** relation and now hides the field while it still exists. To remove it from PostgreSQL for real, run **`.\scripts\run-drop-legacy-transaction-expense-field.ps1`** (same **Cloud SQL Auth Proxy + `BS4_DEV_PASSWORD`** pattern as other break-glass SQL runners). SQL file: **`docs/sql/drop-legacy-transaction-expense-field.sql`**.

## M2O dropdown labels (human-readable, all relations)

**BMAD (product-agnostic):** `**_bmad-output/planning-artifacts/data-admin-surface-requirements.md`** — single canonical spec for **any** database admin/CMS; **PRD NFR14** references it only.

**Architecture (Directus binding):** **ADR-14** + **§4.4** in `_bmad-output/planning-artifacts/architecture-BMADMonorepoEFInternalTools-2026-03-15.md`. Agents: `**.cursorrules`**.

Directus uses `**meta.options.template`** on the **M2O** interface for the picker, but **collection tables and item layouts** use the field **display**. For human-readable FKs everywhere, each M2O field needs:

- `**meta.display`:** `related-values`
- `**meta.display_options.template`:** same string as `**meta.options.template`** (e.g. `{{Name}}`, `{{EmployeeName}} ({{email}})`)

Scripts set all three. The `**apply-m2o-dropdown-templates`** script:

1. **Creates missing** Story **1.2 / 1.3 / 1.9** M2O relations (`POST /relations`) so Directus can hydrate labels (without a relation row, **Profit Center** stays a raw integer in the item view).
2. Upgrades plain `**input`** FKs and legacy `**interface: m2o`** to `**select-dropdown-m2o**` + `**special: m2o**` + `**related-values**` (Directus **11.12** Data Studio).

To align **every** ERP relation FK from `/relations`, run:

```bash
node projects/internal-erp/directus/scripts/apply-m2o-dropdown-templates.mjs --dry-run
node projects/internal-erp/directus/scripts/apply-m2o-dropdown-templates.mjs
node projects/internal-erp/directus/scripts/apply-m2o-dropdown-templates.mjs --force
```

Templates come from `scripts/lib/collection-display-templates.mjs` (merged Story 1.2 + 1.3 + a few extras), then **GET `/collections/:name`** when a collection is not in that map.

**Tests:** `node --test projects/internal-erp/directus/scripts/collection-display-templates.test.mjs`

## Backup & colleague handoff

If this desktop is lost, a colleague can continue from another machine as long as **Git**, **secrets**, **the database**, and (if used) **uploads** are covered.

### 1. Git (code & docs)

- **Commit and push** this monorepo regularly: `Dockerfile`, `docker-compose.yml`, `docker/patch-*.cjs`, `README.md`, `.env.example`, `docs/`, `extensions/`, and `**_bmad-output/`** planning artifacts you care about.
- **Never commit** `.env` (gitignored). Teammates copy `.env.example` → `.env` and fill values from your team’s **secret store** (1Password, Secret Manager, etc.).
- **Branch / PR workflow:** use `main` (or your team default) as the source of truth so handoff is “clone + branch”.

### 2. PostgreSQL (Cloud SQL — already off your laptop)

- **Your data is not only on this PC.** `bidstruct4` lives on **Google Cloud SQL**. Directus metadata (`directus_`* tables), ERP data, and roles/users are there.
- **Turn on / verify Cloud SQL backups** in GCP (automated backups, PITR if your org requires it). That is the primary **database** safety net — not a file on the desktop.
- **Optional manual export** (e.g. before a risky migration), with proxy running and a tool that can connect:
  ```bash
  pg_dump --host=127.0.0.1 --port=5432 --username=YOUR_USER --format=custom --file=bidstruct4_backup.dump bidstruct4
  ```
  Store the dump in **GCS** or another secure team location — **not** in Git (binary + sensitive).

### 3. Local `uploads/` (files)

- Anything uploaded through Directus while using **default local storage** sits under `**uploads/`** on this machine (contents are **gitignored**).
- **Handoff options:** copy `uploads/` to shared storage, **or** configure **S3 / GCS** (or similar) in Directus later so files are not desktop-only.

### 4. Access a colleague must receive (out of band)

- Git **remote** URL + permission to push (or fork process).
- **GCP**: ability to run **Cloud SQL Auth Proxy** (or equivalent) and DB credentials for **`sterile_dev`** (matches **`DB_USER`** for Directus). Optionally **`bs4_dev`** for break-glass / DBA-style `psql` (see **Story 1.10** / **`docs/sql/setup-sterile-dev.sql`**).
- **Directus**: at least one **admin** account (or reset path via CLI / DBA).

### 5. Quick “new laptop” checklist

1. Clone repo, install Docker + Auth Proxy, `cp .env.example .env` and fill secrets.
2. Start proxy → `docker compose build` → `docker compose up`.
3. Restore or sync `**uploads/`** if you rely on local file storage.
4. Open `http://localhost:8055` and sign in.

## Troubleshooting

### `relation "directus_migrations" does not exist` (API down; CLI `database` commands fail)

**Symptoms:** Container exits or the admin UI shows a network error; logs show `select "version" from "directus_migrations"` / `42P01`.

**Cause:** Other `directus_*` tables exist (often in **`BS4Prod09Feb2026`**), but the **`directus_migrations`** tracking table was never created or was dropped. **`node cli.js database migrate:latest` cannot fix this by itself** — the CLI loads the DB layer and queries that table before it can create anything.

**Fix (DBA / break-glass role — not `sterile_dev`):**

1. Connect to **`bidstruct4`** with a user that may **`CREATE TABLE`** on schema **`BS4Prod09Feb2026`** (e.g. **`bs4_dev`** / `postgres` per your runbook).
2. Run the generated script **`docs/sql/generated-backfill-directus-migrations.sql`** (creates the table if missing and inserts one row per built-in migration shipped with image **`11.12.0`**, so Directus does not try to re-apply migrations that already match your schema).
3. From `projects/internal-erp/directus`:  
   `docker compose run --rm directus node cli.js database migrate:latest`  
   then `docker compose up -d directus`.

To **regenerate** that file after changing the Directus image tag, use **`docs/sql/backfill-directus-migrations.sh`** inside the same image (see comments in the script). **`docs/sql/ensure-directus-migrations-table.sql`** is only the `CREATE TABLE` fragment if you prefer a minimal hand-run step.

### `Error: Database doesn't have Directus tables installed` (after bootstrap / migrate)

Your logs may show **both**:

1. `**Error: Database is already installed`** during `bootstrap`, then
2. `**Running migrations…` / `Database up to date`**, then
3. `**ERROR: Database doesn't have Directus tables installed**` when the app starts.

That means the DB is in an **inconsistent state**: something (often leftover `**directus_`*** metadata) makes the **installer/seed** think Directus is already there, but the **runtime** check does not see a complete system schema (partial drop, wrong `search_path`, or tables in a schema the app does not use).

**Do this (backup / DBA approval on shared DB):**

1. In **DBeaver**, on `**bidstruct4`**, run:
  ```sql
   SELECT table_schema, table_name
   FROM information_schema.tables
   WHERE table_name LIKE 'directus%'
   ORDER BY 1, 2;
  ```
2. **If `directus_*` live in a non-`public` schema** (e.g. `**BS4Prod09Feb2026`**): Directus defaults to `**public`** first. **Try `DB_SEARCH_PATH`** before dropping anything.
  **Use the exact name PostgreSQL stores.** DBeaver’s navigator label can differ from the catalog.
   Prefer `**pg_catalog`** (canonical):
   Compare with `information_schema.schemata` if needed:
   **In `.env` (use the built image from this folder — it patches mixed-case `::regnamespace`):**
  - **One schema:** `DB_SEARCH_PATH=BS4Prod09Feb2026` (or whatever `nspname` is).
  - **Several schemas** (e.g. ERP data in `BS4Prod09Feb2026` and **PostGIS in `public`**): do **not** put commas in a single value (Knex would treat that as one invalid name). Use Directus/Knex nested env keys:
    ```env
    DB_SEARCH_PATH__0=BS4Prod09Feb2026
    DB_SEARCH_PATH__1=public
    ```
   **Why mixed-case used to fail:** `@directus/schema` bound the schema as `$1::regnamespace`. Unquoted identifier rules lower-case the string, so logs showed `bs4prod09feb2026` even when `.env` had capitals. The local `**Dockerfile`** patches that binding so capitals match `**pg_namespace.nspname`**.
   **If you see `schema "…" does not exist`:** the name in `.env` does not match `**pg_namespace.nspname`** on the **same** database/user as Docker (`DB_DATABASE`, `DB_USER`), or the container is not reaching the same instance as DBeaver.
   **If you see `3F000` / `invalid_schema_name`:** confirm `nspname` with the SQL above, then rebuild: `docker compose build --no-cache` and `docker compose up`.
   Multi-schema quirks: [Directus / Postgres search path](https://github.com/directus/directus/discussions/12057).
3. **If you still need a clean reinstall** and `**directus_`* are in `public`** (or your chosen schema): drop those tables **only** if you have **no Directus data to keep** and **the right DB role**:
  ```sql
   -- Example pattern (adjust schema/name from your query result):
   -- DROP TABLE IF EXISTS public.directus_activity CASCADE;
  ```
4. `**ERROR: must be owner of table directus_…` (SQLState `42501`)**
  Your Directus **`DB_USER`** (`**sterile_dev`**) is **not the owner** of those tables. You **cannot** drop or alter them until:
  - A **superuser** or **table owner** runs the drops (often connect as break-glass **`bs4_dev`** if that role owns the objects), **or**
  - Your **DBA** grants the needed rights / performs cleanup.
   Do **not** assume `sterile_dev` can delete objects created by another role or migration job.
5. `docker compose down` → `docker compose up` again (after any `.env` or DBA change).

### `Error: Database is already installed` (healthy case)

On **later** container starts, `**bootstrap`** may exit with this after `**migrate:latest`** runs — that is expected with the compose `**command**` (`bootstrap || migrate:latest`). If the app **still** fails with **“doesn’t have Directus tables”**, use the section above (corrupt / wrong schema).

### `TypeError: Cannot read properties of undefined (reading 'primary')` during migrations

Seen when `**directus/directus:11`** (floating / newest 11.x) runs **first-time install** against `**bidstruct4`**, which already has many tables and FKs. A migration (e.g. **Add Project Owner**) introspects relations and can crash.

**Do this:**

1. `docker compose down`
2. In **DBeaver**, check schema `**public`** on `**bidstruct4`**: if `**directus_***` tables were created by the failed run, either:
  - **Drop all `directus_%` tables** in `public` (only if you have no Directus data to keep — backup first), **or**
  - Ask your DBA for a clean approach on a shared DB.
3. Ensure `docker-compose.yml` uses the **pinned** image (`**11.12.0`**, not bare `:11`).
4. `docker compose pull` then `docker compose up` again.

If it still fails, try `**11.13.0`** or `**11.14.1**`, or set `**DB_EXCLUDE_TABLES**` (comma-separated) to exclude legacy tables that confuse introspection — see [Directus database env](https://directus.io/docs/configuration/database).

### Login: “Wrong username or password” or CLI `No such user by this email`

`**ADMIN_EMAIL` / `ADMIN_PASSWORD` in `.env` are only used when `bootstrap` creates the first project.** They are **not** synced later. If `**users passwd`** prints `**No such user by this email`**, that address is **not** in `directus_users` (bootstrap may have hit “already installed” without an admin row, or a different email was used).

1. In **DBeaver**, find where Directus system tables live and list users (adjust schema if yours is not `BS4Prod09Feb2026`):
  ```sql
   SELECT table_schema FROM information_schema.tables
   WHERE table_name = 'directus_users';

   SELECT id, email, status FROM "BS4Prod09Feb2026".directus_users;
  ```
2. Get the **Administrator** role id:
  ```sql
   SELECT id, name FROM "BS4Prod09Feb2026".directus_roles;
  ```
   If this returns **no rows**, roles were never seeded in that schema. **Only** check `public` if your inventory query shows `directus_roles` there — on many installs (including yours) **all `directus_*` tables live only under the ERP schema**, so `public.directus_roles` **does not exist** and Postgres will error with *relation "public.directus_roles" does not exist*.
   If **every** `directus_roles` table is empty, run **bootstrap** once (with the stack up) so Directus can create default roles and admin — it uses your `.env` `**ADMIN_EMAIL`** / `**ADMIN_PASSWORD`**:
   If that prints **“Database already initialized, skipping install”** (or similar) and `**directus_roles` stays empty**, bootstrap will **not** re-seed. Try **creating an admin role** with the CLI (uses the same DB connection as the running container):
   Then confirm a row exists:
   If `**roles create`** errors (e.g. policies / permissions), the DB is still inconsistent — involve a DBA and the **“doesn’t have Directus tables”** section; do **not** guess UUIDs.
3. **Create** the admin user (only after step 2 shows at least one role): copy the **Administrator** row’s `**id`** (a real UUID) and paste it **instead of** the placeholder below — do **not** type the characters `<` or `>`.
  ```bash
   docker compose exec directus npx directus users create --email "you@example.com" --password "YourSecurePassword" --role "PASTE-ADMINISTRATOR-ROLE-UUID-HERE"
  ```
4. Sign in at `http://localhost:8055` with that email and password.

**Noise in CLI logs:** `Collection "ChatLogs" doesn't have a primary key` is unrelated to login. PostGIS-related **WARN** lines during one-off CLI commands are often from schema introspection and can be ignored if the app runs.

### PostGIS / “PostGIS isn’t installed” (Cloud SQL / DBeaver)

1. On database `**bidstruct4`**, install **core PostGIS** only (run **by itself** — do not bundle with topology in one batch if the second line can fail):
  ```sql
   CREATE EXTENSION IF NOT EXISTS postgis SCHEMA public;
  ```
2. Verify:
  ```sql
   SELECT extname, extversion, n.nspname AS schema
   FROM pg_extension e
   JOIN pg_namespace n ON n.oid = e.extnamespace
   WHERE extname LIKE 'postgis%';
  ```
3. `**postgis_topology`:** PostgreSQL requires it in schema `**topology`**, not `public`. If you run `CREATE EXTENSION postgis_topology SCHEMA public`, you get: *extension "postgis_topology" must be installed in schema "topology"*. **Directus usually does not need topology** — skip it unless you use topology features. If you need it:
  ```sql
   CREATE SCHEMA IF NOT EXISTS topology;
   CREATE EXTENSION IF NOT EXISTS postgis_topology SCHEMA topology;
  ```
4. Keep `**DB_SEARCH_PATH__1=public**` (with your ERP schema as `__0`) so `**public**` types/functions resolve.

### DBeaver: `permission denied for schema public` (SQLState `42501`)

Your Directus **`DB_USER`** (`**sterile_dev**`) may have rights on `**BS4Prod09Feb2026**` but **not** `**USAGE` on schema `public`**. That is common on **PostgreSQL 15+** / **Cloud SQL** when `public` is locked down. You will not be able to run `SELECT … FROM public.…` as `sterile_dev` until a privileged role fixes it.

**Inspect the schema that actually holds Directus** (Cloud SQL Studio as `postgres`, etc.). If `directus_roles` is **not** in `public`, qualify the schema (see `information_schema` query in the Login section above).

**If Directus + PostGIS should use `public`**, a DBA can grant the minimum access to **`sterile_dev`** (run as **`postgres`**, **`bs4_dev`**, or another privileged role — adjust database/role names):

```sql
GRANT USAGE ON SCHEMA public TO sterile_dev;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO sterile_dev;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO sterile_dev;
-- optional: future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO sterile_dev;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO sterile_dev;
```

Tighten grants if your security team requires **only** PostGIS (not all `public` tables). **`sterile_dev`** needs at least **`USAGE` on `public`** for typical PostGIS + `search_path` setups.

### Schema / `search_path`

If ERP tables live in a non-`public` schema (e.g. `**BS4Prod09Feb2026**`), you may need `**DB_SEARCH_PATH**` (or equivalent Knex `searchPath`) in `.env` so Directus and your data agree — confirm with your team which schema is canonical.

## Production note

**Target: VM only** — Directus runs on GCE **`directus-erp`** (Docker / Compose on the VM), not Cloud Run.

**What to configure where:** `_bmad-output/implementation-artifacts/directus-gcp-runtime-context.md` (section **“What to add where (VM only)”**). Summary:

- **Secrets and `DB_*` on the VM** (`.env` or Secret Manager): **`DB_USER=sterile_dev`** only; never **`bs4_dev`** for the running app; **`PUBLIC_URL`** = real HTTPS URL; **`DB_HOST`** = how the **VM** reaches Cloud SQL (proxy on VM or private IP).
- **This repo:** infrastructure **facts** only in that markdown file (no passwords).

### Optional: Cloud Run script (not used for current prod)

`deploy-directus-gcp.ps1` + `deploy-directus-gcp.env.example` deploy to **Cloud Run** for experiments only. **Ignore** for **`directus-erp`** VM deployment.
