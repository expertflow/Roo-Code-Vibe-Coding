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
    
    const collections = ['Transaction', 'Invoice', 'BankStatement'];
    const fieldParams = {
      interface: 'input-decimal',
      readonly: true,
      hidden: false,
      translations: JSON.stringify([{"language": "en-US", "translation": "USD Amount"}]),
      note: 'Amount converted to USD based on the closest CurrencyExchange date.'
    };

    let { rows } = await client.query('SELECT COALESCE(MAX(id), 0) as max_id FROM directus.directus_fields');
    let nextId = rows[0].max_id + 1;

    for (const collection of collections) {
      // Check if it already exists
      const { rowCount } = await client.query(`
        SELECT 1 FROM directus.directus_fields 
        WHERE collection = $1 AND field = $2
      `, [collection, 'USDAmount']);

      if (rowCount === 0) {
        await client.query(`
          INSERT INTO directus.directus_fields 
          (id, collection, field, interface, readonly, hidden, translations, note)
          VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        `, [
          nextId++,
          collection, 
          'USDAmount', 
          fieldParams.interface, 
          fieldParams.readonly, 
          fieldParams.hidden, 
          fieldParams.translations, 
          fieldParams.note
        ]);
        console.log(`Configured directus_field for ${collection}.USDAmount`);
      } else {
        console.log(`directus_field configuration already exists for ${collection}.USDAmount`);
      }
    }
    
    // Also update the sequence for future inserts just in case
    await client.query(`SELECT setval('directus.directus_fields_id_seq', $1)`, [nextId]);
    console.log('Updated directus_fields sequence to align.');

  } catch (err) {
    console.error('DB Error:', err.message);
  } finally {
    await client.end();
  }
}

run();
