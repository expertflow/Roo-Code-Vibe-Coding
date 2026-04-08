SELECT
    t.table_schema,
    t.table_name,
    c.column_name,
    c.data_type,
    c.is_identity,
    c.column_default
FROM
    information_schema.tables t
JOIN
    information_schema.key_column_usage kcu
    ON t.table_name = kcu.table_name
    AND t.table_schema = kcu.table_schema
JOIN
    information_schema.table_constraints tc
    ON tc.constraint_name = kcu.constraint_name
JOIN
    information_schema.columns c
    ON c.table_name = t.table_name
    AND c.table_schema = t.table_schema
    AND c.column_name = kcu.column_name
WHERE
    tc.constraint_type = 'PRIMARY KEY'
    AND t.table_schema IN ('bs4_sandbox', 'public')
    AND c.data_type = 'integer'
    AND c.is_identity = 'NO'
    AND c.column_default IS NULL
    AND t.table_name NOT LIKE 'directus_%';
