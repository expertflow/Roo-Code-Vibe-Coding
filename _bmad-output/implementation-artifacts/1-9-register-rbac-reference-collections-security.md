# Story 1.9: Register RBAC database collections (`Role`, `RolePermissions`, `UserToRole`)

Status: done

## Story

As an **Administrator**,
I want the PostgreSQL RBAC tables **`Role`**, **`RolePermissions`**, and **`UserToRole`** registered in Directus with correct field interfaces and labels,
So that **Epic 2** can configure app permissions and **`UserToRole.User`** stays aligned with IdP **verified email** and PostgreSQL RLS (**NFR13** / **Story 1-10**).

## Context

**Epic:** 1 — Platform foundation (security prerequisite).

**Dependencies:** Stories **1-2**–**1-3** (core schema present). **Blocks:** meaningful **Epic 2** work on app RBAC + **`UserToRole`** data entry.

**FR traceability:** **FR2** (collection registration). **NFR1**, **NFR13** (with **1-10** extension).

## Acceptance Criteria

1. **`Role`**, **`RolePermissions`**, **`UserToRole`** are registered in Directus with metadata per Architecture **§4.1** (integers, FKs as **M2O** where applicable).

2. These collections are visible **only** to **Administrator** (and any system roles you define) until **Epic 2** finalizes visibility for custom roles.

3. **`UserToRole.User`** is configured to store **email** (or text key) using the **same normalization** as RLS / **`identity-provider.md`** (typically **`lower()`** on compare).

## Tasks / Subtasks

- [x] Repo automation: `projects/internal-erp/directus/scripts/lib/story-1-9-config.mjs`, `apply-story-1-9-rbac-meta.mjs`, `story-1-9-config.test.mjs`; RBAC relations merged into `lib/erp-relations.mjs` for `apply-m2o-dropdown-templates.mjs`.
- [ ] Run apply script against your Directus instance (collections must exist from DB introspection).
- [ ] Run `apply-m2o-dropdown-templates.mjs` after apply.
- [ ] Smoke-test: Admin can CRUD sample rows (non-prod data); document field meanings (see `directus/docs/story-1-9-rbac-collections.md`).

## References

- `_bmad-output/planning-artifacts/epics-ExpertflowInternalERP-2026-03-16.md` — Story 1.9
- `projects/internal-erp/directus/README.md` — **Story 1.9** (Epic 1 sections are numeric **1.1–1.10**)
- `_bmad-output/planning-artifacts/architecture-BMADMonorepoEFInternalTools-2026-03-15.md` — §4.1, ADR-13
- `_bmad-output/planning-artifacts/identity-provider.md`

## Dev agent sections

_(filled when implemented)_

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
