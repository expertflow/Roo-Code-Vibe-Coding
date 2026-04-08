SET ROLE "BS4Prod09Feb2026";
ALTER TABLE "BS4Prod09Feb2026"."BankStatement" 
ADD COLUMN IF NOT EXISTS "SuggestedTransaction" INTEGER,
ADD COLUMN IF NOT EXISTS "SuggestedInvoice" INTEGER;

DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_bs_suggested_transaction') THEN
        ALTER TABLE "BS4Prod09Feb2026"."BankStatement"
        ADD CONSTRAINT "fk_bs_suggested_transaction" FOREIGN KEY ("SuggestedTransaction") REFERENCES "BS4Prod09Feb2026"."Transaction" (id) ON DELETE SET NULL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_bs_suggested_invoice') THEN
        ALTER TABLE "BS4Prod09Feb2026"."BankStatement"
        ADD CONSTRAINT "fk_bs_suggested_invoice" FOREIGN KEY ("SuggestedInvoice") REFERENCES "BS4Prod09Feb2026"."Invoice" (id) ON DELETE SET NULL;
    END IF;
END $$;
RESET ROLE;

-- Register metadata in directus schema
INSERT INTO "directus"."directus_fields" 
(collection, field, special, interface, display, display_options, readonly, hidden, width)
SELECT 'BankStatement', 'SuggestedTransaction', 'm2o', 'select-dropdown-m2o', 'related-values', '{"template": "{{Description}} ({{Amount}}) - {{Date}}"}', true, false, 'half'
WHERE NOT EXISTS (SELECT 1 FROM "directus"."directus_fields" WHERE collection = 'BankStatement' AND field = 'SuggestedTransaction');

INSERT INTO "directus"."directus_fields" 
(collection, field, special, interface, display, display_options, readonly, hidden, width)
SELECT 'BankStatement', 'SuggestedInvoice', 'm2o', 'select-dropdown-m2o', 'related-values', '{"template": "{{Description}} ({{Amount}}) - {{Date}}"}', true, false, 'half'
WHERE NOT EXISTS (SELECT 1 FROM "directus"."directus_fields" WHERE collection = 'BankStatement' AND field = 'SuggestedInvoice');

INSERT INTO "directus"."directus_relations" 
(many_collection, many_field, one_collection, one_field, one_deselect_action)
SELECT 'BankStatement', 'SuggestedTransaction', 'Transaction', 'SuggestingBankStatements', 'nullify'
WHERE NOT EXISTS (SELECT 1 FROM "directus"."directus_relations" WHERE many_collection = 'BankStatement' AND many_field = 'SuggestedTransaction');

INSERT INTO "directus"."directus_relations" 
(many_collection, many_field, one_collection, one_field, one_deselect_action)
SELECT 'BankStatement', 'SuggestedInvoice', 'Invoice', 'SuggestingBankStatements', 'nullify'
WHERE NOT EXISTS (SELECT 1 FROM "directus"."directus_relations" WHERE many_collection = 'BankStatement' AND many_field = 'SuggestedInvoice');
