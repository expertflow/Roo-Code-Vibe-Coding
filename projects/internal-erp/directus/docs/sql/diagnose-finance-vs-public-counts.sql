SET search_path = "BS4Prod09Feb2026";

-- Total rows as break-glass baseline
SELECT count(*) AS invoice_count_total FROM "Invoice";
SELECT count(*) AS transaction_count_total FROM "Transaction";

-- Public/external user rows
SET ROLE directus_rls_subject;
SELECT set_config('app.user_email', 'apstuber@gmail.com', true);
SELECT count(*) AS invoice_count_public FROM "Invoice";
SELECT count(*) AS transaction_count_public FROM "Transaction";
RESET ROLE;

-- Finance user rows
SET ROLE directus_rls_subject;
SELECT set_config('app.user_email', 'andreas.stuber@expertflow.com', true);
SELECT count(*) AS invoice_count_finance FROM "Invoice";
SELECT count(*) AS transaction_count_finance FROM "Transaction";
RESET ROLE;

-- Policy targets
SELECT tablename, policyname, roles::text
FROM pg_policies
WHERE schemaname = 'BS4Prod09Feb2026'
  AND tablename IN ('Invoice', 'Transaction')
  AND policyname IN ('policy_finance','policy_invoice_finance_select','policy_transaction_finance_select','policy_invoice_sterile_select','policy_transaction_sterile_select')
ORDER BY tablename, policyname;
