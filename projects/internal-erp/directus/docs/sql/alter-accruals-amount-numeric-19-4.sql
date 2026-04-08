-- Accruals."Amount": text -> numeric(19,4)
-- Run as table owner or break-glass (e.g. bs4_dev). sterile_dev cannot ALTER.
--
-- Preconditions: every non-null "Amount" value must cast to numeric (no currency symbols,
-- locale commas, etc.). Empty/whitespace -> NULL.
--
-- After apply: re-run Directus schema snapshot if Accruals metadata should match DB.

SET search_path TO "BS4Prod09Feb2026";

ALTER TABLE "Accruals"
  ALTER COLUMN "Amount" TYPE numeric(19,4)
  USING (NULLIF(trim("Amount"), '')::numeric);

-- Optional: mirror sandbox schema (uncomment if you use it)
-- SET search_path TO "testschema04feb";
-- ALTER TABLE "Accruals"
--   ALTER COLUMN "Amount" TYPE numeric(19,4)
--   USING (NULLIF(trim("Amount"), '')::numeric);
