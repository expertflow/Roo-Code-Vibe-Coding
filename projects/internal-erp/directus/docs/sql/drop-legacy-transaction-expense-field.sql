BEGIN;

-- Remove stale Directus metadata + DB column for Transaction.expense_id.
-- Reason: not part of the intended source mapping; tracked as a shadow field in db_inconsistency_report.md.

DO $$
DECLARE
  r record;
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = current_schema()
      AND table_name = 'Transaction'
      AND column_name = 'expense_id'
  ) THEN
    FOR r IN
      SELECT DISTINCT c.conname
      FROM pg_constraint c
      JOIN pg_class t
        ON t.oid = c.conrelid
      JOIN pg_namespace n
        ON n.oid = t.relnamespace
      JOIN unnest(c.conkey) AS ck(attnum)
        ON TRUE
      JOIN pg_attribute a
        ON a.attrelid = t.oid
       AND a.attnum = ck.attnum
      WHERE n.nspname = current_schema()
        AND t.relname = 'Transaction'
        AND a.attname = 'expense_id'
    LOOP
      EXECUTE format('ALTER TABLE "Transaction" DROP CONSTRAINT IF EXISTS %I', r.conname);
    END LOOP;

    ALTER TABLE "Transaction" DROP COLUMN IF EXISTS "expense_id";
  END IF;
END $$;

DELETE FROM directus_relations
WHERE many_collection = 'Transaction'
  AND many_field = 'expense_id';

DELETE FROM directus_fields
WHERE collection = 'Transaction'
  AND field = 'expense_id';

COMMIT;
