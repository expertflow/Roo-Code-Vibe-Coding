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
    
    let { rows } = await client.query(`
      SELECT tablename, tableowner 
      FROM pg_tables 
      WHERE tablename IN ('Transaction', 'Invoice', 'BankStatement') 
      AND schemaname = 'BS4Prod09Feb2026'
    `);
    console.log('Owners:', rows);
    
    // Check directus user
    let res = await client.query(`SELECT current_user`);
    console.log('Current user:', res.rows[0]);

  } catch (err) {
    console.error('DB Error:', err.message);
  } finally {
    await client.end();
  }
}

run();
