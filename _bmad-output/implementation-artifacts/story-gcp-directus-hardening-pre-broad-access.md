# Story: GCP Directus hardening before broad employee access

Status: ready-for-dev

## Story

As a **security- and operations-conscious team**,

I want the **Directus instance on GCP** (Docker on Compute Engine, Cloud SQL) **hardened and documented**,

so that we can **onboard a wider set of employees** without exposing ERP data over insecure channels or an unnecessarily large attack surface.

## Background (current state — verify during implementation)

- Directus runs on a GCE VM with Docker; database is Cloud SQL Postgres, typically reached via Cloud SQL Auth Proxy on the VM.
- Public entry may use a **nip.io** hostname and **HTTP**; Google OAuth was configured to require a real hostname (not a bare IP).
- Access control: roles/policies in Directus; ERP table permissions were automatable via `projects/internal-erp/directus/scripts/apply-erp-staff-policy-vm.ps1` and SQL under `projects/internal-erp/directus/docs/sql/`.
- Known follow-ups from earlier rollout: **uploads directory** may not be writable inside the container; **custom extensions** may log missing dependency warnings — treat as separate cleanup unless they block hardening acceptance.

This document is **self-contained**: implement using any editor or AI assistant. All paths are **relative to the repository root**.

## Acceptance criteria

1. **HTTPS end-to-end for the browser** — Users hit Directus only over TLS; `PUBLIC_URL` and OAuth redirect URIs match the canonical HTTPS URL.
2. **Reduced network exposure** — Only required ports are reachable from the internet; database and admin paths are not unnecessarily exposed.
3. **SSH access controlled** — Administrative SSH is not open to the world without compensating controls (e.g. IAP, allowlisted IPs, keys only).
4. **Secrets handling documented and improved for scale** — Clear guidance for where secrets live, rotation, and (if agreed) migration toward GCP Secret Manager or equivalent.
5. **Patch and update path** — Documented process to update the OS, Docker images, and Directus version; someone can repeat it without tribal knowledge.
6. **Permission and data review** — Stakeholders confirm Directus policies (collections/fields/actions) match data classification before broad rollout; sensitive ERP subsets are not over-shared by default.
7. **Backups and recovery** — Cloud SQL backups (and any other recovery assumptions) are verified; RPO/RTO expectations are written down.
8. **Sign-off** — A short “go / no-go for broad access” note is recorded (email, ticket comment, or section at bottom of this file).

## Tasks / subtasks (checklist)

Implement in order unless a task explicitly allows parallel work. Check boxes as you complete and verify.

---

### 1. TLS / HTTPS and canonical URL (AC: #1)

- [x] **1.1** Choose termination approach (pick one and document):
  - [ ] **Option A:** Google Cloud HTTPS load balancer + managed certificate + backend to VM (or instance group).
  - [ ] **Option B:** Reverse proxy on the VM (**Caddy** or **nginx**) with Let’s Encrypt (or Google-managed cert if using a Google LB in front of proxy).
  - [x] **Option C:** Third-party edge (e.g. Cloudflare) with TLS to origin — document origin security and header trust.
- [x] **1.2** Register or reuse a **stable DNS name** (replace nip.io for production if that was interim only).
- [x] **1.3** Deploy TLS so browsers show a **valid certificate** (no mixed-content warnings for the app).
- [x] **1.4** Update Directus **`PUBLIC_URL`** on the VM to the **HTTPS** canonical URL (compare with `projects/internal-erp/directus/directus-vm-runtime.env` and deployment env used on the server — keep secrets out of git; update the **runtime** env on the VM and redeploy/restart Compose).
- [ ] **1.5** Update **Google OAuth** client: authorized JavaScript origins and redirect URIs must match the new **`PUBLIC_URL`** exactly.
- [ ] **1.6** Smoke test: login (password and Google if enabled), API health, and a read on a non-sensitive collection.

**Verification notes (fill in):**

- Canonical URL: `https://bs4.expertflow.com`
- `PUBLIC_URL` after change: `https://bs4.expertflow.com`
- Date verified: `2026-03-25`

---

### 2. Firewall and listening services (AC: #2)

- [ ] **2.1** Inventory what listens on the VM: `ss -tlnp` / `netstat` (as appropriate), Docker published ports, Cloud SQL Auth Proxy bind address.
- [ ] **2.2** Ensure **PostgreSQL is not reachable from the internet** — proxy should bind **`127.0.0.1`** unless there is a documented exception (prefer localhost-only).
- [ ] **2.3** Restrict **VPC firewall rules** / tags so only **443** (and **80** only if required for ACME HTTP-01) are open to the public, plus **22** only if required and then locked down per task 3.
- [ ] **2.4** Remove or document any **temporary “allow all”** rules from the pilot phase.
- [ ] **2.5** Confirm Directus is reachable **only** via the intended path (LB or proxy), not an accidental secondary port.

**Verification notes (fill in):**

- Public ports after hardening: `___________________________`
- Postgres/proxy bind: `___________________________`

---

### 3. SSH and VM admin access (AC: #3)

- [ ] **3.1** Disable password authentication for SSH if not already; **key-based** or **OS Login** only.
- [ ] **3.2** Prefer **Identity-Aware Proxy (IAP) for TCP forwarding** to SSH, or **allowlist office/VPN IPs** — avoid `0.0.0.0/0` on :22 without IAP.
- [ ] **3.3** Ensure **OS patch baseline** is defined (auto-updates or monthly patch window).
- [ ] **3.4** Document **who has `compute.osAdminLogin` / instance access** in IAM.

**Verification notes (fill in):**

- SSH access method: `___________________________`
- IAP / IP allowlist: `yes / no — details: ___`

---

### 4. Secrets and configuration (AC: #4)

- [ ] **4.1** List all secrets Directus needs: `KEY`, `SECRET`, DB credentials, OAuth client secret, admin bootstrap if any — **do not paste values into the repo**.
- [ ] **4.2** Confirm **gitignored** local files remain so (see repository `.gitignore` for `directus-migration.secrets.env`, `directus-vm-runtime.env`, `.secrets/`).
- [ ] **4.3** Decide pilot vs production: for broader access, plan **Secret Manager** (or sealed env on VM with restricted IAM) and document **how** the VM or Compose loads them at boot.
- [ ] **4.4** Rotation drill: document steps to rotate **`KEY` / `SECRET`** and OAuth secret without extended downtime (or accept maintenance window and document it).

**Verification notes (fill in):**

- Secret storage decision: `___________________________`
- Rotation owner: `___________________________`

---

### 5. Updates: OS, Docker image, Directus (AC: #5)

- [ ] **5.1** Pin **Directus version** in `projects/internal-erp/directus/Dockerfile` (or image tag in Compose) and record upgrade policy (e.g. security patches within N days).
- [ ] **5.2** Document rebuild and deploy: reference existing scripts under `projects/internal-erp/directus/` (e.g. migrate/deploy scripts and env files — read `README.md` in that folder).
- [ ] **5.3** After any upgrade, run smoke tests (login, collections, extensions if used).

**Verification notes (fill in):**

- Directus version deployed: `___________________________`
- Last image rebuild date: `___________`

---

### 6. Directus permissions and data governance (AC: #6)

- [ ] **6.1** With product/data owners, list **collections that contain PII, finance, or legal** data (examples from schema: `Employee`, `EmployeePersonalInfo`, `BankStatement`, `Invoice`, etc. — confirm against live DB).
- [ ] **6.2** For each **role** that will get broad access, confirm **read vs create/update/delete** per collection; remove “full CRUD everywhere” unless explicitly approved.
- [ ] **6.3** Use the Admin UI or controlled SQL to align policies; optional automation: `projects/internal-erp/directus/scripts/apply-erp-staff-policy-vm.ps1` (defaults are **read-all ERP tables** — tighten before broad rollout if needed).
- [ ] **6.4** If required by compliance, plan **audit logging** for sensitive reads/writes (see existing planning artifact `1-6-enable-audit-logging-finance-employee-pii.md` in this folder if still accurate).

**Verification notes (fill in):**

- Roles reviewed: `___________________________`
- Collections restricted vs pilot: `___________________________`

---

### 7. Backups and recovery (AC: #7)

- [ ] **7.1** Confirm **Cloud SQL automated backups** enabled; note **retention** and **region**.
- [ ] **7.2** Perform a **restore test** to a non-production instance or point-in-time clone (once per quarter minimum — record date).
- [ ] **7.3** Document what is **not** in DB backups (e.g. VM disk, uploaded files on local volume) and how those are backed up if used.

**Verification notes (fill in):**

- Backup retention: `___________________________`
- Last restore test: `___________`

---

### 8. Operational follow-ups (non-blocking for AC but recommended)

- [ ] **8.1** **Uploads:** Fix `directus/uploads` (or mounted volume) permissions if file fields are in scope — see container logs for “not writable” warnings.
- [ ] **8.2** **Extensions:** Resolve `@directus/errors` (or equivalent) warnings for custom extensions under `projects/internal-erp/directus/extensions/` to reduce upgrade risk.
- [ ] **8.3** **Monitoring:** Optional — uptime check, log sink to Cloud Logging, alert on instance or DB failure.

---

## References (repository paths only)

| Topic | Path |
|--------|------|
| Directus app root, deploy notes | `projects/internal-erp/directus/README.md` |
| Example VM / GCP env | `projects/internal-erp/directus/.env.gcp-vm.example`, `projects/internal-erp/directus/deploy-directus-gcp.env.example` |
| Policy automation (ERP read/CUD) | `projects/internal-erp/directus/scripts/apply-erp-staff-policy-vm.ps1` |
| SQL equivalents | `projects/internal-erp/directus/docs/sql/activate-erp-staff-policy-read.sql`, `activate-erp-staff-policy-add-cud-all.sql` |
| Local SQL via proxy (optional) | `projects/internal-erp/directus/run-owner-sql-through-proxy.ps1` |
| Audit logging story (if in scope) | `_bmad-output/implementation-artifacts/1-6-enable-audit-logging-finance-employee-pii.md` |

## Dev Agent Record

### Completion Notes List

_(Implementer: add dated notes, decisions, and links to tickets/PRs here.)_

### File List

_(List any new or changed repo files — e.g. updated `README.md`, Terraform, Compose, scripts.)_

---

## Go / no-go for broad employee access (AC: #8)

**Decision:** `GO` / `NO-GO` — **Date:** `___________` — **Signed (name + role):** `___________________________`

**Conditions (if conditional GO):**

- `_________________________________________________________________`
