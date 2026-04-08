-- Run: psql -U sterile_dev -d bidstruct4 -f verify-sterile-dev-rls.sql
SET search_path = "BS4Prod09Feb2026";

SELECT current_user AS whoami;

-- No app.user_email: expect no row (no policy passes for sensitive TXN-1)
SELECT id FROM "Transaction" WHERE id = 1;

-- With RLS subject + external email not in UserToRole: expect no row
SET ROLE directus_rls_subject;
SELECT set_config('app.user_email', 'apstuber@gmail.com', true);
SELECT id FROM "Transaction" WHERE id = 1;
RESET ROLE;
