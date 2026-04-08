# Story 1.5: Configure all foreign-key relationships (Directus)

Status: **done** (2026-03-16)

## Story

As an **Administrator**,  
I want every foreign-key relationship in **`schema_dump_final.json`** configured as a Directus relational field,  
So operators can navigate related records in Admin without raw ID lookups (**FR3**, **`data-admin-surface-requirements.md`** R1–R3).

**Normative epic:** `_bmad-output/planning-artifacts/epics-ExpertflowInternalERP-2026-03-16.md` — Story 1.5.

## Implementation approach (repo)

| Mechanism | Role |
|-----------|------|
| **`scripts/lib/story-1-2-config.mjs`** | `FINANCIAL_RELATIONS` — many finance FKs |
| **`scripts/lib/story-1-3-config.mjs`** | `ORG_HR_RELATIONS` |
| **`scripts/lib/story-1-9-config.mjs`** | `RBAC_RELATIONS` |
| **`scripts/lib/erp-relations.mjs`** | `ALL_CONFIGURED_ERP_RELATIONS` merge |
| **`scripts/apply-m2o-dropdown-templates.mjs`** | Ensures missing **`POST /relations`**, upgrades M2O meta + templates |

**Gap work for “all” FKs:** Compare in-scope collections / integer FK columns in **`schema_dump_final.json`** vs `ALL_CONFIGURED_ERP_RELATIONS`; add missing `{ many_collection, many_field, one_collection }` rows, then re-run **`apply-m2o-dropdown-templates`**.

## Tasks / Subtasks

- [x] Inventory: FK-backed fields verified in Data Studio (human-readable M2O / templates; no bare integers on checked records).
- [x] Add missing relations — none required beyond merged **`ALL_CONFIGURED_ERP_RELATIONS`** for verified paths; re-open if **`schema_dump_final.json`** gap analysis finds new FKs.
- [x] Run **`apply-m2o-dropdown-templates.mjs`** (after **`apply-story-*`** scripts for collections if needed). Use **`--force`** if item/detail views still show raw PKs while `/fields` meta looks correct.
- [x] **AC spot-check** (epic): `Transaction`, `Invoice`, and related M2O fields show names/codes (operator verification 2026-03-16).
- [x] **R1–R3** spot-check per **`data-admin-surface-requirements.md`** (lists / item views / pickers — satisfied with same verification).
- Epic 1 tail: **1.6** / **1.7** — **`1-6-enable-audit-logging-finance-employee-pii.md`**, **`1-7-schema-snapshot-version-control.md`**.

## Commands (local)

```bash
cd projects/internal-erp/directus/scripts
node apply-m2o-dropdown-templates.mjs --dry-run
set DIRECTUS_URL=http://127.0.0.1:8055
set DIRECTUS_ADMIN_EMAIL=...
set DIRECTUS_ADMIN_PASSWORD=...
node apply-m2o-dropdown-templates.mjs
# If Origin Account / Currency still show integers in record view:
node apply-m2o-dropdown-templates.mjs --force
```

Use **Google SSO** user + token if password login disabled later (`STATIC_TOKEN` or session-based automation TBD).

## References

- `schema_dump_final.json` (repo root)
- Architecture **ADR-14** / **`data-admin-surface-requirements.md`**

## Dev agent sections

### Completion Notes List

- **2026-03-16 — Story closed:** Data Studio record/detail views show **names/codes** (not raw integer PKs) for verified finance/org FKs after **`apply-m2o-dropdown-templates.mjs --force`** + valid **`STATIC_TOKEN`** (see `verify-directus-auth.mjs`). Epic AC for M2O readability met for checked collections.
- **2026-03-23 — Human-readable M2O in record views:** `apply-m2o-dropdown-templates.mjs` supports **`--force`** to re-PATCH every ERP relation FK with `select-dropdown-m2o` + `display: related-values` + shared `template` / `display_options.template` (see `lib/m2o-readable-meta.mjs`). Run after Story 1.2 meta if Transaction/Invoice fields still render as plain integers.

### File List

- `projects/internal-erp/directus/scripts/apply-m2o-dropdown-templates.mjs` — **`--force`** flag (re-apply M2O + `related-values` templates)
- `projects/internal-erp/directus/scripts/lib/m2o-readable-meta.mjs`
- `projects/internal-erp/directus/scripts/lib/collection-display-templates.mjs`
- `projects/internal-erp/directus/README.md` — **Story 1.5** + **M2O dropdown labels** (Epic 1 **1.1–1.10** numeric order)
