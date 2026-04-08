# Story 1.10: Directus extension — RLS request context (`app.user_email`)

Status: done

## Story

As a **Developer / Security**,
I want a **Directus extension** that, on **user-initiated API requests**, runs `SET LOCAL ROLE <RLS_SESSION_ROLE>; SET LOCAL app.user_email = '<authenticated_user_email>';` (default **`directus_rls_subject`**, env **`RLS_SESSION_ROLE`** — **not** `public`; per **PRD NFR13** / Architecture **ADR-13**),
So PostgreSQL RLS on the **12 protected tables** evaluates with the **human operator’s** identity — not only the pooled service DB user’s owner bypass.

## Context

**Epic:** 1. **Dependencies:** working Directus auth (local or **Story 1-8** SSO). **Enables:** RLS-aligned row visibility for **all** authenticated users, **including Directus Administrator**, together with **Epic 2** and **`UserToRole`**.

## PENDING — RLS vs Directus (explicit)

| Status | Detail |
|--------|--------|
| **PENDING** | **End-to-end verification** that **authenticated** users (**including Administrator**) receive **row sets** matching **PostgreSQL RLS** + **`UserToRole`** for their email, aligned with **Directus RBAC** where applicable. |
| **Why** | Without **1-10** (or with `RLS_USER_CONTEXT_ENABLED=false`), `items.*` traffic as **`bs4_dev`** may hit **owner-access** policies. **Mitigation:** Directus **`DB_USER` = `sterile_dev`** (no owner-access policies) — see **`docs/sql/setup-sterile-dev.sql`** / Architecture **§8.1**. |
| **Blocked until** | Extension deployed **+** **`directus_users.email`** **+** **Epic 2** (partial) **+** **`UserToRole`** rows for test accounts. |
| **Close criteria** | Document a **role × collection × expected row count / sample IDs** matrix signed off in **Completion Notes** below. |

## Acceptance Criteria

1. On each **authenticated** Data Engine API request (**including** users with the Directus Administrator flag), the extension sets **`SET LOCAL ROLE <RLS_SESSION_ROLE>`** and **`app.user_email`** to the **current user’s normalized email** (per Architecture / **`identity-provider.md`**). **No** bypass for Administrator on this path. **DB one-time:** `create-rls-session-role.sql` + **`setup-sterile-dev.sql`** (runtime `DB_USER` = **`sterile_dev`**) + ERP grants on **`directus_rls_subject`** (`grant-rls-subject-erp-schema.sql`).

2. **Internal / maintenance** traffic without `accountability.user` (migrations, bootstrap, some static flows) does **not** break; **`RLS_USER_CONTEXT_ENABLED=false`** is **break-glass** only — document risk.

3. **PENDING** row above is **tracked**; story may ship **implementation-done** before matrix is **fully** green — update this file when the matrix passes.

## Tasks / Subtasks

- [x] Hook extension: `projects/internal-erp/directus/extensions/rls-user-context/` (loaded via existing `./extensions:/directus/extensions` volume — **rebuild/restart** Directus after pull).
- [x] Restart container; confirm extension loads (no boot error).
- [x] Integration smoke (2026-03-16): Directus Admin (`apstuber@expertflow.com`) **cannot** insert **`UserToRole`** — PostgreSQL RLS policy blocks write — confirms **`items.*`** path uses session role + RLS (not owner bypass).
- [ ] **Story 1-8** Google SSO: `directus_users.email` must match **`UserToRole.User`** (lowercase) for IdP-verified accounts.
- [ ] **Epic 2:** assign **`finance-manager`** Directus role + collection permissions (“see all tables” in Directus is **not** the same as RLS Finance — align **`UserToRole`** with PG role id **115** / Finance per Architecture §8.2).
- [ ] Run **authenticated-user RLS matrix** (incl. Administrator — PENDING); paste results in Completion Notes.

## File List (implementation)

- `projects/internal-erp/directus/extensions/rls-user-context/package.json`
- `projects/internal-erp/directus/extensions/rls-user-context/index.js`
- `projects/internal-erp/directus/docs/sql/create-rls-session-role.sql`
- `projects/internal-erp/directus/docs/sql/setup-sterile-dev.sql` — Directus runtime DB user (no `policy_owner_access_*`)
- `projects/internal-erp/directus/docs/sql/fix-rls-policies-v2.sql` — policy correctness patch (2026-03-16)
- `projects/internal-erp/directus/docs/story-1-10-rls-user-context.md`
- `projects/internal-erp/directus/README.md` — **Story 1.10** (Epic 1 **1.1–1.10** numeric order)

## References

- PRD **NFR13**
- Architecture **ADR-13**, **§3.2** / RLS sections
- `_bmad-output/planning-artifacts/epics-ExpertflowInternalERP-2026-03-16.md` — Story 1.10

## Dev agent sections

### Agent Model Used

_(n/a)_

### Debug Log References

_(n/a)_

### Completion Notes List

- **2026-03-16 — Sanity smoke (signed off):** Admin user on **`items.create`** for **`UserToRole`** received `new row violates row-level security policy for table "UserToRole"` — expected with **1-10** + policies that do not grant that email write access. Confirms **no Administrator bypass** on ERP RLS tables for Data Engine traffic.
- **Operational note:** Seed **`UserToRole`** via **`psql` as `bs4_dev`** (break-glass) or SQL admin, not Admin UI, when RLS blocks inserts — see **`projects/internal-erp/directus/docs/sql/seed-user-to-role.example.sql`** and **`docs/story-1-8-google-sso.md`** §7.
- **2026-03-16 — Runtime DB user `sterile_dev`:** Directus `.env` uses **`DB_USER=sterile_dev`** so connections are **not** covered by `policy_owner_access_*` (`TO bs4_dev`). Verified: as **`sterile_dev`**, `SELECT` on **`Transaction` id=1** returns **0 rows** without owner bypass; with **`SET ROLE directus_rls_subject`** + **`app.user_email=apstuber@gmail.com`**, still **0 rows**. Script: **`docs/sql/verify-sterile-dev-rls.sql`**.
- **2026-03-16 — Policy correctness patch (`fix-rls-policies-v2.sql`) executed and verified:**
  - **FORCE ROW LEVEL SECURITY** applied to all 12 protected tables — combined with **`sterile_dev`** as Directus `DB_USER`, ERP visibility no longer falls through **`bs4_dev`** `policy_owner_access_*` on app connections; **`bs4_dev`** remains break-glass with those policies.
  - **Open SELECT** added to `UserToRole`, `Role`, `RolePermissions`, `Account`, `LegalEntity` — the structural bug that silently zeroed out all Finance/HR subquery results is fixed.
  - **Transaction / Invoice / Allocation** `public_read` policies replaced: now check **BOTH** `OriginAccount` AND `DestinationAccount` for Employee / Executive (NFR13).
  - **Transaction / Invoice** `hr_select` policies replaced: now (one leg = Employee) AND (no leg = Executive) across both account columns.
  - **BankStatement** Finance / HR / public SELECT policies created (canonical, replacing any prior state).
  - **Accruals** Finance SELECT + INSERT + UPDATE + DELETE policies created (were entirely absent).
  - **Journal** Finance SELECT + INSERT + UPDATE + DELETE policies created (were entirely absent).
  - Pre-existing legacy `_hr_delete` / `_hr_update` DML policies on Transaction/Invoice lack the Executive-exclusion guard — write backstop is `auth_crud()` per Architecture §8.5; a separate SQL task can align them in a later sprint.

### File List

_(see File List (implementation) above)_
