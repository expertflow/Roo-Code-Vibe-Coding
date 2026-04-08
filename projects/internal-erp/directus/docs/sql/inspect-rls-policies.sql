-- 1. Which tables actually have RLS enforced?
SELECT relname, relrowsecurity, relforcerowsecurity
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'BS4Prod09Feb2026'
  AND relkind = 'r'
ORDER BY relname;

-- 2. Can directus_rls_subject read UserToRole? (policies subquery depends on this)
SET ROLE directus_rls_subject;
SELECT count(*) AS usertorole_rows_visible FROM "BS4Prod09Feb2026"."UserToRole";
RESET ROLE;

-- 3. auth_crud function definition (SECURITY DEFINER bypasses RLS?)
SELECT routine_name, security_type, routine_definition
FROM information_schema.routines
WHERE routine_schema = 'BS4Prod09Feb2026'
  AND routine_name = 'auth_crud';
