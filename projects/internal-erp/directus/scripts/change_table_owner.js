const { Client } = require('pg');

async function makeOwner() {
  const client = new Client({
    host: '127.0.0.1',
    port: 5432,
    user: 'bs4_dev',
    password: '3(Ga;lhU=:l-Fe_)',
    database: 'bidstruct4',
    ssl: false
  });

  try {
    await client.connect();
    console.log('Connected to DB');

    const queries = [
      `ALTER TABLE "BS4Prod09Feb2026"."Transaction" OWNER TO sterile_dev;`,
      `ALTER TABLE "BS4Prod09Feb2026"."Invoice" OWNER TO sterile_dev;`,
      `ALTER TABLE "BS4Prod09Feb2026"."BankStatement" OWNER TO sterile_dev;`
    ];

    for (const q of queries) {
      console.log('Executing:', q);
      await client.query(q);
    }

    console.log('Successfully updated table owners to sterile_dev');
  } catch (error) {
    console.error('Failed to update owner:', error);
  } finally {
    await client.end();
  }
}

makeOwner();
