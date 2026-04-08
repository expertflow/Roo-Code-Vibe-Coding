-- Add field metadata for BankStatement.Transaction (M2O)
INSERT INTO "directus"."directus_fields" 
(collection, field, special, interface, display, display_options, readonly, hidden, width, required)
VALUES 
('BankStatement', 'Transaction', 'm2o', 'select-dropdown-m2o', 'related-values', '{"template": "{{Description}} ({{Amount}}) - {{Date}}"}', false, false, 'half', false);

-- Add relation metadata
INSERT INTO "directus"."directus_relations" 
(many_collection, many_field, one_collection, one_field, one_deselect_action)
VALUES 
('BankStatement', 'Transaction', 'Transaction', 'BankStatements', 'nullify');
