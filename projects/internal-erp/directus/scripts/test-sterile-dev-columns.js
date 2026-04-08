const { Client } = require('pg');

const DB_HOST = process.env.DB_HOST || '127.0.0.1';
const DB_PORT = process.env.DB_PORT || 5432;
const DB_USER = 'sterile_dev';
const DB_PASSWORD = 'l@QM0>6ZD>oj[J:a';
const DB_NAME = process.env.DB_NAME || 'bidstruct4';

async function testAccess() {
  const client = new Client({
    host: DB_HOST,
    port: DB_PORT,
    user: DB_USER,
    password: DB_PASSWORD,
    database: DB_NAME
  });

  try {
    await client.connect();
    
    // Check if the user sees it in information_schema.columns
    const res = await client.query(`
      SELECT column_name 
      FROM information_schema.columns 
      WHERE table_schema='BS4Prod09Feb2026' 
        AND table_name='LegalEntity_Summary'
    `);
    
    if (res.rows.length === 0) {
      console.log('❌ sterile_dev cannot see the columns in information_schema!');
    } else {
      console.log('✅ sterile_dev can see columns:', res.rows.map(r => r.column_name));
    }
  } catch (err) {
    console.error('Connection/Query error:', err);
  } finally {
    await client.end();
  }
}

testAccess();
