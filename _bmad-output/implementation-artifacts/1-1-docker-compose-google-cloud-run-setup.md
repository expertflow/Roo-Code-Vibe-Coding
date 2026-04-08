# Story 1.1: Docker Compose & Google Cloud Run Setup

Status: done

<!-- Validation: optional — run validate-create-story before dev-story. -->

## Story

As a **DevOps Engineer / Developer**,
I want a `docker-compose.yml` that runs Directus v11 locally using the same Docker image as production, with Cloud SQL Auth Proxy connectivity and all credentials externalized to `.env`,
So that the local environment is **parity-aligned** with the Google Cloud Run production deployment and **no credentials** are ever committed to the repository.

### BMAD planning vs this story (clarification)

- **Already planned:** GCP hosting is **not** new to BMAD. **Epic 1 Story 1.1** (this artifact), **PRD NFR2 / NFR6 / NFR9**, **Architecture §2.2 + ADR-10** define **Google Cloud Run** as the **canonical production** deployment (same Docker image as local; **Secret Manager**; **Cloud SQL** via proxy/sidecar).
- **Consolidated addendum (2026-03):** A **Compute Engine VM + Docker Compose** path (Cloud SQL Auth Proxy **inside** Compose on the VM) was added as a **documented interim** so colleagues can use a stable URL **before** Cloud Run is fully cut over. It uses the **same image** and the same secret / **`PUBLIC_URL` / OAuth** rules; it **does not** supersede ADR-10.
- **Single source of truth for “how to run Directus on GCP” (repo):** **`projects/internal-erp/directus/docs/gcp-directus-deployment.md`** · example compose: **`projects/internal-erp/directus/docker-compose.gcp-vm.example.yml`**. **Wave plan:** **`_bmad-output/planning-artifacts/migration-plan-postgres-directus-cloud-wave1.md`** (Wave 0 — Cloud Run skeleton; VM path noted there).

## Context (Epic 1)

**Epic goal:** A running, production-equivalent Directus v11 Docker environment on Google Cloud with all `bidstruct4` collections registered, relationships mapped, and audit logging active. This story is the **first** slice: runnable Directus + DB connectivity only — no collection registration yet (Stories 1.2+).

**Dependencies:** None (greenfield path under `projects/internal-erp/directus/`).

**Blocks:** Stories 1.2–1.7 (Admin cannot configure collections until Directus boots).

## Acceptance Criteria

1. **Given** the developer has configured a local `.env` file from `.env.example` with valid `DB_*`, `SECRET`, and `KEY` values, **When** they run `docker compose up` in `projects/internal-erp/directus/`, **Then** Directus v11 starts successfully on `http://localhost:8055` and the admin login screen is accessible **And** the Directus container connects to `bidstruct4` via `host.docker.internal:5432` (Cloud SQL Auth Proxy listening on the host).

2. **Given** a developer inspects the repository, **When** they check any committed file, **Then** no actual passwords, `SECRET` values, or `KEY` values appear anywhere — only `.env.example` with empty placeholders.

3. **Given** `.env.example` is present, **When** a new developer copies it to `.env` and fills in credentials, **Then** `docker compose up` succeeds with no additional manual configuration steps (beyond valid DB + Directus secrets).

4. **Given** `docker-compose.yml` defines the Directus service, **When** the image tag is inspected, **Then** it references `directus/directus:11` or a **pinned** `11.x` patch (document the pin in a comment; prefer patch pin for reproducibility).

## Tasks / Subtasks

- [x] **Scaffold Directus project directory** (AC: 1, 3)
  - [x] Create `projects/internal-erp/directus/` if missing
  - [x] Add root `.gitignore` entries OR confirm repo `.gitignore` includes `projects/internal-erp/directus/.env`, `uploads/`, and any local proxy credential files
- [x] **Author `docker-compose.yml`** (AC: 1, 4)
  - [x] Service: `directus` — image `directus/directus:11` (or pinned `11.x.y`)
  - [x] Expose `8055:8055`
  - [x] Pass through env from `.env`: at minimum `KEY`, `SECRET`, `DB_CLIENT=pg`, `DB_HOST`, `DB_PORT`, `DB_DATABASE`, `DB_USER`, `DB_PASSWORD`, `ADMIN_EMAIL` / `ADMIN_PASSWORD` if bootstrap needed
  - [x] Set `DB_HOST=host.docker.internal` (Windows/Mac Docker Desktop) **or** document Linux alternative (`extra_hosts` / host gateway) in Dev Notes
- [x] **Author `.env.example`** (AC: 2, 3)
  - [x] All required keys with empty values and one-line comments; no secrets
- [x] **Document Cloud SQL Auth Proxy** (AC: 1)
  - [x] README: **Prerequisites** + **§1** in `projects/internal-erp/directus/README.md` — start proxy on host `127.0.0.1:5432` **before** `docker compose up`; link to ADR-02. Epic 1 **Story 1.1–1.10** sections appear in **numeric order** there (delivery order may differ — see epic *Implementation sequencing*).
- [ ] **Smoke test** (AC: 1–4) — *requires local Docker + Cloud SQL Auth Proxy + filled `.env`*
  - [ ] `docker compose up` → open `http://localhost:8055` → login

## Dev Notes

### Architecture compliance

- **ADR-01 / §2.2:** Directus v11 Dockerized; production target **Google Cloud Run** — local must use the **same image family** as prod.
- **ADR-02 / §3.1:** DB connectivity via **Cloud SQL Auth Proxy** to `localhost:5432` on host; container uses `host.docker.internal:5432` (Docker Desktop pattern).
- **ADR-03:** Secrets only in `.env` (local) / Secret Manager (prod). Never commit `.env`.
- **NFR2, NFR6:** Reproducible `docker compose up` after `.env` setup.

### Governance / vibecoding

- Per `docs/governance.md`: do not paste real `SECRET`, `KEY`, or `DB_PASSWORD` into issues, PRs, or chat.

### Project structure (target)

```
projects/internal-erp/directus/
├── docker-compose.yml
├── .env.example          # committed
├── README.md             # proxy + compose instructions
├── extensions/           # hooks appear in later stories (empty or .gitkeep)
└── uploads/              # gitignored; Directus local file storage
```

Repo root `schema.json` may appear after Story 1.7 — not required for 1.1.

### Windows / Docker Desktop specifics

- Confirm `host.docker.internal` resolves from the Directus container; if not, add `extra_hosts: - "host.docker.internal:host-gateway"` (Linux) or document WSL2 networking.

### Testing

- Manual: compose up, HTTP 200 on `:8055`, admin UI loads.
- No automated E2E required for this story unless repo already has a harness.

### Shared GCP deployment (VM interim — BMAD-aligned)

- Runbook: **`projects/internal-erp/directus/docs/gcp-directus-deployment.md`**
- Compose pattern: **`projects/internal-erp/directus/docker-compose.gcp-vm.example.yml`** → copy to `docker-compose.gcp-vm.yml` (gitignored)
- OAuth / **`PUBLIC_URL`**: **`projects/internal-erp/directus/docs/story-1-8-google-sso.md`** (add production origins + redirect URIs)

### References

- [Source: `_bmad-output/planning-artifacts/epics-ExpertflowInternalERP-2026-03-16.md` — Story 1.1]
- [Source: `_bmad-output/planning-artifacts/architecture-BMADMonorepoEFInternalTools-2026-03-15.md` — §2.2, §3.1, ADR-01–03, ADR-10]
- [Source: `_bmad-output/planning-artifacts/prd-ExpertflowInternalERP-2026-03-16.md` — FR1, NFR2, NFR6, NFR9]
- [Source: `_bmad-output/planning-artifacts/migration-plan-postgres-directus-cloud-wave1.md` — Wave 0]
- [Source: `docs/governance.md` — secret handling]

## Dev Agent Record

### Agent Model Used

Composer (Cursor agent)

### Debug Log References

### Completion Notes List

- Scaffolded `projects/internal-erp/directus/` with `docker-compose.yml` (`directus/directus:11`, `8055`, `env_file`, `uploads`/`extensions` volumes, `extra_hosts` for Linux host-gateway).
- Added `.env.example` (no secrets), `README.md` (proxy + ADR-02 pointer), `extensions/.gitkeep`, `uploads/.gitignore`.
- Root `.gitignore`: explicit `directus/.env` and `uploads/*` exceptions.
- **Smoke test not run** in CI/agent environment (Docker CLI unavailable).

### File List

- `projects/internal-erp/directus/docker-compose.yml`
- `projects/internal-erp/directus/docker-compose.gcp-vm.example.yml` — VM + Cloud SQL proxy sidecar (interim; BMAD cross-ref § above)
- `projects/internal-erp/directus/docs/gcp-directus-deployment.md` — GCP runbook (BMAD consolidation)
- `projects/internal-erp/directus/.env.example`
- `projects/internal-erp/directus/README.md`
- `projects/internal-erp/directus/extensions/.gitkeep`
- `projects/internal-erp/directus/uploads/.gitignore`
- `.gitignore`
