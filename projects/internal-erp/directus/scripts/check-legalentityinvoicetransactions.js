const { Client } = require('pg');

const DB_HOST = process.env.DB_HOST || '127.0.0.1';
const DB_PORT = process.env.DB_PORT || 5432;
const DB_USER = 'bs4_dev'; // use owner
const DB_PASSWORD = '3(Ga;lhU=:l-Fe_)';
const DB_NAME = process.env.DB_NAME || 'bidstruct4';

async function check() {
  const client = new Client({
    host: DB_HOST,
    port: DB_PORT,
    user: DB_USER,
    password: DB_PASSWORD,
    database: DB_NAME,
    ssl: { rejectUnauthorized: false }
  });

  try {
    await client.connect();
    
    console.log('--- directus_collections ---');
    const colRes = await client.query("SELECT * FROM directus.directus_collections WHERE collection = 'LegalEntityInvoiceTransactions'");
    console.log(colRes.rows);

    console.log('\n--- directus_fields ---');
    const fldRes = await client.query("SELECT * FROM directus.directus_fields WHERE collection = 'LegalEntityInvoiceTransactions'");
    console.log(fldRes.rows);

    console.log('\n--- information_schema.tables ---');
    const tblRes = await client.query("SELECT table_schema, table_name, table_type FROM information_schema.tables WHERE table_name = 'LegalEntityInvoiceTransactions'");
    console.log(tblRes.rows);

    console.log('\n--- information_schema.columns ---');
    const colSchRes = await client.query("SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'LegalEntityInvoiceTransactions'");
    console.log(colSchRes.rows);

  } catch (err) {
    console.error('❌ Error executing:', err);
  } finally {
    await client.end();
  }
}

check();
