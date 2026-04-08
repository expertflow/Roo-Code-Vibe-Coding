const { Client } = require('pg');

const client = new Client({
    connectionString: 'postgresql://bs4_dev:06gttJSgZhbyhFkFb%23DO@127.0.0.1:5432/bidstruct4?sslmode=disable'
});

async function run() {
    await client.connect();
    console.log('Connected to DB');
    
    try {
        await client.query(`
        ALTER TABLE "BS4Prod09Feb2026"."BankStatement" 
        ADD COLUMN IF NOT EXISTS "MatchIndicator" text 
        GENERATED ALWAYS AS (
            CASE 
                WHEN "SuggestedTransaction" IS NOT NULL OR "SuggestedInvoice" IS NOT NULL THEN 'match' 
                ELSE NULL 
            END
        ) STORED;
        `);
        console.log('Column MatchIndicator added successfully');
    } catch(e) {
        console.error('Error:', e);
    }
    await client.end();
}

run();
