# Deploy Directus to Google Cloud (colleague access)

**BMAD traceability:** Hosting on GCP was **already planned**: Epic 1 **Story 1.1** (`_bmad-output/implementation-artifacts/1-1-docker-compose-google-cloud-run-setup.md`), **PRD NFR2 / NFR9**, **Architecture §2.2 + ADR-10** — **canonical production = Google Cloud Run** + **Secret Manager** + **Cloud SQL** via proxy.  
This document adds a **BMAD-consolidated path on Compute Engine**: **VM + Docker Compose** + **Cloud SQL Auth Proxy** sidecar (same **Dockerfile** as local). It **does not** replace ADR-10; when Cloud Run is live, prefer that path per architecture.

Project context: **[expertflowerp](https://console.cloud.google.com/compute/overview?project=expertflowerp)**.

On GCP, the proxy runs **inside** Compose on the VM (not on your laptop).

---

## Choose a shape

| Option | Best when | Notes |
|--------|-----------|--------|
| **Compute Engine VM + Docker Compose** | Match local image; control `uploads/` + `extensions/` | **This doc — step-by-step below.** |
| **Cloud Run** | Scale-to-zero, managed HTTPS | See README Story **1.1** artifact. |
| **GKE** | Many services on Kubernetes | Usually overkill for one Directus. |

---

## Step-by-step: new VM → running Directus

Do these from **your workstation** (with `gcloud` installed and authenticated) unless noted “**on VM**”.

### A. Gather values

| Value | Example | Where |
|--------|---------|--------|
| **GCP project** | `expertflowerp` | Console project picker |
| **Cloud SQL connection name** | `expertflowerp:europe-west1:my-db` | Cloud SQL → instance → **Connection name** |
| **Region / zone** | `europe-west1-b` | Same region as Cloud SQL helps latency |
| **VPC** | Default or shared VPC | VM must reach Cloud SQL (**private IP** preferred) |

### B. IAM — VM must open Cloud SQL

The VM’s **service account** needs **`roles/cloudsql.client`**.

**Option 1 — use Compute Engine default SA** (quick):

1. Console → **IAM** → find `PROJECT_NUMBER-compute@developer.gserviceaccount.com`.
2. **Grant** role **Cloud SQL Client**.

**Option 2 — dedicated SA** (cleaner):

```bash
export PROJECT_ID=expertflowerp
gcloud config set project "$PROJECT_ID"

gcloud iam service-accounts create directus-vm \
  --display-name="Directus GCE VM"

SA_EMAIL="directus-vm@${PROJECT_ID}.iam.gserviceaccount.com"

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/cloudsql.client"
```

When creating the VM (next step), set **Identity and API access** → **Service account** to `directus-vm@...`.

### C. Firewall

**Temporary HTTP (dev only):** expose Directus on **8055** to the internet.

```bash
export PROJECT_ID=expertflowerp
gcloud compute firewall-rules create allow-directus-8055 \
  --project="$PROJECT_ID" \
  --direction=INGRESS \
  --action=ALLOW \
  --rules=tcp:8055 \
  --source-ranges=0.0.0.0/0 \
  --target-tags=directus-vm
```

**Production:** use **80/443** only, terminate TLS (Caddy/nginx) in front of `127.0.0.1:8055`, tighten **source-ranges** or use **IAP** / VPN.

When creating the VM, add **Network tags**: `directus-vm`.

### D. Create the VM (Console or CLI)

**Console:** [VM instances](https://console.cloud.google.com/compute/instances?project=expertflowerp) → **Create** — Ubuntu 22.04, e.g. **e2-medium**, attach SA with **Cloud SQL Client**, network tag `directus-vm`, same VPC as Cloud SQL private IP.

**CLI example:**

```bash
export PROJECT_ID=expertflowerp
export ZONE=europe-west1-b
export VM_NAME=directus-erp

gcloud compute instances create "$VM_NAME" \
  --project="$PROJECT_ID" \
  --zone="$ZONE" \
  --machine-type=e2-medium \
  --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud \
  --boot-disk-size=40GB \
  --tags=directus-vm \
  --service-account="directus-vm@${PROJECT_ID}.iam.gserviceaccount.com" \
  --scopes=https://www.googleapis.com/auth/cloud-platform
```

*(If you use the default compute SA instead, omit `--service-account` and grant that SA `roles/cloudsql.client` in IAM.)*

### E. Copy repo files to the VM

**On your workstation** (paths adjusted):

**Recommended:** `git clone` the monorepo on the VM, then `cd projects/internal-erp/directus` (keeps `docker/` patch, extensions, and scripts in sync).

**Minimal `scp` from your workstation** (must include **`docker/`** — the **Dockerfile** copies `docker/patch-directus-pg-regnamespace.cjs`):

```bash
gcloud compute scp --recurse \
  projects/internal-erp/directus/Dockerfile \
  projects/internal-erp/directus/docker \
  projects/internal-erp/directus/docker-compose.yml \
  projects/internal-erp/directus/docker-compose.gcp-vm.example.yml \
  projects/internal-erp/directus/.env.gcp-vm.example \
  projects/internal-erp/directus/ecosystem.config.cjs \
  projects/internal-erp/directus/extensions \
  projects/internal-erp/directus/scripts \
  USER@VM_EXTERNAL_IP:~/directus/
```

Create empty dirs on the VM if missing: `mkdir -p uploads extensions` (uploads/extensions may be empty at first).

**Do not** upload `.env` via insecure channels with real passwords; prefer **Secret Manager** + a small script on the VM, or **SSH + editor** on the VM only.

### F. Install Docker (**on VM**)

```bash
chmod +x scripts/gcp-vm-bootstrap.sh
./scripts/gcp-vm-bootstrap.sh
# log out and SSH back in, or: newgrp docker
```

### G. Configure `.env` and compose (**on VM**)

```bash
cd ~/directus   # or your path

cp docker-compose.gcp-vm.example.yml docker-compose.gcp-vm.yml
cp .env.gcp-vm.example .env
nano .env   # fill KEY, SECRET, PUBLIC_URL, DB_*, CLOUD_SQL_INSTANCE, SSO vars — see .env.example
```

**Required in `.env` for this compose file:**

- `CLOUD_SQL_INSTANCE=project:region:instance` (used by the proxy service).
- Same Directus/DB vars as local, but **`PUBLIC_URL`** = your real **https://** URL when TLS is ready (or `http://VM_IP:8055` for a quick test — update before SSO).

The compose file **overrides** `DB_HOST` / `DB_PORT` for the Directus container — do **not** rely on `host.docker.internal` on the VM.

### H. Build and start (**on VM**)

```bash
docker compose -f docker-compose.gcp-vm.yml build
docker compose -f docker-compose.gcp-vm.yml up -d
docker compose -f docker-compose.gcp-vm.yml logs -f directus
```

Open `http://VM_EXTERNAL_IP:8055` (if firewall **8055** is open). After TLS + domain, set **`PUBLIC_URL`** and add Google OAuth origins — **`docs/story-1-8-google-sso.md`**.

### I. Cloud SQL private IP

If the instance uses **private IP** only, the VM must be in a **subnet with private service access / VPC** to Cloud SQL. If the proxy logs **connection refused** or **timeout**, fix VPC/peering first; see [Cloud SQL private IP](https://cloud.google.com/sql/docs/postgres/configure-private-ip).

Optional proxy flag (private IP only):

```yaml
# In docker-compose.gcp-vm.yml under cloud-sql-proxy command, add:
# - "--private-ip"
```

---

## Prerequisites summary

1. **Billing** on the project.
2. **Cloud SQL** Postgres (`bidstruct4`) — connection name for `CLOUD_SQL_INSTANCE`.
3. **VM SA** with **`roles/cloudsql.client`**.
4. **VPC** path from VM → Cloud SQL (private IP recommended).

---

## HTTPS and public URL

1. Point DNS at the VM (or use a load balancer + managed certificate).
2. Put **Caddy**, **nginx + certbot**, or **Traefik** in front of `127.0.0.1:8055`.
3. Set **`PUBLIC_URL=https://your-host`** (must match the browser URL).

---

## Directus env: local vs VM

| Variable | Local | VM (this compose) |
|----------|--------|-------------------|
| `PUBLIC_URL` | `http://127.0.0.1:8055` | `https://…` or `http://VM:8055` for smoke test |
| `DB_HOST` | `host.docker.internal` | **Forced to `cloud-sql-proxy`** in compose |
| `CLOUD_SQL_INSTANCE` | (not used) | **Required in `.env`** for proxy |
| `KEY` / `SECRET` | dev | **New** values for prod-style VM |

---

## Google OAuth (Story 1.8)

Add to the OAuth client:

- **JavaScript origin:** `https://<your-host>`
- **Redirect:** `https://<your-host>/auth/login/google/callback`

See **`docs/story-1-8-google-sso.md`**.

---

## Security checklist

- [ ] `.env` not in git; production secrets in **Secret Manager** when hardened.
- [ ] Firewall: tighten **8055** or move to **443** only.
- [ ] **`AUTH_DISABLE_DEFAULT`**: SSO-only when policy allows.
- [ ] Cloud SQL backups; snapshot VM boot disk if needed.

---

## Related files

- **`docs/gcp-migration-kickoff-checklist.md`** — backup + cutover order.
- **`docker-compose.gcp-vm.example.yml`** — proxy + Directus.
- **`.env.gcp-vm.example`** — template including `CLOUD_SQL_INSTANCE`.
- **`scripts/gcp-vm-ensure-docker.sh`** — Verifies Docker + Compose v2; installs only if missing (idempotent). **`scripts/gcp-vm-bootstrap.sh`** calls the same script for backward compatibility.
- **`docs/story-1-8-google-sso.md`** — OAuth.

---

## References

- [Compute Engine](https://console.cloud.google.com/compute/overview?project=expertflowerp)
- [Cloud SQL Auth Proxy](https://cloud.google.com/sql/docs/postgres/connect-auth-proxy)
- [Directus config](https://docs.directus.io/self-hosted/config-options.html)
