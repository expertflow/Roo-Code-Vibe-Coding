-- Story 1-10 — PostgreSQL role for RLS session switching
-- -----------------------------------------------------------------------------
-- `SET LOCAL ROLE public` is INVALID: there is no role named "public" in PostgreSQL.
-- `PUBLIC` in CREATE POLICY / GRANT is a keyword, not a role.
--
-- The Directus extension runs `SET ROLE <RLS_SESSION_ROLE>` (default:
-- `directus_rls_subject`) so the session is not the table owner and RLS applies,
-- then `app.user_email` drives row visibility.
--
-- IMPORTANT: Because SET ROLE applies to ALL queries on the connection — including
-- Directus's internal writes to directus_activity, directus_revisions, and
-- directus_presets — the role MUST have INSERT/UPDATE access to the `directus`
-- schema as well as the ERP schema. Missing this causes:
--   "permission denied for table directus_activity" on every item save.
--
-- Edit and run as superuser or owner. Set your real Directus DB user below.
-- -----------------------------------------------------------------------------

CREATE ROLE directus_rls_subject NOLOGIN;

-- Directus runtime user MUST be able to SET ROLE to this NOLOGIN role.
-- Prefer sterile_dev (no policy_owner_access_*); keep bs4_dev only for break-glass tooling.
GRANT directus_rls_subject TO sterile_dev;
GRANT directus_rls_subject TO bs4_dev;

-- ERP schema: row-level access for application data.
-- Replace `public` with your ERP schema if needed (quote mixed-case names).
GRANT USAGE ON SCHEMA "BS4Prod09Feb2026" TO directus_rls_subject;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA "BS4Prod09Feb2026" TO directus_rls_subject;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA "BS4Prod09Feb2026" TO directus_rls_subject;

-- Directus system schema: required for internal Directus writes (activity log,
-- revisions, presets, etc.) that run under SET ROLE on the same connection.
-- Without these grants, every item mutation returns "permission denied for table directus_activity".
GRANT USAGE ON SCHEMA directus TO directus_rls_subject;
GRANT ALL ON ALL TABLES IN SCHEMA directus TO directus_rls_subject;
GRANT ALL ON ALL SEQUENCES IN SCHEMA directus TO directus_rls_subject;

-- After adding new tables (ERP or Directus upgrade): re-run the GRANT ALL TABLES
-- lines above, or add ALTER DEFAULT PRIVILEGES so new tables are auto-granted.
--
-- See: docs/troubleshooting-rls-permissions.md for diagnosis steps.
