-- Run this script using your PostgreSQL client (e.g. pgAdmin, DBeaver) as the user "bs4_dev" or table owner.
-- This applies the database schema and logic required for the "USD Amount" field in Directus.

-- 1. Add the column to the active schema (e.g., "BS4Prod09Feb2026", adjust if using another active schema in the tool)
ALTER TABLE "Transaction"
ADD COLUMN IF NOT EXISTS "USDAmount" numeric(18, 5) NULL;

-- 2. Create the Trigger Function
CREATE OR REPLACE FUNCTION update_transaction_usd_amount()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    target_rate numeric(18, 10);
BEGIN
    -- If no currency or amount, skip calculation
    IF NEW."Currency" IS NULL OR NEW."Amount" IS NULL THEN
        NEW."USDAmount" := NULL;
        RETURN NEW;
    END IF;

    -- Lookup closest exchange rate equal to or before the transaction date
    SELECT "RateToUSD" INTO target_rate
    FROM "CurrencyExchange"
    WHERE "Currency" = NEW."Currency"
      AND "Date" <= NEW."Date"
    ORDER BY "Date" DESC 
    LIMIT 1;

    -- Calculate the USD Amount if a rate was found
    IF FOUND AND target_rate IS NOT NULL THEN
        NEW."USDAmount" := NEW."Amount" * target_rate;
    ELSE
        NEW."USDAmount" := NULL;
    END IF;

    RETURN NEW;
END;
$$;

-- 3. Bind the trigger to the Transaction table
DROP TRIGGER IF EXISTS trigger_calculate_usd_amount ON "Transaction";
CREATE TRIGGER trigger_calculate_usd_amount
BEFORE INSERT OR UPDATE OF "Amount", "Currency", "Date"
ON "Transaction"
FOR EACH ROW
EXECUTE FUNCTION update_transaction_usd_amount();

-- 4. Automatically retro-fill existing records (Optional but recommended)
UPDATE "Transaction"
SET "USDAmount" = "Amount" * (
    SELECT "RateToUSD"
    FROM "CurrencyExchange"
    WHERE "CurrencyExchange"."Currency" = "Transaction"."Currency"
      AND "CurrencyExchange"."Date" <= "Transaction"."Date"
    ORDER BY "CurrencyExchange"."Date" DESC 
    LIMIT 1
);
