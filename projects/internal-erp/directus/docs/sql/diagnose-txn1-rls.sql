-- Diagnosis: why is TXN-1 (OriginAccount=7, DestinationAccount=98) visible
-- to apstuber@gmail.com (not in UserToRole)?

SET search_path = "BS4Prod09Feb2026";

-- 1. LegalEntity type for accounts 7 and 98 (as bs4_dev / owner)
SELECT a.id AS account_id,
       a."LegalEntity" AS le_id,
       l."Name"        AS le_name,
       l."Type"        AS le_type
FROM   "Account" a
LEFT JOIN "LegalEntity" l ON a."LegalEntity" = l.id
WHERE  a.id IN (7, 98);

-- 2. Same query as directus_rls_subject — confirms open SELECT policy works
SET ROLE directus_rls_subject;
SELECT a.id AS account_id,
       a."LegalEntity" AS le_id,
       l."Name"        AS le_name,
       l."Type"        AS le_type
FROM   "Account" a
LEFT JOIN "LegalEntity" l ON a."LegalEntity" = l.id
WHERE  a.id IN (7, 98);
RESET ROLE;

-- 3. Simulate the exact policy USING expression for TXN-1 as directus_rls_subject
-- Returns: TRUE = row would be VISIBLE (no sensitive leg), FALSE = HIDDEN
SET ROLE directus_rls_subject;
SELECT NOT EXISTS (
  SELECT 1
  FROM   "Account" a
  JOIN   "LegalEntity" l ON a."LegalEntity" = l.id
  WHERE  a.id IN (7, 98)
    AND  l."Type" IN ('Employee', 'Executive')
) AS txn1_visible_to_public;
RESET ROLE;

-- 4. All distinct LegalEntity Type values in the database (check exact strings)
SELECT DISTINCT "Type" FROM "LegalEntity" ORDER BY "Type";

-- 5. Is apstuber@gmail.com a Directus user? Which provider?
SELECT id, email, provider, status FROM directus_users WHERE email = 'apstuber@gmail.com';

-- 6. Compare actual row visibility by DB execution identity
-- bs4_dev has owner-access policy; directus_rls_subject + app.user_email should not.
SELECT id, "OriginAccount", "DestinationAccount"
FROM "Transaction"
WHERE id = 1;

SET ROLE directus_rls_subject;
SELECT set_config('app.user_email', 'apstuber@gmail.com', true);
SELECT id, "OriginAccount", "DestinationAccount"
FROM "Transaction"
WHERE id = 1;
RESET ROLE;
