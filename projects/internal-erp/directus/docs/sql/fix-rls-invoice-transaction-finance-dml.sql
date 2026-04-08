-- =============================================================================
-- fix-rls-invoice-transaction-finance-dml.sql
--
-- Symptom (Directus): INSERT Invoice / Transaction fails with:
--   column rp.RoleName does not exist
--
-- Root cause: A row-level security policy (often INSERT / UPDATE / DELETE) was
-- written joining "RolePermissions" AS rp but referencing rp."RoleName".
-- The PostgreSQL table "RolePermissions" has column "Role" (FK → "Role".id),
-- not "RoleName". The column "RoleName" exists on "UserToRole" (FK → "Role").
--
-- Fix: Drop all **non-SELECT** RLS policies on "Invoice" and "Transaction"
-- (removes broken DML policies with any name), then add canonical **Finance**
-- INSERT / UPDATE / DELETE policies matching "Accruals" / "Journal" in
-- fix-rls-policies-v2.sql (UserToRole + "RoleName" = Finance role id).
--
-- SELECT policies from fix-rls-policies-v2.sql are **unchanged** (not dropped).
--
-- Run as break-glass (e.g. bs4_dev) or superuser. Schema: BS4Prod09Feb2026.
-- Safe to re-run: DROP uses IF EXISTS via dynamic policy list.
-- =============================================================================

BEGIN;

SET search_path = "BS4Prod09Feb2026";

-- Drop every non-SELECT policy on Invoice / Transaction (clears bad DML SQL).
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT policyname
    FROM pg_policies
    WHERE schemaname = 'BS4Prod09Feb2026'
      AND tablename = 'Invoice'
      AND cmd <> 'SELECT'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON "Invoice"', r.policyname);
  END LOOP;

  FOR r IN
    SELECT policyname
    FROM pg_policies
    WHERE schemaname = 'BS4Prod09Feb2026'
      AND tablename = 'Transaction'
      AND cmd <> 'SELECT'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON "Transaction"', r.policyname);
  END LOOP;
END $$;

-- -----------------------------------------------------------------------------
-- Invoice — Finance DML (mirror Accruals / Journal in fix-rls-policies-v2.sql)
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS policy_invoice_finance_insert ON "Invoice";
DROP POLICY IF EXISTS policy_invoice_finance_update ON "Invoice";
DROP POLICY IF EXISTS policy_invoice_finance_delete ON "Invoice";

CREATE POLICY policy_invoice_finance_insert
  ON "Invoice"
  FOR INSERT TO PUBLIC
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM "UserToRole"
      WHERE LOWER("User") = LOWER(current_setting('app.user_email', true))
        AND "RoleName" = (SELECT id FROM "Role" WHERE "Name" = 'Finance')
    )
  );

CREATE POLICY policy_invoice_finance_update
  ON "Invoice"
  FOR UPDATE TO PUBLIC
  USING (
    EXISTS (
      SELECT 1 FROM "UserToRole"
      WHERE LOWER("User") = LOWER(current_setting('app.user_email', true))
        AND "RoleName" = (SELECT id FROM "Role" WHERE "Name" = 'Finance')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM "UserToRole"
      WHERE LOWER("User") = LOWER(current_setting('app.user_email', true))
        AND "RoleName" = (SELECT id FROM "Role" WHERE "Name" = 'Finance')
    )
  );

CREATE POLICY policy_invoice_finance_delete
  ON "Invoice"
  FOR DELETE TO PUBLIC
  USING (
    EXISTS (
      SELECT 1 FROM "UserToRole"
      WHERE LOWER("User") = LOWER(current_setting('app.user_email', true))
        AND "RoleName" = (SELECT id FROM "Role" WHERE "Name" = 'Finance')
    )
  );

-- -----------------------------------------------------------------------------
-- Transaction — Finance DML
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS policy_transaction_finance_insert ON "Transaction";
DROP POLICY IF EXISTS policy_transaction_finance_update ON "Transaction";
DROP POLICY IF EXISTS policy_transaction_finance_delete ON "Transaction";

CREATE POLICY policy_transaction_finance_insert
  ON "Transaction"
  FOR INSERT TO PUBLIC
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM "UserToRole"
      WHERE LOWER("User") = LOWER(current_setting('app.user_email', true))
        AND "RoleName" = (SELECT id FROM "Role" WHERE "Name" = 'Finance')
    )
  );

CREATE POLICY policy_transaction_finance_update
  ON "Transaction"
  FOR UPDATE TO PUBLIC
  USING (
    EXISTS (
      SELECT 1 FROM "UserToRole"
      WHERE LOWER("User") = LOWER(current_setting('app.user_email', true))
        AND "RoleName" = (SELECT id FROM "Role" WHERE "Name" = 'Finance')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM "UserToRole"
      WHERE LOWER("User") = LOWER(current_setting('app.user_email', true))
        AND "RoleName" = (SELECT id FROM "Role" WHERE "Name" = 'Finance')
    )
  );

CREATE POLICY policy_transaction_finance_delete
  ON "Transaction"
  FOR DELETE TO PUBLIC
  USING (
    EXISTS (
      SELECT 1 FROM "UserToRole"
      WHERE LOWER("User") = LOWER(current_setting('app.user_email', true))
        AND "RoleName" = (SELECT id FROM "Role" WHERE "Name" = 'Finance')
    )
  );

COMMIT;

-- Verification (optional):
-- SELECT tablename, policyname, cmd FROM pg_policies
-- WHERE schemaname = 'BS4Prod09Feb2026'
--   AND tablename IN ('Invoice', 'Transaction')
-- ORDER BY tablename, cmd, policyname;
