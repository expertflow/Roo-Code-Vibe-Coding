-- Activate "ERP staff" style access without using the Admin UI:
-- 1) Turn on app access for the policy (so users with that role can open the Data Studio / app).
-- 2) Grant read on every BASE TABLE in the ERP schema (names match information_schema.table_name).
--
-- Run with psql variables (adjust UUID + schema to your environment):
--   psql ... -v ON_ERROR_STOP=1 \
--     -v policy_id=5d3e8662-4298-4b9a-94e7-3edbeb2ba061 \
--     -v erp_schema=BS4Prod09Feb2026 \
--     -f activate-erp-staff-policy-read.sql
--
-- Optional: after this, add create/update/delete only where needed (UI or separate SQL).
-- If directus.directus_collections is empty but the app still lists collections, Directus may be
-- inferring from the database; if the sidebar is empty, bootstrap / schema sync is a separate step.

BEGIN;

UPDATE directus.directus_policies
SET app_access = true
WHERE id = :'policy_id'::uuid;

DELETE FROM directus.directus_permissions
WHERE policy = :'policy_id'::uuid;

INSERT INTO directus.directus_permissions (
  collection,
  action,
  permissions,
  validation,
  presets,
  fields,
  policy
)
SELECT
  table_name,
  'read',
  NULL::json,
  NULL::json,
  NULL::json,
  NULL::text,
  :'policy_id'::uuid
FROM information_schema.tables
WHERE table_schema = :'erp_schema'
  AND table_type = 'BASE TABLE';

COMMIT;
