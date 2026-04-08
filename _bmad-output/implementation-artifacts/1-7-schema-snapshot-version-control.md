# Story 1.7: Schema snapshot & version control (`schema.json`)

Status: **done**

## Story

As a **Developer**,  
I want the full Directus **collection configuration** exported as **`schema.json`** and committed under **`projects/internal-erp/directus/`**,  
So anyone can reproduce metadata with **`directus schema apply`** without manual UI steps.

**Normative epic:** `_bmad-output/planning-artifacts/epics-ExpertflowInternalERP-2026-03-16.md` — Story 1.7.

## Implementation approach (repo)

| Artifact | Role |
|----------|------|
| **`projects/internal-erp/directus/schema.json`** | Canonical snapshot (git-tracked). Created via CLI **inside** the running Directus container, then copied to the host (see **`README.md`** Story **1.7**). |
| **`scripts/snapshot-schema.ps1`** / **`scripts/snapshot-schema.sh`** | Optional one-shot: snapshot → copy beside `docker-compose.yml`. |

## Tasks / Subtasks

- [x] Directus stack **up** with current `.env` (same DB as Stories **1.2–1.5**).
- [x] Run **schema snapshot** (container CLI) → host file **`projects/internal-erp/directus/schema.json`**.
- [x] Open snapshot briefly: contains **`collections`**, **`fields`**, **`relations`** (Directus v11 snapshot format; file may be YAML-shaped content under `schema.json` name per CLI default).
- [x] **Commit** `schema.json` + any README/script additions — canonical file in **`ae1bc50`**; **2026-03-24** re-ran **`scripts/snapshot-schema.ps1`** → **no diff** vs `HEAD` (metadata matches repo).
- [ ] _(Optional dry-run)_ On a **throwaway** DB only: copy `schema.json` into the container, then `directus schema apply /tmp/schema-apply.json` — **destructive if mis-targeted**; see **`README.md`** Story **1.7**; **never** apply to production without review.

## References

- `projects/internal-erp/directus/README.md` — **Story 1.7** (Epic 1 **1.1–1.10** numeric order)
- Architecture **ADR-04** (if referenced for snapshot location)

## Dev agent sections

### Completion Notes List

- **2026-03-24** — Re-ran `projects/internal-erp/directus/scripts/snapshot-schema.ps1` against running local stack; working tree **clean** (snapshot matches committed `schema.json`). First landed in **`ae1bc50`**.

### File List

- `projects/internal-erp/directus/schema.json` — _(created by operator)_
- `projects/internal-erp/directus/scripts/snapshot-schema.ps1`
- `projects/internal-erp/directus/scripts/snapshot-schema.sh`
