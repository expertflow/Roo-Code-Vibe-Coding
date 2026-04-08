const { Client } = require('pg');

const DB_HOST = process.env.DB_HOST || '127.0.0.1';
const DB_PORT = process.env.DB_PORT || 5432;
const DB_USER = 'bs4_dev'; // use owner
const DB_PASSWORD = '3(Ga;lhU=:l-Fe_)';
const DB_NAME = process.env.DB_NAME || 'bidstruct4';

async function forceTrackView() {
  const client = new Client({
    host: DB_HOST,
    port: DB_PORT,
    user: DB_USER,
    password: DB_PASSWORD,
    database: DB_NAME
  });

  try {
    await client.connect();
    
    const trackCol = `
      INSERT INTO directus.directus_collections 
        (collection, icon, note, hidden, singleton) 
      VALUES 
        ('LegalEntity_Summary', 'summarize', 'Summary View showing Legal Entities with total Invoice and Transaction sums.', false, false)
      ON CONFLICT (collection) DO NOTHING;
    `;
    await client.query(trackCol);

    const fieldsToTrack = [
      { field: 'id', interface: 'input' },
      { field: 'Name', interface: 'input' },
      { field: 'TotalInvoicesUSD', interface: 'input-decimal' },
      { field: 'TotalTransactionsUSD', interface: 'input-decimal' }
    ];

    for (const f of fieldsToTrack) {
      const res = await client.query('SELECT id FROM directus.directus_fields WHERE collection = $1 AND field = $2', ['LegalEntity_Summary', f.field]);
      if (res.rowCount === 0) {
        await client.query(
          `INSERT INTO directus.directus_fields (collection, field, interface, readonly, hidden) VALUES ($1, $2, $3, true, false)`,
          ['LegalEntity_Summary', f.field, f.interface]
        );
      }
    }

    console.log('✅ Values inserted into directus_collections and directus_fields.');

  } catch (err) {
    console.error('❌ Error executing:', err);
  } finally {
    await client.end();
  }
}

forceTrackView();
