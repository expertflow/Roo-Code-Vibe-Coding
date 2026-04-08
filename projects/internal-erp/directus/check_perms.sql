SELECT 
    schemaname, 
    tablename, 
    tableowner, 
    has_table_privilege('sterile_dev', quote_ident(schemaname) || '.' || quote_ident(tablename), 'INSERT') as can_insert
FROM pg_tables
WHERE tablename = 'directus_activity';
