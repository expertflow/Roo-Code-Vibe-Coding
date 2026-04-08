-- Migration: Convert LegalEntity.Type from text to ENUM
-- Target schema: BS4Prod09Feb2026
-- Existing values: Client, Employee, Executive, Internal, Partner, Supplier
-- Added values: Bank, Other

BEGIN;

-- Step 1: Create the ENUM type
CREATE TYPE "BS4Prod09Feb2026".legal_entity_type AS ENUM (
    'Client',
    'Employee',
    'Executive',
    'Internal',
    'Partner',
    'Supplier',
    'Bank',
    'Other'
);

-- Step 2: Alter the column to use the ENUM type
ALTER TABLE "BS4Prod09Feb2026"."LegalEntity"
    ALTER COLUMN "Type" TYPE "BS4Prod09Feb2026".legal_entity_type
    USING "Type"::"BS4Prod09Feb2026".legal_entity_type;

COMMIT;
