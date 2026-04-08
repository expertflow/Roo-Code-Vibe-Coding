-- Grant RLS session role access to ERP schema (adjust name to match DB_SEARCH_PATH__0).
GRANT USAGE ON SCHEMA "BS4Prod09Feb2026" TO directus_rls_subject;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA "BS4Prod09Feb2026" TO directus_rls_subject;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA "BS4Prod09Feb2026" TO directus_rls_subject;

-- Grant RLS session role access to Directus system schema.
-- Required because SET ROLE directus_rls_subject also covers Directus internal
-- writes (directus_activity, directus_presets, directus_revisions, etc.).
GRANT USAGE ON SCHEMA directus TO directus_rls_subject;
GRANT ALL ON ALL TABLES IN SCHEMA directus TO directus_rls_subject;
GRANT ALL ON ALL SEQUENCES IN SCHEMA directus TO directus_rls_subject;
