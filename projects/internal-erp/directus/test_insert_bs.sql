INSERT INTO "BankStatement" ("Account", "Date", "Amount", "Description", "BankTransactionID") VALUES (7, '2026-03-10', -40000, 'Test', 'TEST1234') RETURNING "id";
