-- Sanity check: Directus resolves unqualified directus_* via DB_SEARCH_PATH (ERP schema first, then directus).
-- Run: psql -U sterile_dev -d bidstruct4 -v ON_ERROR_STOP=1 -f verify-sterile-dev-directus-search-path.sql
-- Expect: one email row. If ERROR relation "directus_users" does not exist, fix grants on schema directus
-- or align DB_SEARCH_PATH__* with your deployment.

SET search_path TO "BS4Prod09Feb2026", directus, public;
SELECT email FROM directus_users LIMIT 1;
