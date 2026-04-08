# Identity provider (IdP) — canonical specification

**Single source of truth:** All **vendor-specific** identity details for Directus live **only in this file** (and in **Story 1.8** implementation notes). Other documents (PRD, Architecture, Vision, `.cursorrules`, Directus README) MUST **not** duplicate IdP vendor names or endpoint specifics — they reference **NFR12**, **ADR-12**, and **this document**.

**Change process:** To switch IdP (e.g. from Google Workspace to Keycloak or Microsoft Entra ID / Azure AD), update **this file** and complete **Story 1.8** (reconfigure Directus + secrets + validation). Then grep the repo for stale references.

---

## Contract (IdP-agnostic — do not change when swapping vendors)

| Requirement | Detail |
|-------------|--------|
| **Protocol** | OpenID Connect (OIDC) and/or OAuth 2.0 authorization code flow — whatever Directus supports for “SSO” providers. |
| **Human users (production)** | MUST authenticate to Directus via the **configured** external IdP — not shared local passwords. |
| **Verified email** | The IdP MUST supply a **stable, verified email** claim used to: (1) link or create `directus_users`, (2) pass `app.user_email` for PostgreSQL RLS (`UserToRole.User` MUST match this email, case-normalized per existing RLS — typically `lower()`). |
| **Domain-trusted JIT sign-in** | Users who complete SSO with the **configured trusted IdP** and present a **verified email** whose **domain** is listed in **§ Current configuration → Trusted email domains** MUST be able to **use Directus without anyone pre-creating** a `directus_users` row — Directus MUST **provision (create or auto-register)** that user on **first successful SSO** using Directus-supported OAuth/OIDC flows. Identities **outside** the trusted domain allowlist MUST **not** receive automatic provisioning (configure **deny**, **invite-only**, or equivalent per security review — document the chosen behavior in **Current configuration**). |
| **Authorization** | Directus **roles and permissions** (`directus_users`, policies) and PostgreSQL **`UserToRole`** remain authoritative for **what** users can do; the IdP establishes **who** they are. **JIT-provisioned** users get the **default Directus role** named in **Current configuration** until Epic 2 / ops assigns app roles and **`UserToRole`** rows. |
| **Non-production** | Local dev, break-glass admin, and automation MAY use Directus local auth or static tokens; document exceptions in runbooks — not the production default. |

---

## Current configuration (Phase 1 — edit this section when changing IdP)

| Field | Value |
|-------|--------|
| **IdP product** | **Google Workspace** (Google Cloud OAuth 2.0 / OIDC) |
| **Directus integration** | Directus SSO / OAuth2 provider pointing at Google’s issuer and token endpoints |
| **Trusted email domains** (JIT allowlist) | **`expertflow.com`** — SSO users with IdP-**verified** `@expertflow.com` email MUST be able to log in **without** prior manual Directus user creation (see contract **Domain-trusted JIT sign-in**). Add further domains here if the org standardizes additional Workspace domains. |
| **Outside allowlist** | **Deny** automatic sign-up / provisioning (only allowlisted domains get JIT); adjust here if policy changes. |
| **Default Directus role (JIT users)** | Create a **minimal** role in Directus (no sensitive collection permissions until **Epic 2**); set its UUID in **`AUTH_GOOGLE_DEFAULT_ROLE_ID`** — **`projects/internal-erp/directus/docs/story-1-8-google-sso.md`** §3. |
| **Domain restriction** | Organization Workspace domain(s) — enforce via Google Cloud OAuth consent + Workspace admin policy **and** Directus / IdP settings consistent with **Trusted email domains** above |
| **Secrets** | OAuth client ID/secret in Secret Manager (production); never commit |
| **Rationale (historical)** | Aligns with Expertflow **Google Workspace Business Standard**; MFA and user lifecycle in Workspace |

### Future IdP options (examples only — not configured until this section is updated)

- **Keycloak** (self-hosted or managed) — OIDC  
- **Microsoft Entra ID** (Azure AD) — OIDC  
- Any OIDC-compliant IdP Directus can register as an external provider

When switching: replace the **Current configuration** table, update Directus provider settings and secrets, re-test email claim mapping and RLS `UserToRole` alignment.

---

## Traceability

| Artifact | Role |
|----------|------|
| **PRD NFR12** | Normative requirement (external IdP, email, exceptions) — no vendor names |
| **Architecture ADR-12** | Decision pointer to OIDC SSO + **this file** |
| **Story 1.8** | Sole implementation story for IdP wiring and cutover |

---

*Last updated: 2026-03-16 — Story 1.8 runbook: `docs/story-1-8-google-sso.md`; default JIT role via `AUTH_GOOGLE_DEFAULT_ROLE_ID`.*
