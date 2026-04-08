SELECT 
    nspname as schema_name, 
    has_schema_privilege('sterile_dev', nspname, 'USAGE') as can_use
FROM pg_namespace
WHERE nspname IN ('BS4Prod09Feb2026', 'directus', 'public');
