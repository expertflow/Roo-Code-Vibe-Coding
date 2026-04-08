const { Client } = require('pg');

const client = new Client({
  host: '127.0.0.1',
  port: 5432,
  user: 'bs4_dev',
  password: '3(Ga;lhU=:l-Fe_)',
  database: 'bidstruct4',
  ssl: false
});

async function run() {
  try {
    await client.connect();
    
    await client.query(`ALTER TABLE "BS4Prod09Feb2026"."Transaction" ADD COLUMN IF NOT EXISTS "USDAmount" numeric(18,5) NULL;`);
    console.log('Transaction column added or already exists.');
    
    await client.query(`ALTER TABLE "BS4Prod09Feb2026"."Invoice" ADD COLUMN IF NOT EXISTS "USDAmount" numeric(18,5) NULL;`);
    console.log('Invoice column added or already exists.');
    
    await client.query(`ALTER TABLE "BS4Prod09Feb2026"."BankStatement" ADD COLUMN IF NOT EXISTS "USDAmount" numeric(18,5) NULL;`);
    console.log('BankStatement column added or already exists.');
    
  } catch (err) {
    console.error('DB Error:', err.message);
  } finally {
    await client.end();
  }
}

run();
