# Story 1.8: External OIDC identity provider (Directus SSO)

Status: in-progress

## Story

As an **Administrator / DevOps**,
I want Directus in **production** to use the **external OIDC/OAuth identity provider** defined in the canonical spec,
So that staff authenticate through corporate SSO, **verified email** aligns with `directus_users` and PostgreSQL `UserToRole`, and we can **change IdP later** by updating one doc and this story — not scattered PRD edits.

## Dependencies (security sequence)

Implement **after** **Story 1-10** (RLS `app.user_email` extension) so SSO smoke tests can confirm **API requests** carry RLS context. **Story 1-9** (`Role` / `RolePermissions` / `UserToRole` in Directus) should be **done** before **`UserToRole`**-aligned SSO checks.

## Canonical specification (single source of truth)

**`_bmad-output/planning-artifacts/identity-provider.md`**

- **Do not** duplicate Google / Keycloak / Azure specifics in the PRD or Architecture body — only in `identity-provider.md` and this story’s completion notes.
- **Normative requirements:** PRD **NFR12**, Architecture **ADR-12**. **Trusted-domain JIT** for **`@expertflow.com`** per that file.

## Acceptance criteria

**Given** production Directus is deployed,
**When** a staff member opens the Admin login,
**Then** they can sign in via the **IdP named in `identity-provider.md` § Current configuration** (today: Google Workspace OIDC/OAuth), not a shared Directus password.

**Given** a user completes SSO successfully,
**When** Directus creates or links their session,
**Then** the **verified email** from the IdP matches the email used for PostgreSQL RLS (`SET LOCAL app.user_email`) and **`UserToRole.User`** (same normalization rules as existing RLS — e.g. `lower()`).

**Given** a user authenticates via the **trusted IdP** (e.g. Google Workspace) with an IdP-**verified** email whose **domain** is in **`identity-provider.md` → Trusted email domains** (e.g. `@expertflow.com`),
**When** no administrator has **pre-created** a Directus user for that email,
**Then** **first successful SSO** still logs them in — Directus **JIT-provisions** (creates or auto-registers) `directus_users` per **`identity-provider.md`**; non-allowlisted domains behave per **`identity-provider.md` → Outside allowlist**.

**Given** the organization decides to migrate IdP (e.g. to Keycloak or Entra ID),
**When** the team updates **`identity-provider.md`** § Current configuration and reconfigures Directus + secrets,
**Then** no PRD/Architecture rewrite is required beyond verifying NFR12/ADR-12 still hold and updating this story’s completion notes.

## Tasks / Subtasks

- [x] Runbook + `.env.example` templates: **`projects/internal-erp/directus/docs/story-1-8-google-sso.md`**, **`projects/internal-erp/directus/.env.example`** (Story 1.8 block).
- [x] Configure Google Cloud **OAuth 2.0 Web client**; set **`AUTH_GOOGLE_CLIENT_ID`** / **`AUTH_GOOGLE_CLIENT_SECRET`** in local `.env` (never commit).
- [x] Create **minimal** Directus role; set **`AUTH_GOOGLE_DEFAULT_ROLE_ID`** (see runbook §3).
- [ ] Store OAuth client secret in **Secret Manager** (prod); local `.env` only on workstations.
- [x] **JIT:** **`AUTH_GOOGLE_ALLOW_PUBLIC_REGISTRATION=true`** + **`AUTH_GOOGLE_IDENTIFIER_KEY=email`** + **`AUTH_GOOGLE_REQUIRE_VERIFIED_EMAIL=true`** per runbook — aligns with **`identity-provider.md`** trusted-domain JIT (enforce Workspace-only via Google **Internal** consent / org policy).
- [x] Smoke-test (migrated user): **`andreas.stuber@expertflow.com`** — local user row updated to **`provider = google`** + **`external_identifier`** → **Google SSO login succeeds** (2026-03-23).
- [ ] **TODO (tomorrow) — JIT smoke:** different **`@expertflow.com`** mailbox with **no** pre-existing **`directus_users`** row → first **Google** login → new user row + **`AUTH_GOOGLE_DEFAULT_ROLE_ID`** → open a collection (confirm **1-10** `app.user_email`). Full RLS matrix still **PENDING** until Epic 2 + **`UserToRole`** data.
- [x] **`identity-provider.md`** — default JIT role row points to runbook §3; last updated **2026-03-16**.

## References

- PRD **NFR12**
- Architecture **ADR-12**, **§3.2**
- `identity-provider.md`

## Dev agent sections

### Agent Model Used

_(n/a)_

### Debug Log References

_(n/a)_

### Completion Notes List

- **2026-03-16:** Implementation **docs** landed; **`UserToRole`** seeding when RLS blocks Admin UI: **`docs/story-1-8-google-sso.md`** §7.
- **2026-03-23:** Google SSO working for migrated admin; **JIT first-time user** test explicitly **deferred to next session** (tracked above + sprint header).

### File List

- `projects/internal-erp/directus/docs/story-1-8-google-sso.md`
- `projects/internal-erp/directus/docs/sql/seed-user-to-role.example.sql`
- `projects/internal-erp/directus/.env.example` (Story 1.8 env block)
- `projects/internal-erp/directus/README.md` — **Story 1.8** (Epic 1 **1.1–1.10** numeric order)
- `_bmad-output/planning-artifacts/identity-provider.md` (default role row + last updated)
