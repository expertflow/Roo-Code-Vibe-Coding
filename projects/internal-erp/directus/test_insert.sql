INSERT INTO "directus_activity" ("action", "collection", "ip", "item", "origin", "timestamp", "user", "user_agent")
VALUES ('create', 'BankStatement', '127.0.0.1', '1', 'api', now(), null, 'test') 
RETURNING "id";
