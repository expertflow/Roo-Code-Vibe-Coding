-- =============================================================================
-- setup-sterile-dev.sql — Directus runtime DB user (no RLS blanket bypass)
-- =============================================================================
-- Run as bs4_dev (or superuser). Idempotent where possible.
--
-- sterile_dev:
--   - NOT listed on policy_owner_access_* (those are TO bs4_dev only).
--   - Member of directus_rls_subject so SET LOCAL ROLE works from extension.
--   - DML + schema USAGE on public + ERP schema so Directus + RLS subject work.
--
-- bs4_dev remains break-glass / migrations / owner-style operations.
--
-- After run: set DB_USER=sterile_dev and DB_PASSWORD in .env; recreate Directus.
-- =============================================================================

-- 1) Extension must be able to SET LOCAL ROLE directus_rls_subject
GRANT directus_rls_subject TO sterile_dev;

-- 2) Database connect
GRANT CONNECT ON DATABASE bidstruct4 TO sterile_dev;

-- 3) Schemas — Directus system tables live in public; ERP in BS4Prod09Feb2026
GRANT USAGE ON SCHEMA public TO sterile_dev;
GRANT CREATE ON SCHEMA public TO sterile_dev;

GRANT USAGE ON SCHEMA "BS4Prod09Feb2026" TO sterile_dev;

-- 4) Existing objects in public (directus_*, PostGIS, etc.)
GRANT SELECT, INSERT, UPDATE, DELETE, REFERENCES, TRIGGER ON ALL TABLES IN SCHEMA public TO sterile_dev;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO sterile_dev;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO sterile_dev;

-- 5) Existing objects in ERP schema (tables may be owned by bs4_dev or BS4Prod09Feb2026)
GRANT SELECT, INSERT, UPDATE, DELETE, REFERENCES, TRIGGER ON ALL TABLES IN SCHEMA "BS4Prod09Feb2026" TO sterile_dev;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA "BS4Prod09Feb2026" TO sterile_dev;

-- 6) Future objects created by bs4_dev in public (Directus migrations)
ALTER DEFAULT PRIVILEGES FOR ROLE bs4_dev IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE, REFERENCES, TRIGGER ON TABLES TO sterile_dev;
ALTER DEFAULT PRIVILEGES FOR ROLE bs4_dev IN SCHEMA public
  GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO sterile_dev;
ALTER DEFAULT PRIVILEGES FOR ROLE bs4_dev IN SCHEMA public
  GRANT EXECUTE ON FUNCTIONS TO sterile_dev;

-- 7) Future objects in ERP schema if created as bs4_dev
ALTER DEFAULT PRIVILEGES FOR ROLE bs4_dev IN SCHEMA "BS4Prod09Feb2026"
  GRANT SELECT, INSERT, UPDATE, DELETE, REFERENCES, TRIGGER ON TABLES TO sterile_dev;
ALTER DEFAULT PRIVILEGES FOR ROLE bs4_dev IN SCHEMA "BS4Prod09Feb2026"
  GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO sterile_dev;

-- 8) ERP objects owned by role "BS4Prod09Feb2026" (not by bs4_dev) — grant only those.
--    GRANT ... ON ALL TABLES IN SCHEMA would fail for tables owned by bs4_dev while SET ROLE
--    to the schema role (permission denied on e.g. directus_sessions in that schema).
DO $grant_bs4_schema_owned$
DECLARE
  r RECORD;
  v_owner oid := (SELECT oid FROM pg_roles WHERE rolname = 'BS4Prod09Feb2026');
BEGIN
  IF v_owner IS NULL THEN
    RAISE NOTICE 'Role BS4Prod09Feb2026 not found; skip schema-owner grants';
    RETURN;
  END IF;
  SET LOCAL ROLE "BS4Prod09Feb2026";
  FOR r IN
    SELECT c.relname
    FROM   pg_class c
    JOIN   pg_namespace n ON n.oid = c.relnamespace
    WHERE  n.nspname = 'BS4Prod09Feb2026'
      AND  c.relkind = 'r'
      AND  c.relowner = v_owner
  LOOP
    EXECUTE format(
      'GRANT SELECT, INSERT, UPDATE, DELETE, REFERENCES, TRIGGER ON "BS4Prod09Feb2026".%I TO sterile_dev',
      r.relname
    );
  END LOOP;
  FOR r IN
    SELECT c.relname
    FROM   pg_class c
    JOIN   pg_namespace n ON n.oid = c.relnamespace
    WHERE  n.nspname = 'BS4Prod09Feb2026'
      AND  c.relkind = 'S'
      AND  c.relowner = v_owner
  LOOP
    EXECUTE format(
      'GRANT USAGE, SELECT, UPDATE ON "BS4Prod09Feb2026".%I TO sterile_dev',
      r.relname
    );
  END LOOP;
END
$grant_bs4_schema_owned$;

SET ROLE "BS4Prod09Feb2026";
ALTER DEFAULT PRIVILEGES FOR ROLE "BS4Prod09Feb2026" IN SCHEMA "BS4Prod09Feb2026"
  GRANT SELECT, INSERT, UPDATE, DELETE, REFERENCES, TRIGGER ON TABLES TO sterile_dev;
ALTER DEFAULT PRIVILEGES FOR ROLE "BS4Prod09Feb2026" IN SCHEMA "BS4Prod09Feb2026"
  GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO sterile_dev;
RESET ROLE;

-- 9) Password — CHANGE THIS before production; keep in sync with .env DB_PASSWORD
ALTER ROLE sterile_dev LOGIN PASSWORD 'SterileDev_ChangeMe_2026!';
