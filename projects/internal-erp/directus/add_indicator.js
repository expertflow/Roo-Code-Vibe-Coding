const { Client } = require('pg');

const client = new Client({
    connectionString: 'postgres://bs4_dev:3(Ga;lhU=:l-Fe_)@213.55.244.201:5432/bidstruct4?sslmode=require'
});

async function run() {
    await client.connect();
    console.log('Connected to DB');
    
    try {
        await client.query(`
        ALTER TABLE "BS4Prod09Feb2026"."BankStatement" 
        ADD COLUMN "MatchIndicator" text 
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
