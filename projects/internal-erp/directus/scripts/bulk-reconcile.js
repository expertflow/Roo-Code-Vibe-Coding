const { Client } = require('pg');

// Use environment variables or fallback to dev defaults
const DB_HOST = process.env.DB_HOST || '213.55.244.201';
const DB_PORT = process.env.DB_PORT || 5432;
const DB_USER = process.env.DB_USER || 'bs4_dev';
const DB_PASSWORD = process.env.DB_PASSWORD || '3(Ga;lhU=:l-Fe_)';
const DB_NAME = process.env.DB_NAME || 'bidstruct4';
const SCHEMA = process.env.DB_SCHEMA || '"BS4Prod09Feb2026"';

async function bulkReconcile() {
  console.log('--- Starting Bulk Auto-Match Reconciliation ---');
  
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

    // Fetch all records
    const { rows } = await client.query(`
      SELECT id, "Description", "CorrespondantBank", "Project"
      FROM ${SCHEMA}."BankStatement"
    `);
    
    console.log(`Fetched ${rows.length} total BankStatement records.`);

    // Separate into sources and targets
    const sources = rows.filter(r => r.CorrespondantBank !== null && r.Project !== null);
    const targets = rows.filter(r => r.CorrespondantBank === null || r.Project === null);
    
    console.log(`Found ${sources.length} fully assigned records (Sources).`);
    console.log(`Found ${targets.length} records needing assignment (Targets).`);

    // Build prefix map
    const sourceMap = {};
    for (const s of sources) {
      if (!s.Description) continue;
      const prefix = s.Description.trim().substring(0, 20);
      if (!sourceMap[prefix]) {
        sourceMap[prefix] = {
          CorrespondantBank: s.CorrespondantBank,
          Project: s.Project
        };
      }
    }

    console.log(`Generated ${Object.keys(sourceMap).length} unique matching prefixes.`);

    // Find updates
    const updates = [];
    for (const t of targets) {
      if (!t.Description) continue;
      
      const prefix = t.Description.trim().substring(0, 20);
      const match = sourceMap[prefix];
      
      if (match) {
        updates.push({
          id: t.id,
          CorrespondantBank: t.CorrespondantBank || match.CorrespondantBank,
          Project: t.Project || match.Project
        });
      }
    }

    console.log(`Identified ${updates.length} records eligible for update.`);

    if (updates.length === 0) {
      console.log('No updates required. Exiting.');
      return;
    }

    // Execute updates transactionally
    console.log('Applying updates to database...');
    await client.query('BEGIN');

    for (const upd of updates) {
      await client.query(`
        UPDATE ${SCHEMA}."BankStatement"
        SET "CorrespondantBank" = $1, "Project" = $2
        WHERE id = $3
      `, [upd.CorrespondantBank, upd.Project, upd.id]);
    }

    await client.query('COMMIT');
    console.log(`✅ Successfully updated ${updates.length} records!`);

  } catch (err) {
    console.error('❌ Error during reconciliation:', err);
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

bulkReconcile();
