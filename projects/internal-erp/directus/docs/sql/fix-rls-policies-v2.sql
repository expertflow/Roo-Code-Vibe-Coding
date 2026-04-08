-- =============================================================================
-- fix-rls-policies-v2.sql
-- NFR13 / Architecture §8.2 — RLS policy correctness patch
--
-- Bugs fixed (identified in Story 1-10 audit):
--   1. FORCE ROW LEVEL SECURITY on all 12 protected tables
--      → bs4_dev (table owner) can no longer bypass RLS; it is still governed
--        by its own policy_owner_access_* (USING true) so system traffic is
--        unaffected. Directus admin users cannot bypass via ownership either.
--   2. UserToRole / Role / RolePermissions / Account / LegalEntity:
--      add PUBLIC SELECT (open read) so policy subquery JOINs resolve for
--      directus_rls_subject (the critical structural bug that silently broke
--      all Finance/HR policies on every other table).
--   3. Transaction public_read: was checking DestinationAccount only;
--      must check BOTH OriginAccount AND DestinationAccount (NFR13).
--   4. Invoice public_read: same single-leg bug as Transaction.
--   5. Allocation public_read: same single-leg bug.
--   6. BankStatement: ensure canonical Finance / HR / public policies exist
--      (single Account leg — simpler check).
--   7. Transaction HR policy: was missing Executive-exclusion leg check and
--      only tested DestinationAccount; must be (one leg Employee) AND
--      (no leg Executive) checking both legs.
--   8. Invoice HR policy: same HR bugs as Transaction.
--   9. Accruals: Finance SELECT + full DML policies were missing entirely.
--  10. Journal:  Finance SELECT + full DML policies were missing entirely.
--
-- Safe to re-run: DROP IF EXISTS guards prevent duplicate-policy errors.
-- Run as bs4_dev (or any superuser) while the Directus container is up.
--
-- Invoice / Transaction **INSERT** fails with `column rp.RoleName does not exist`?
-- That is a **separate** bad DML policy (RolePermissions has "Role", not "RoleName").
-- Apply: fix-rls-invoice-transaction-finance-dml.sql
-- =============================================================================

BEGIN;

SET search_path = "BS4Prod09Feb2026";

-- =============================================================================
-- SECTION 1 — FORCE ROW LEVEL SECURITY on all 12 protected tables
-- With FORCE, even the table owner (bs4_dev) goes through RLS.
-- bs4_dev still has policy_owner_access_* (USING true) on every table, so
-- migrations and internal Directus knex paths that never call SET LOCAL ROLE
-- continue to see all rows via those owner policies.
-- After SET LOCAL ROLE directus_rls_subject, ownership does not matter —
-- only policies with TO PUBLIC / TO directus_rls_subject apply.
-- =============================================================================

ALTER TABLE "Account"           FORCE ROW LEVEL SECURITY;
ALTER TABLE "Accruals"          FORCE ROW LEVEL SECURITY;
ALTER TABLE "Allocation"        FORCE ROW LEVEL SECURITY;
ALTER TABLE "BankStatement"     FORCE ROW LEVEL SECURITY;
ALTER TABLE "Employee"          FORCE ROW LEVEL SECURITY;
ALTER TABLE "Invoice"           FORCE ROW LEVEL SECURITY;
ALTER TABLE "Journal"           FORCE ROW LEVEL SECURITY;
ALTER TABLE "LegalEntity"       FORCE ROW LEVEL SECURITY;
ALTER TABLE "Role"              FORCE ROW LEVEL SECURITY;
ALTER TABLE "RolePermissions"   FORCE ROW LEVEL SECURITY;
ALTER TABLE "Transaction"       FORCE ROW LEVEL SECURITY;
ALTER TABLE "UserToRole"        FORCE ROW LEVEL SECURITY;

-- =============================================================================
-- SECTION 2 — Open SELECT on lookup / reference tables
-- Architecture §8.2: Account, LegalEntity, Role, RolePermissions, UserToRole
-- are all "Open select".  directus_rls_subject MUST be able to read these
-- tables so that USING-clause subqueries inside financial policies can join
-- through them.  Without this, every Finance/HR subquery returns zero rows
-- and those policies silently deny access to every financial record.
-- =============================================================================

-- Account
DROP POLICY IF EXISTS policy_account_open_select ON "Account";
CREATE POLICY policy_account_open_select
  ON "Account"
  FOR SELECT TO PUBLIC
  USING (true);

-- LegalEntity
DROP POLICY IF EXISTS policy_legalentity_open_select ON "LegalEntity";
CREATE POLICY policy_legalentity_open_select
  ON "LegalEntity"
  FOR SELECT TO PUBLIC
  USING (true);

-- Role
DROP POLICY IF EXISTS policy_role_open_select ON "Role";
CREATE POLICY policy_role_open_select
  ON "Role"
  FOR SELECT TO PUBLIC
  USING (true);

-- RolePermissions
DROP POLICY IF EXISTS policy_rolepermissions_open_select ON "RolePermissions";
CREATE POLICY policy_rolepermissions_open_select
  ON "RolePermissions"
  FOR SELECT TO PUBLIC
  USING (true);

-- UserToRole  ← THE CRITICAL FIX: without this, Finance/HR lookup
-- subqueries on all financial tables see zero rows and silently deny access
DROP POLICY IF EXISTS policy_usertorole_open_select ON "UserToRole";
CREATE POLICY policy_usertorole_open_select
  ON "UserToRole"
  FOR SELECT TO PUBLIC
  USING (true);

-- =============================================================================
-- SECTION 3 — TRANSACTION
-- Architecture §8.2:
--   Public  : exclude if EITHER OriginAccount OR DestinationAccount is
--             Employee or Executive
--   HR      : at least one leg Employee AND zero legs Executive
--   Finance : full access
-- =============================================================================

DROP POLICY IF EXISTS policy_hr                         ON "Transaction";
DROP POLICY IF EXISTS policy_transaction_hr_select      ON "Transaction";
DROP POLICY IF EXISTS policy_transaction_public_read    ON "Transaction";
DROP POLICY IF EXISTS policy_transaction_finance_select ON "Transaction";

-- Public: hide if EITHER leg is Employee or Executive
CREATE POLICY policy_transaction_public_read
  ON "Transaction"
  FOR SELECT TO PUBLIC
  USING (
    NOT EXISTS (
      SELECT 1
      FROM   "Account" a
      JOIN   "LegalEntity" l ON a."LegalEntity" = l.id
      WHERE  a.id IN ("Transaction"."OriginAccount",
                      "Transaction"."DestinationAccount")
        AND  l."Type" IN ('Employee', 'Executive')
    )
  );

-- HR: one leg Employee, no leg Executive — checking BOTH legs
CREATE POLICY policy_transaction_hr_select
  ON "Transaction"
  FOR SELECT TO PUBLIC
  USING (
    EXISTS (
      SELECT 1 FROM "UserToRole"
      WHERE  LOWER("User") = LOWER(current_setting('app.user_email', true))
        AND  "RoleName" = (SELECT id FROM "Role" WHERE "Name" = 'HR')
    )
    AND EXISTS (
      SELECT 1 FROM "Account" a JOIN "LegalEntity" l ON a."LegalEntity" = l.id
      WHERE  a.id IN ("Transaction"."OriginAccount",
                      "Transaction"."DestinationAccount")
        AND  l."Type" = 'Employee'
    )
    AND NOT EXISTS (
      SELECT 1 FROM "Account" a JOIN "LegalEntity" l ON a."LegalEntity" = l.id
      WHERE  a.id IN ("Transaction"."OriginAccount",
                      "Transaction"."DestinationAccount")
        AND  l."Type" = 'Executive'
    )
  );

-- Finance: unrestricted read
CREATE POLICY policy_transaction_finance_select
  ON "Transaction"
  FOR SELECT TO PUBLIC
  USING (
    EXISTS (
      SELECT 1 FROM "UserToRole"
      WHERE  LOWER("User") = LOWER(current_setting('app.user_email', true))
        AND  "RoleName" = (SELECT id FROM "Role" WHERE "Name" = 'Finance')
    )
  );

-- =============================================================================
-- SECTION 4 — INVOICE
-- Architecture §8.2: "Same public/HR pattern as Transaction (both legs)"
-- =============================================================================

DROP POLICY IF EXISTS policy_hr                      ON "Invoice";
DROP POLICY IF EXISTS policy_invoice_hr_select       ON "Invoice";
DROP POLICY IF EXISTS policy_invoice_public_read     ON "Invoice";
DROP POLICY IF EXISTS policy_invoice_finance_select  ON "Invoice";

CREATE POLICY policy_invoice_public_read
  ON "Invoice"
  FOR SELECT TO PUBLIC
  USING (
    NOT EXISTS (
      SELECT 1
      FROM   "Account" a
      JOIN   "LegalEntity" l ON a."LegalEntity" = l.id
      WHERE  a.id IN ("Invoice"."OriginAccount",
                      "Invoice"."DestinationAccount")
        AND  l."Type" IN ('Employee', 'Executive')
    )
  );

CREATE POLICY policy_invoice_hr_select
  ON "Invoice"
  FOR SELECT TO PUBLIC
  USING (
    EXISTS (
      SELECT 1 FROM "UserToRole"
      WHERE  LOWER("User") = LOWER(current_setting('app.user_email', true))
        AND  "RoleName" = (SELECT id FROM "Role" WHERE "Name" = 'HR')
    )
    AND EXISTS (
      SELECT 1 FROM "Account" a JOIN "LegalEntity" l ON a."LegalEntity" = l.id
      WHERE  a.id IN ("Invoice"."OriginAccount",
                      "Invoice"."DestinationAccount")
        AND  l."Type" = 'Employee'
    )
    AND NOT EXISTS (
      SELECT 1 FROM "Account" a JOIN "LegalEntity" l ON a."LegalEntity" = l.id
      WHERE  a.id IN ("Invoice"."OriginAccount",
                      "Invoice"."DestinationAccount")
        AND  l."Type" = 'Executive'
    )
  );

CREATE POLICY policy_invoice_finance_select
  ON "Invoice"
  FOR SELECT TO PUBLIC
  USING (
    EXISTS (
      SELECT 1 FROM "UserToRole"
      WHERE  LOWER("User") = LOWER(current_setting('app.user_email', true))
        AND  "RoleName" = (SELECT id FROM "Role" WHERE "Name" = 'Finance')
    )
  );

-- =============================================================================
-- SECTION 5 — ALLOCATION
-- Architecture §8.2:
--   Public  : exclude if EITHER OriginAccount OR DestinationAccount is
--             Employee or Executive
--   HR      : DestinationAccount Employee only (no Executive exclusion spec'd
--             for Allocation — distinct from Transaction/Invoice)
--   Finance : full access
-- =============================================================================

DROP POLICY IF EXISTS policy_hr                        ON "Allocation";
DROP POLICY IF EXISTS policy_allocation_hr_select      ON "Allocation";
DROP POLICY IF EXISTS policy_allocation_public_read    ON "Allocation";
DROP POLICY IF EXISTS policy_allocation_finance_select ON "Allocation";

CREATE POLICY policy_allocation_public_read
  ON "Allocation"
  FOR SELECT TO PUBLIC
  USING (
    NOT EXISTS (
      SELECT 1
      FROM   "Account" a
      JOIN   "LegalEntity" l ON a."LegalEntity" = l.id
      WHERE  a.id IN ("Allocation"."OriginAccount",
                      "Allocation"."DestinationAccount")
        AND  l."Type" IN ('Employee', 'Executive')
    )
  );

CREATE POLICY policy_allocation_hr_select
  ON "Allocation"
  FOR SELECT TO PUBLIC
  USING (
    EXISTS (
      SELECT 1 FROM "UserToRole"
      WHERE  LOWER("User") = LOWER(current_setting('app.user_email', true))
        AND  "RoleName" = (SELECT id FROM "Role" WHERE "Name" = 'HR')
    )
    AND EXISTS (
      SELECT 1 FROM "Account" a JOIN "LegalEntity" l ON a."LegalEntity" = l.id
      WHERE  a.id = "Allocation"."DestinationAccount"
        AND  l."Type" = 'Employee'
    )
  );

CREATE POLICY policy_allocation_finance_select
  ON "Allocation"
  FOR SELECT TO PUBLIC
  USING (
    EXISTS (
      SELECT 1 FROM "UserToRole"
      WHERE  LOWER("User") = LOWER(current_setting('app.user_email', true))
        AND  "RoleName" = (SELECT id FROM "Role" WHERE "Name" = 'Finance')
    )
  );

-- =============================================================================
-- SECTION 6 — BANKSTATEMENT
-- Architecture §8.2: single Account leg (not OriginAccount/DestinationAccount)
--   Public  : exclude if the linked Account is Employee or Executive
--   HR      : Account.LegalEntity.Type = 'Employee' only
--   Finance : full access
-- =============================================================================

DROP POLICY IF EXISTS policy_hr                           ON "BankStatement";
DROP POLICY IF EXISTS policy_bankstatement_hr_select      ON "BankStatement";
DROP POLICY IF EXISTS policy_bankstatement_public_read    ON "BankStatement";
DROP POLICY IF EXISTS policy_bankstatement_finance_select ON "BankStatement";

CREATE POLICY policy_bankstatement_public_read
  ON "BankStatement"
  FOR SELECT TO PUBLIC
  USING (
    NOT EXISTS (
      SELECT 1
      FROM   "Account" a
      JOIN   "LegalEntity" l ON a."LegalEntity" = l.id
      WHERE  a.id = "BankStatement"."Account"
        AND  l."Type" IN ('Employee', 'Executive')
    )
  );

CREATE POLICY policy_bankstatement_hr_select
  ON "BankStatement"
  FOR SELECT TO PUBLIC
  USING (
    EXISTS (
      SELECT 1 FROM "UserToRole"
      WHERE  LOWER("User") = LOWER(current_setting('app.user_email', true))
        AND  "RoleName" = (SELECT id FROM "Role" WHERE "Name" = 'HR')
    )
    AND EXISTS (
      SELECT 1 FROM "Account" a JOIN "LegalEntity" l ON a."LegalEntity" = l.id
      WHERE  a.id = "BankStatement"."Account"
        AND  l."Type" = 'Employee'
    )
  );

CREATE POLICY policy_bankstatement_finance_select
  ON "BankStatement"
  FOR SELECT TO PUBLIC
  USING (
    EXISTS (
      SELECT 1 FROM "UserToRole"
      WHERE  LOWER("User") = LOWER(current_setting('app.user_email', true))
        AND  "RoleName" = (SELECT id FROM "Role" WHERE "Name" = 'Finance')
    )
  );

-- =============================================================================
-- SECTION 7 — ACCRUALS
-- Architecture §8.2: "Finance: full (no HR/public write policies for
-- sensitive rows)".  No Account FKs → no leg-based filtering.
-- Default (no matching policy) = no access for non-Finance sessions.
-- These policies were entirely missing before this patch.
-- =============================================================================

DROP POLICY IF EXISTS policy_accruals_finance_select ON "Accruals";
DROP POLICY IF EXISTS policy_accruals_finance_insert ON "Accruals";
DROP POLICY IF EXISTS policy_accruals_finance_update ON "Accruals";
DROP POLICY IF EXISTS policy_accruals_finance_delete ON "Accruals";

CREATE POLICY policy_accruals_finance_select
  ON "Accruals"
  FOR SELECT TO PUBLIC
  USING (
    EXISTS (
      SELECT 1 FROM "UserToRole"
      WHERE  LOWER("User") = LOWER(current_setting('app.user_email', true))
        AND  "RoleName" = (SELECT id FROM "Role" WHERE "Name" = 'Finance')
    )
  );

CREATE POLICY policy_accruals_finance_insert
  ON "Accruals"
  FOR INSERT TO PUBLIC
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM "UserToRole"
      WHERE  LOWER("User") = LOWER(current_setting('app.user_email', true))
        AND  "RoleName" = (SELECT id FROM "Role" WHERE "Name" = 'Finance')
    )
  );

CREATE POLICY policy_accruals_finance_update
  ON "Accruals"
  FOR UPDATE TO PUBLIC
  USING (
    EXISTS (
      SELECT 1 FROM "UserToRole"
      WHERE  LOWER("User") = LOWER(current_setting('app.user_email', true))
        AND  "RoleName" = (SELECT id FROM "Role" WHERE "Name" = 'Finance')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM "UserToRole"
      WHERE  LOWER("User") = LOWER(current_setting('app.user_email', true))
        AND  "RoleName" = (SELECT id FROM "Role" WHERE "Name" = 'Finance')
    )
  );

CREATE POLICY policy_accruals_finance_delete
  ON "Accruals"
  FOR DELETE TO PUBLIC
  USING (
    EXISTS (
      SELECT 1 FROM "UserToRole"
      WHERE  LOWER("User") = LOWER(current_setting('app.user_email', true))
        AND  "RoleName" = (SELECT id FROM "Role" WHERE "Name" = 'Finance')
    )
  );

-- =============================================================================
-- SECTION 8 — JOURNAL
-- Architecture §8.2: "Finance: full".  No Account FKs.
-- These policies were entirely missing before this patch.
-- =============================================================================

DROP POLICY IF EXISTS policy_journal_finance_select ON "Journal";
DROP POLICY IF EXISTS policy_journal_finance_insert ON "Journal";
DROP POLICY IF EXISTS policy_journal_finance_update ON "Journal";
DROP POLICY IF EXISTS policy_journal_finance_delete ON "Journal";

CREATE POLICY policy_journal_finance_select
  ON "Journal"
  FOR SELECT TO PUBLIC
  USING (
    EXISTS (
      SELECT 1 FROM "UserToRole"
      WHERE  LOWER("User") = LOWER(current_setting('app.user_email', true))
        AND  "RoleName" = (SELECT id FROM "Role" WHERE "Name" = 'Finance')
    )
  );

CREATE POLICY policy_journal_finance_insert
  ON "Journal"
  FOR INSERT TO PUBLIC
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM "UserToRole"
      WHERE  LOWER("User") = LOWER(current_setting('app.user_email', true))
        AND  "RoleName" = (SELECT id FROM "Role" WHERE "Name" = 'Finance')
    )
  );

CREATE POLICY policy_journal_finance_update
  ON "Journal"
  FOR UPDATE TO PUBLIC
  USING (
    EXISTS (
      SELECT 1 FROM "UserToRole"
      WHERE  LOWER("User") = LOWER(current_setting('app.user_email', true))
        AND  "RoleName" = (SELECT id FROM "Role" WHERE "Name" = 'Finance')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM "UserToRole"
      WHERE  LOWER("User") = LOWER(current_setting('app.user_email', true))
        AND  "RoleName" = (SELECT id FROM "Role" WHERE "Name" = 'Finance')
    )
  );

CREATE POLICY policy_journal_finance_delete
  ON "Journal"
  FOR DELETE TO PUBLIC
  USING (
    EXISTS (
      SELECT 1 FROM "UserToRole"
      WHERE  LOWER("User") = LOWER(current_setting('app.user_email', true))
        AND  "RoleName" = (SELECT id FROM "Role" WHERE "Name" = 'Finance')
    )
  );

-- =============================================================================
-- VERIFICATION — run immediately after COMMIT to confirm patch applied
-- =============================================================================
-- SELECT tablename, policyname, cmd, roles, qual
-- FROM   pg_policies
-- WHERE  schemaname = 'BS4Prod09Feb2026'
--   AND  tablename IN (
--          'UserToRole','Role','RolePermissions','Account','LegalEntity',
--          'Transaction','Invoice','Allocation','BankStatement',
--          'Accruals','Journal'
--        )
-- ORDER BY tablename, policyname;
--
-- SELECT relname, relrowsecurity, relforcerowsecurity
-- FROM   pg_class c
-- JOIN   pg_namespace n ON n.oid = c.relnamespace
-- WHERE  n.nspname = 'BS4Prod09Feb2026'
--   AND  relkind   = 'r'
--   AND  relname   IN (
--          'Account','Accruals','Allocation','BankStatement',
--          'Employee','Invoice','Journal','LegalEntity',
--          'Role','RolePermissions','Transaction','UserToRole'
--        )
-- ORDER BY relname;

COMMIT;
