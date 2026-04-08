# Story 1.3 — Organizational & HR core collections (implementation companion)

Checklist for **`_bmad-output/implementation-artifacts/1-3-register-organizational-hr-core-collections.md`**.

**Automation:** `projects/internal-erp/directus/scripts/apply-story-1-3-org-hr-meta.mjs`  
**Config (schema-validated):** `scripts/lib/story-1-3-config.mjs`  
**Tests:** `node --test projects/internal-erp/directus/scripts/story-1-3-config.test.mjs`

---

## AC verification (Administrator)

1. **Employee** — display template `{{EmployeeName}} ({{email}})`; **ManagerId** is M2O → **Employee**.
2. **Project** — **ProfitCenter** is M2O → **ProfitCenter** (list by name via relation).
3. **LegalEntity** — **Type** is select-dropdown (suggested values + allow other); display `{{Name}} ({{Type}})`.
4. **EmployeePersonalInfo** — **employee_id** is M2O → **Employee**; template shows linked employee name.

**Phase 1:** **Employee.ProfitCenter** is **hidden** in field metadata (PRD A2 / FR22); RBAC refinement in Epic 2.

---

## Optional manual follow-up

- If **Project.Status** enum values in PostgreSQL differ from `Active` / `Inactive` / `Archived`, keep **allow other** on the dropdown or adjust `PROJECT_STATUS_CHOICES` in `story-1-3-config.mjs`.
- Canonical **`schema.json`**: Story **1.7**.
