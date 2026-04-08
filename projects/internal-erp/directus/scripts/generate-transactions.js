const { Client } = require('pg');

// Configuration matching bulk-reconcile.js
const DB_HOST = process.env.DB_HOST || '213.55.244.201';
const DB_PORT = process.env.DB_PORT || 5432;
const DB_USER = process.env.DB_USER || 'bs4_dev';
const DB_PASSWORD = process.env.DB_PASSWORD || '3(Ga;lhU=:l-Fe_)';
const DB_NAME = process.env.DB_NAME || 'bidstruct4';
const SCHEMA = process.env.DB_SCHEMA || '"BS4Prod09Feb2026"';

async function generateTransactions() {
  console.log('--- Starting SQL-Direct Transaction Generation ---');
  
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
    console.log('Connected to Database successfully.');

    // 1. Fetch eligible BankStatement records
    // Requirement: CorrespondantBank IS NOT NULL, Project IS NOT NULL, Transaction IS NULL
    const { rows: statements } = await client.query(`
      SELECT bs.id, bs."Amount", bs."Date", bs."Description", bs."Project", 
             bs."Account", bs."CorrespondantBank", acc."Currency" as "CurrencyID"
      FROM ${SCHEMA}."BankStatement" bs
      JOIN ${SCHEMA}."Account" acc ON bs."Account" = acc.id
      WHERE bs."Transaction" IS NULL 
        AND bs."CorrespondantBank" IS NOT NULL
        AND bs."Project" IS NOT NULL
    `);
    
    console.log(`Fetched ${statements.length} eligible BankStatement records.`);

    if (statements.length === 0) {
      console.log('No records to process. Exiting.');
      return;
    }

    let createdTotal = 0;
    let linkedTotal = 0;

    await client.query('BEGIN');

    for (const bs of statements) {
      const amount = parseFloat(bs.Amount);
      const absAmt = Math.abs(amount);
      const origin = amount > 0 ? bs.Account : bs.CorrespondantBank;
      const dest = amount > 0 ? bs.CorrespondantBank : bs.Account;
      const date = bs.Date;

      // Ensure both OriginAccount and DestinationAccount are non-null
      if (!origin || !dest) {
          console.log(`Skipping BS ID ${bs.id}: Missing OriginAccount or DestinationAccount`);
          continue;
      }

      // 2. Search for existing matching Transaction
      // Criteria: Amount +/- 5%, Date +/- 3 days, Project match, Accounts match
      const { rows: matches } = await client.query(`
        SELECT id FROM ${SCHEMA}."Transaction"
        WHERE "Amount" BETWEEN $1 AND $2
          AND "Date" BETWEEN ($3::date - interval '3 days') AND ($3::date + interval '3 days')
          AND "OriginAccount" = $4
          AND "DestinationAccount" = $5
          AND "Project" = $6
        LIMIT 1
      `, [absAmt * 0.95, absAmt * 1.05, date, origin, dest, bs.Project]);

      let tId;
      if (matches.length > 0) {
        tId = matches[0].id;
        linkedTotal++;
      } else {
        // 3. Create new Transaction
        const { rows: newT } = await client.query(`
          INSERT INTO ${SCHEMA}."Transaction" 
          ("Amount", "Date", "Description", "Project", "OriginAccount", "DestinationAccount", "Currency")
          VALUES ($1, $2, $3, $4, $5, $6, $7)
          RETURNING id
        `, [absAmt, date, bs.Description, bs.Project, origin, dest, bs.CurrencyID]);
        tId = newT[0].id;
        createdTotal++;
      }

      // 4. Link back to BankStatement
      await client.query(`
        UPDATE ${SCHEMA}."BankStatement" 
        SET "Transaction" = $1 
        WHERE id = $2
      `, [tId, bs.id]);
    }

    await client.query('COMMIT');
    console.log(`✅ Processed ${statements.length} statements: Created ${createdTotal}, Linked ${linkedTotal}.`);

  } catch (err) {
    console.error('❌ Error during transaction generation:', err);
    try {
      await client.query('ROLLBACK');
      console.log('Transaction rolled back.');
    } catch (rollbackErr) {
      console.error('Error rolling back:', rollbackErr);
    }
  } finally {
    await client.end();
    console.log('Database connection closed.');
  }
}

generateTransactions();
