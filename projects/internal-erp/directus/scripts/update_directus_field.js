const { Client } = require('pg');

async function main() {
  const client = new Client({
    host: '127.0.0.1',
    port: 5432,
    database: 'bidstruct4',
    user: 'bs4_dev',
    password: '3(Ga;lhU=:l-Fe_)',
  });

  await client.connect();
  console.log('Connected.');

  const options = JSON.stringify({
    choices: [
      { text: "Client", value: "Client" },
      { text: "Employee", value: "Employee" },
      { text: "Executive", value: "Executive" },
      { text: "Internal", value: "Internal" },
      { text: "Partner", value: "Partner" },
      { text: "Supplier", value: "Supplier" },
      { text: "Bank", value: "Bank" },
      { text: "Other", value: "Other" },
    ],
  });

  const displayOptions = JSON.stringify({
    showAsDot: false,
    choices: [
      { background: "#2ECDA7", foreground: "#FFFFFF", text: "Client", value: "Client" },
      { background: "var(--theme--primary)", foreground: "#FFFFFF", text: "Employee", value: "Employee" },
      { background: "#6644FF", foreground: "#FFFFFF", text: "Executive", value: "Executive" },
      { background: "#FFA439", foreground: "#FFFFFF", text: "Internal", value: "Internal" },
      { background: "#FF6B6B", foreground: "#FFFFFF", text: "Partner", value: "Partner" },
      { background: "#E040FB", foreground: "#FFFFFF", text: "Supplier", value: "Supplier" },
      { background: "#42A5F5", foreground: "#FFFFFF", text: "Bank", value: "Bank" },
      { background: "var(--theme--background-normal)", foreground: "var(--theme--foreground)", text: "Other", value: "Other" },
    ],
  });

  try {
    const res = await client.query(`
      UPDATE directus.directus_fields
      SET 
        interface = 'select-dropdown',
        options = $1::json,
        display = 'labels',
        display_options = $2::json,
        required = true
      WHERE collection = 'LegalEntity' AND field = 'Type'
    `, [options, displayOptions]);

    console.log(`Updated ${res.rowCount} row(s).`);

    // Verify
    const verify = await client.query(`
      SELECT interface, display, required FROM directus.directus_fields 
      WHERE collection = 'LegalEntity' AND field = 'Type'
    `);
    console.log('Verification:', verify.rows[0]);
    console.log('\nDone! Refresh Directus to see the changes.');
  } catch (err) {
    console.error('ERROR:', err.message);
    process.exit(1);
  } finally {
    await client.end();
  }
}

main();
