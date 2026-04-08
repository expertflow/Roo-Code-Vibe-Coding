SET ROLE "BS4Prod09Feb2026";
ALTER TABLE "BS4Prod09Feb2026"."BankStatement" ADD COLUMN IF NOT EXISTS "Transaction" INTEGER;
ALTER TABLE "BS4Prod09Feb2026"."BankStatement" ADD CONSTRAINT "fk_bankstatement_transaction" FOREIGN KEY ("Transaction") REFERENCES "BS4Prod09Feb2026"."Transaction" ("id") ON DELETE SET NULL;
ALTER TABLE "BS4Prod09Feb2026"."Transaction" DROP COLUMN IF EXISTS "BankStatementId";
RESET ROLE;
