-- Amount columns: JDBC-style + PostgreSQL declared type (typmod).
-- Run with psql or any SQL client connected via Cloud SQL Auth Proxy.

SELECT table_schema,
       table_name,
       column_name,
       data_type,
       numeric_precision,
       numeric_scale
FROM information_schema.columns
WHERE column_name = 'Amount'
  AND table_schema NOT IN ('pg_catalog', 'information_schema')
ORDER BY table_schema, table_name;

SELECT n.nspname AS schema,
       c.relname AS relation,
       c.relkind,
       a.attname,
       pg_catalog.format_type(a.atttypid, a.atttypmod) AS pg_type
FROM pg_catalog.pg_attribute a
JOIN pg_catalog.pg_class c ON c.oid = a.attrelid
JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
WHERE a.attname = 'Amount'
  AND NOT a.attisdropped
  AND c.relkind IN ('r', 'v', 'm')
  AND n.nspname NOT IN ('pg_catalog', 'information_schema')
ORDER BY 1, 2;
