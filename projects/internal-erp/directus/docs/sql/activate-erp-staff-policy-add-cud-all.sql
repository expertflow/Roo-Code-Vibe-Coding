-- Append create / update / delete for every BASE TABLE in the ERP schema for an existing policy.
-- Use only where you intentionally want full CRUD on all ERP tables (prefer tightening later).
--
-- Prerequisite: run activate-erp-staff-policy-read.sql (or equivalent) first.
--
--   psql ... -v ON_ERROR_STOP=1 \
--     -v policy_id=5d3e8662-4298-4b9a-94e7-3edbeb2ba061 \
--     -v erp_schema=BS4Prod09Feb2026 \
--     -f activate-erp-staff-policy-add-cud-all.sql

BEGIN;

DELETE FROM directus.directus_permissions
WHERE policy = :'policy_id'::uuid
  AND action IN ('create', 'update', 'delete');

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
  a.action,
  NULL::json,
  NULL::json,
  NULL::json,
  NULL::text,
  :'policy_id'::uuid
FROM information_schema.tables
CROSS JOIN (
  VALUES ('create'), ('update'), ('delete')
) AS a (action)
WHERE table_schema = :'erp_schema'
  AND table_type = 'BASE TABLE';

COMMIT;
