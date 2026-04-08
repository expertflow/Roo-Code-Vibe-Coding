# Story 1.9 — RBAC collections in Directus

## Scope

| Collection         | Purpose |
|--------------------|--------|
| `Role`             | App role names (PostgreSQL RBAC — not `directus_roles`) |
| `RolePermissions`  | Per-role table CRUD + `AccessCondition` |
| `UserToRole`       | Maps **`User`** (text email) → **`RoleName`** (M2O → `Role`) |

## Email alignment

Store **`UserToRole.User`** in the **same normalized form** as IdP verified email and RLS **`current_setting('app.user_email')`** (typically **lowercase**). See **`_bmad-output/planning-artifacts/identity-provider.md`**.

## Scripts

- `scripts/apply-story-1-9-rbac-meta.mjs` — labels, templates, relations, field interfaces  
- `scripts/apply-m2o-dropdown-templates.mjs` — refresh M2O display after relations exist  

## Next

- **Story 1-10** — RLS request-context extension  
- **Story 1-8** — Google SSO + `@expertflow.com` JIT  
- **Epic 2** — restrict non-Admin access to these collections  
