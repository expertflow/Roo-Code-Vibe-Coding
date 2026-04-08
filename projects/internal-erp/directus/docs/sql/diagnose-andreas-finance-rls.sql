SET search_path = "BS4Prod09Feb2026";

SELECT u.id, u.email, u.provider, u.status
FROM directus_users u
WHERE lower(u.email) = 'andreas.stuber@expertflow.com';

SELECT utr.id, utr."User", utr."RoleName", r."Name" AS role_name
FROM "UserToRole" utr
LEFT JOIN "Role" r ON r.id = utr."RoleName"
WHERE lower(utr."User") = 'andreas.stuber@expertflow.com';

SELECT tablename, policyname, cmd, roles::text
FROM pg_policies
WHERE schemaname = 'BS4Prod09Feb2026'
  AND tablename IN ('Invoice', 'Transaction')
  AND (policyname ILIKE '%finance%' OR policyname = 'policy_finance')
ORDER BY tablename, policyname;
