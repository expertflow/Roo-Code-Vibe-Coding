const { Client } = require('pg');

const DB_HOST = process.env.DB_HOST || '127.0.0.1';
const DB_PORT = process.env.DB_PORT || 5432;
const DB_USER = 'sterile_dev';
const DB_PASSWORD = 'l@QM0>6ZD>oj[J:a';
const DB_NAME = process.env.DB_NAME || 'bidstruct4';
const SCHEMA = '"BS4Prod09Feb2026"';

async function testSelectView() {
  const client = new Client({
    host: DB_HOST,
    port: DB_PORT,
    user: DB_USER,
    password: DB_PASSWORD,
    database: DB_NAME
  });

  try {
    await client.connect();
    const res = await client.query(`SELECT table_name FROM information_schema.tables WHERE table_schema = 'BS4Prod09Feb2026' AND table_name = 'LegalEntity_Summary'`);
    console.log('✅ sterile_dev information_schema check:', res.rows);
  } catch (err) {
    console.error('❌ Error selecting:', err);
  } finally {
    await client.end();
  }
}

testSelectView();
