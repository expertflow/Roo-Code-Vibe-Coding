SELECT
    n.nspname,
    c.relname,
    c.relkind
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relname = 'directus_activity';
