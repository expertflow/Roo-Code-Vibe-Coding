# Data administration surface — operator presentation (canonical)

**Single source of truth:** All **product-agnostic** rules for how **operators** see **references, lookups, and lists** in the internal **database administration UI** live **only in this document**. Other BMAD artifacts (PRD, Epics, Vision, Architecture, `.cursorrules`) MUST **not** restate the full contract — they reference **NFR14** (PRD) and **this file**.

**What this covers:** The **structured admin layer** on top of PostgreSQL (`bidstruct4`) — the app staff use to browse collections, open records, and pick related entities. **Phase 1 implementation:** **Directus** (see § Current implementation binding). **Swapping products** (e.g. to Strapi, Payload, custom Admin): update **§ Current implementation binding**, Architecture stack ADRs, and implementation stories — **without weakening** §§ Operator presentation contract or Relationship modeling below.

**Change process:** To adopt a different admin/CMS product, edit **§ Current implementation binding**, add/replace an Architecture ADR for the new stack, and implement equivalent metadata/automation. Then grep the repo for stale “Directus-only” wording in **requirements** (implementation paths in `projects/internal-erp/` may still say Directus until migrated).

---

## 1. Operator presentation contract (CMS-agnostic)

These rules apply to **any** data-administration product used for Phase 1 (or successor phases) unless the product owner **explicitly exempts** a field in writing.

| # | Requirement |
|---|-------------|
| **R1 — Readable references** | Any field that stores a **foreign key** (or logical reference) to another entity MUST present a **human-meaningful** representation of the **target** entity in: **tabular/list views**, **single-record (detail) views**, and **relational pickers / search dialogs** — not the raw surrogate primary-key value alone (e.g. bare `10`, `7`, `2`) when a related row exists. Acceptable forms include names, codes, titles, or **approved multi-field templates** (e.g. “Name (code)”). |
| **R2 — Default experience** | Raw PK display as the **only** visible value for such fields in those contexts is a **defect**, not a stylistic choice. |
| **R3 — Navigation** | Operators MUST be able to **navigate** from a reference to the related record through the admin UI’s normal relational affordances (subject to RBAC). |
| **R4 — API vs UI** | The **REST/GraphQL API** may continue to return scalar FK columns unless clients request expanded relational `fields`. **R1–R3** apply to the **operator-facing admin UI** (and any **first-party extension UIs** that mirror the same field configuration). |
| **R5 — Regression** | After **any** change that adds or alters **references, relationships, or field presentation metadata**, the team MUST **re-validate** R1–R3 (automation, checklist, or test) per the **current implementation binding**. |

---

## 2. Relationship modeling (CMS-agnostic)

| # | Requirement |
|---|-------------|
| **M1** | Foreign keys exposed in the admin UI MUST be modeled as **first-class relational fields** (many-to-one or equivalent), not as opaque integers with no relational metadata — so the platform can resolve labels and navigation. |
| **M2** | **Collection / entity display names** in navigation SHOULD use **human-readable** titles, not only internal table names — within the limits of the chosen product. |

---

## 3. Current implementation binding (Phase 1 — edit when changing product)

| Item | Value |
|------|--------|
| **Admin product** | **Directus** v11.x (self-hosted, Docker). |
| **Repository** | `projects/internal-erp/directus/` |
| **Normative technical mapping** | Architecture **`architecture-BMADMonorepoEFInternalTools-2026-03-15.md`** — **§4.4 Directus binding**, **ADR-14**. |
| **Automation & runbooks** | `projects/internal-erp/directus/README.md`; scripts under `projects/internal-erp/directus/scripts/` (e.g. `apply-m2o-dropdown-templates.mjs` and **`--force`** when record views regress to raw PKs, `lib/m2o-readable-meta.mjs`, `lib/collection-display-templates.mjs`). |

**Directus-specific note (implementation detail, not a duplicate of §1):** Today’s binding uses M2O relations, **`select-dropdown-m2o`** (preferred on v11), **`related-values`** display with aligned templates, and repo scripts after metadata changes — see Architecture §4.4 for exact field-meta expectations.

### Future admin products (examples only — not configured until this table is updated)

- **Strapi**, **Payload**, **Keystone**, or another **PostgreSQL-backed** headless CMS / admin generator  
- **Custom React/Vite admin** reading the same API contract  

Each MUST implement §§ **1–2**; duplicate **vendor field-meta names** from Directus only in **Architecture** + product-specific docs, **not** in PRD/Epic prose.

---

## 4. Traceability

| Artifact | Pointer |
|----------|---------|
| **PRD** | **NFR14** → this document |
| **Architecture** | **ADR-14**, **§4.4** → Directus binding for this document’s §1–2 |
| **Epic 1 / foundation stories** | Satisfy **NFR14** via this document; avoid copy-pasting acceptance text — reference **§1 R1–R3** and **§3** for verification method |
