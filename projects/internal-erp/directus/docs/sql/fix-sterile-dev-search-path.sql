-- Fix: sterile_dev and directus_rls_subject must resolve tables in the directus schema
-- (where directus_* system tables live), the ERP schema, and public.
--
-- Root cause: the RLS extension does SET ROLE directus_rls_subject, and PostgreSQL
-- silently skips schemas where the active role lacks USAGE — even if search_path lists them.
-- Without GRANT USAGE ON SCHEMA directus TO directus_rls_subject, queries like
-- SELECT ... FROM "directus_users" fail with 42P01 while the role is active.
--
-- Run as bs4_dev (or any role that can ALTER ROLE and GRANT on schema directus).

-- 1. Role-level search_path defaults (applied at login / new connection)
ALTER ROLE sterile_dev SET search_path TO "BS4Prod09Feb2026", directus, public;

-- 2. directus_rls_subject needs USAGE + SELECT on the directus schema
GRANT USAGE ON SCHEMA directus TO directus_rls_subject;
GRANT SELECT ON ALL TABLES IN SCHEMA directus TO directus_rls_subject;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA directus TO directus_rls_subject;

-- 3. Future objects in schema directus (e.g. after Directus upgrades / migrations)
ALTER DEFAULT PRIVILEGES IN SCHEMA directus GRANT SELECT ON TABLES TO directus_rls_subject;
ALTER DEFAULT PRIVILEGES IN SCHEMA directus GRANT USAGE, SELECT ON SEQUENCES TO directus_rls_subject;
