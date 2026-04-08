-- Canonical rate date for CurrencyExchange (re-added after A12 dropped redundant Key/Month/Year/Day).
-- Schema: adjust if your ERP namespace differs.
SET search_path TO "BS4Prod09Feb2026", public;

ALTER TABLE "CurrencyExchange" ADD COLUMN IF NOT EXISTS "Day" date NULL;

COMMENT ON COLUMN "CurrencyExchange"."Day" IS 'Effective date for the exchange rate (canonical; replaces redundant Key/Month/Year).';
