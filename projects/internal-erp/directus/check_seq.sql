SELECT
    n.nspname as schema_name,
    c.relname as relation_name,
    c.relrowsecurity as rls_enabled,
    c.relforcerowsecurity as rls_forced,
    (CASE WHEN c.relkind = 'S' THEN has_sequence_privilege('sterile_dev', quote_ident(n.nspname) || '.' || quote_ident(c.relname), 'USAGE') ELSE null END) as seq_usage
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relname LIKE 'directus_activity%';
