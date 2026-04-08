BEGIN;

-- Remove stale Directus metadata + DB column for Invoice.employee_id.
-- Reason: the intended model links Invoice -> Account -> LegalEntity, not Invoice -> Employee directly.

DO $$
DECLARE
  r record;
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = current_schema()
      AND table_name = 'Invoice'
      AND column_name = 'employee_id'
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
        AND t.relname = 'Invoice'
        AND a.attname = 'employee_id'
    LOOP
      EXECUTE format('ALTER TABLE "Invoice" DROP CONSTRAINT IF EXISTS %I', r.conname);
    END LOOP;

    ALTER TABLE "Invoice" DROP COLUMN IF EXISTS "employee_id";
  END IF;
END $$;

DELETE FROM directus_relations
WHERE many_collection = 'Invoice'
  AND many_field = 'employee_id';

DELETE FROM directus_fields
WHERE collection = 'Invoice'
  AND field = 'employee_id';

COMMIT;
