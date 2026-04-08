SET search_path = "BS4Prod09Feb2026";

SET ROLE directus_rls_subject;
SELECT set_config('app.user_email', 'andreas.stuber@expertflow.com', true);

SELECT current_user AS whoami,
       current_setting('app.user_email', true) AS app_user_email;

SELECT EXISTS (
  SELECT 1
  FROM "UserToRole"
  WHERE lower("User") = lower(current_setting('app.user_email', true))
    AND "RoleName" = (SELECT id FROM "Role" WHERE "Name" = 'Finance')
) AS finance_predicate_lower;

SELECT EXISTS (
  SELECT 1
  FROM "UserToRole"
  WHERE "User" = current_setting('app.user_email', true)
    AND "RoleName" = (SELECT id FROM "Role" WHERE "Name" = 'Finance')
) AS finance_predicate_exact;

SELECT id, "User", "RoleName"
FROM "UserToRole"
WHERE lower("User") = lower(current_setting('app.user_email', true));

SELECT id, "Name"
FROM "Role"
WHERE "Name" IN ('Finance', 'HR');

RESET ROLE;
