SET search_path = "BS4Prod09Feb2026";

SELECT current_user AS whoami;
SELECT count(*) AS invoice_count_sterile FROM "Invoice";
SELECT count(*) AS transaction_count_sterile FROM "Transaction";

SET ROLE directus_rls_subject;
SELECT set_config('app.user_email', 'andreas.stuber@expertflow.com', true);
SELECT current_user AS whoami_with_role;
SELECT count(*) AS invoice_count_andreas FROM "Invoice";
SELECT count(*) AS transaction_count_andreas FROM "Transaction";
RESET ROLE;
