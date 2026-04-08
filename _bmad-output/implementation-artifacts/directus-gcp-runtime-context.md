# Directus GCP runtime context (reference for dev / agents)

**Purpose:** Single place to record where production-style Directus runs in GCP, how PostgreSQL is reached, and **non-negotiable DB account rules** (RLS). Update this file when infrastructure changes.

**Deployment model:** **VM only** — Directus runs on GCE **`directus-erp`** (Docker / Compose on the VM). **Cloud Run is not** the chosen production target for this project unless that decision changes.

**Last updated:** 2026-03-24

---

## What to add where (VM only)

| Information | Where it lives |
|-------------|----------------|
| **Secrets** (`KEY`, `SECRET`, `DB_PASSWORD` for `sterile_dev`, OAuth client secrets, etc.) | **On the VM only** — e.g. `.env` beside compose (not in git), **Secret Manager** + env injection, or your platform’s vault. Never commit. |
| **`PUBLIC_URL`** | VM env — must be the URL users open (HTTPS via load balancer / reverse proxy / public IP as designed). |
| **`DB_USER` / `DB_PASSWORD`** | VM env — **`DB_USER=sterile_dev`** always for the running Directus container. |
| **`DB_HOST` / `DB_PORT`** | VM env — whatever reaches Cloud SQL **from the VM** (e.g. **Cloud SQL Auth Proxy** on `127.0.0.1:5432`, or **private IP** if the VPC is wired that way). |
| **`DB_DATABASE`**, **`DB_SEARCH_PATH__0`**, **`DB_SEARCH_PATH__1`** | VM env — same as local: `bidstruct4`, `BS4Prod09Feb2026`, `public`. |
| **Image** | Build on the VM (`docker build` from repo) **or** build/push in CI and **pull on the VM** — team choice. Use the repo **`Dockerfile`**. |
| **Infra facts** (VM name, zone, Cloud SQL connection name, policy notes) | **This file** — no secrets, only reference. |

**Ignore for production:** `deploy-directus-gcp.ps1` / `deploy-directus-gcp.env` — those target **Cloud Run**, not this VM (kept in repo only if someone experiments).

### Migration script (laptop → `directus-erp`)

Repo files: `projects/internal-erp/directus/migrate-directus-to-vm.ps1` and `directus-vm-migrate.env.example` (copy to **`directus-vm-migrate.env`**, gitignored).

**Fill in the env file:**

| Variable | What to supply |
|----------|----------------|
| `GCP_PROJECT`, `GCP_ZONE`, `GCP_VM_NAME` | Usually `expertflowerp`, `europe-west6-a`, `directus-erp` (see Compute table below). |
| `VM_DEPLOY_PATH` | Absolute path on the VM where the Directus folder contents should live (e.g. `/opt/directus`). |
| `LOCAL_DIRECTUS_DIR` | Optional; defaults to the folder that contains the script. Set if you run the script from elsewhere. |
| `GCP_SSH_USER` | Optional; set if `gcloud compute ssh` does not use the right Unix account (OS Login / username mismatch). |
| `VM_USE_SUDO_FOR_DEPLOY` | `true` if `/opt/...` requires `sudo` to create; script runs `chown` back to the SSH user for Docker. |
| `VM_ENV_FILE_TO_UPLOAD` | Optional Windows path to a **production** `.env` to copy to `$VM_DEPLOY_PATH/.env` after extract. Omit if you maintain `.env` only on the VM. |
| `SKIP_BUILD`, `DRY_RUN` | Optional toggles (see example file). |

**The script does not configure:** Cloud SQL Auth Proxy, systemd, firewall, HTTPS reverse proxy, or **`PUBLIC_URL`** — those stay in your VM runbook and in `.env`. Before first `docker compose up`, the VM must reach Postgres (proxy or private IP) and **`DB_USER=sterile_dev`** must be set in `.env` as in the RLS section above.

---

## Compute: Google Compute Engine VM (“Directus Cloud”)

| Field | Value |
|--------|--------|
| **VM name** | `directus-erp` |
| **Project (display)** | ExpertflowERP |
| **Project ID** | `expertflowerp` |
| **Zone** | `europe-west6-a` |
| **OS image** | Ubuntu 22.04 (`ubuntu-2204-jammy-*`, x86_64) |
| **Console URL pattern** | `https://console.cloud.google.com/compute/instancesDetail/zones/europe-west6-a/instances/directus-erp?project=expertflowerp` |

**Operational access:** SSH from GCP Console or `gcloud compute ssh` (standard VM workflows). Install/run Docker (or Compose) on the VM per team runbook; this file does not prescribe the exact service manager.

**Backup reminder (GCP banner):** VM is not fully covered until a **snapshot schedule** or **backup plan** is attached—coordinate with platform/DBA.

---

## PostgreSQL: Cloud SQL

| Field | Value |
|--------|--------|
| **Instance connection name** | `expertflowerp:europe-west6:expertflowerp1` |
| **Database name** | `bidstruct4` (confirm in Secret Manager / env if renamed) |
| **ERP / Directus metadata schema** | `BS4Prod09Feb2026` (matches `DB_SEARCH_PATH__0` in local Directus `.env`) |
| **Secondary search_path schema** | `public` (e.g. PostGIS — matches `DB_SEARCH_PATH__1`) |

**Local development (workstation):** **Cloud SQL Auth Proxy** is used; typical JDBC/CLI target is **`127.0.0.1:5432`** → tunnels to `expertflowerp:europe-west6:expertflowerp1`.

Example proxy command (Windows):

```text
.\cloud-sql-proxy.exe expertflowerp:europe-west6:expertflowerp1
```

**On the GCE VM:** use either the **Cloud SQL Auth Proxy** as a service, **private IP + VPC**, or another approved pattern—must end with Directus seeing a stable `DB_HOST`/`DB_PORT` (document in runbook).

---

## Database credentials policy (RLS) — **mandatory**

| Role | Use for Directus / app runtime? | Why |
|------|----------------------------------|-----|
| **`sterile_dev`** | **Yes — only this account** for Directus `DB_USER` in all environments where RLS must apply. | Subject to PostgreSQL RLS; matches Architecture intent for normal API traffic. |
| **`bs4_dev`** | **No** for Directus application database user. | Break-glass / owner-style usage can **bypass or undermine RLS**; reserve for DBA migrations, manual fixes, DBeaver admin tasks—not the running Directus process. |

**Agent / implementer checklist:**

- Set **`DB_USER=sterile_dev`** (and matching `DB_PASSWORD`) in VM `.env`, Secret Manager references, and any deploy scripts that materialize runtime env.
- Do **not** reuse DBeaver `bs4_dev` credentials for Directus container env.
- One-off SQL repair scripts may still use `bs4_dev` **only** when explicitly required and approved (e.g. DDL `CREATE TABLE` that `sterile_dev` cannot run)—never as the long-lived Directus DB user.

---

## Related repo artifacts

- **Local stack:** `projects/internal-erp/directus/docker-compose.yml`, `.env.example`
- **Image build:** `projects/internal-erp/directus/Dockerfile` (regnamespace patch, Python `bank-import`, bundled `extensions/`)
- **Cloud Run script (not used for VM-only prod):** `projects/internal-erp/directus/deploy-directus-gcp.ps1` — optional experiment only; production is **GCE `directus-erp`** + env as in **What to add where** above.
- **Migration repair (missing `directus_migrations`):** `projects/internal-erp/directus/docs/sql/generated-backfill-directus-migrations.sql` (run with appropriate privileged role; not a substitute for `sterile_dev` at runtime)
- **VM code deploy:** `projects/internal-erp/directus/migrate-directus-to-vm.ps1`, `directus-vm-migrate.env.example`

---

## Changelog

| Date | Change |
|------|--------|
| 2026-03-24 | `migrate-directus-to-vm.ps1` + `directus-vm-migrate.env.example`; migration env table; `directus-vm-migrate.env` gitignored. |
| 2026-03-24 | VM `directus-erp`, Cloud SQL `expertflowerp1`, `sterile_dev`-only runtime DB user; **VM-only** prod; “What to add where” table; Cloud Run script out of scope for prod. |
