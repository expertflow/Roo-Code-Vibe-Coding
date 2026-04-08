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

  const SCHEMA = 'BS4Prod09Feb2026';

  try {
    // TypeEnum already has data from previous run. Check state first.
    const colCheck = await client.query(`
      SELECT column_name FROM information_schema.columns 
      WHERE table_schema = $1 AND table_name = 'LegalEntity' 
      AND column_name IN ('Type', 'TypeEnum')
    `, [SCHEMA]);
    console.log('Existing columns:', colCheck.rows.map(r => r.column_name));

    // Find what depends on the old Type column
    console.log('\nChecking dependencies on old Type column...');
    const deps = await client.query(`
      SELECT pg_describe_object(classid, objid, objsubid) as dependent_object
      FROM pg_depend d
      JOIN pg_class c ON d.refobjid = c.oid 
      JOIN pg_namespace n ON c.relnamespace = n.oid
      JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum = d.refobjsubid
      WHERE c.relname = 'LegalEntity' 
        AND n.nspname = $1 
        AND a.attname = 'Type'
        AND d.deptype = 'n'
    `, [SCHEMA]);
    console.log('Dependencies:', deps.rows);

    // Drop old column with CASCADE
    console.log('\nDropping old Type column with CASCADE...');
    await client.query(`ALTER TABLE "${SCHEMA}"."LegalEntity" DROP COLUMN "Type" CASCADE`);
    console.log('  Old column dropped.');

    console.log('Renaming TypeEnum to Type...');
    await client.query(`ALTER TABLE "${SCHEMA}"."LegalEntity" RENAME COLUMN "TypeEnum" TO "Type"`);
    console.log('  Renamed.');

    // Re-enable RLS and recreate policies
    console.log('Re-enabling RLS...');
    await client.query(`ALTER TABLE "${SCHEMA}"."LegalEntity" ENABLE ROW LEVEL SECURITY`);
    await client.query(`ALTER TABLE "${SCHEMA}"."LegalEntity" FORCE ROW LEVEL SECURITY`);
    
    // Check if policies already exist (from partial runs)
    const existingPols = await client.query(`
      SELECT p.polname FROM pg_policy p 
      JOIN pg_class c ON p.polrelid = c.oid 
      JOIN pg_namespace n ON c.relnamespace = n.oid 
      WHERE c.relname = 'LegalEntity' AND n.nspname = $1
    `, [SCHEMA]);
    const existing = existingPols.rows.map(r => r.polname);
    console.log('Existing policies:', existing);

    const policiesToCreate = [
      { name: 'policy_owner_access_legalentity', sql: `CREATE POLICY "policy_owner_access_legalentity" ON "${SCHEMA}"."LegalEntity" FOR ALL TO bs4_dev USING (true) WITH CHECK (true)` },
      { name: 'policy_legalentity_sterile_select', sql: `CREATE POLICY "policy_legalentity_sterile_select" ON "${SCHEMA}"."LegalEntity" FOR SELECT TO sterile_dev USING (true)` },
      { name: 'policy_legalentity_open_select', sql: `CREATE POLICY "policy_legalentity_open_select" ON "${SCHEMA}"."LegalEntity" FOR SELECT TO public USING (true)` },
      { name: 'policy_legalentity_auth_delete', sql: `CREATE POLICY "policy_legalentity_auth_delete" ON "${SCHEMA}"."LegalEntity" FOR DELETE TO public USING (auth_crud('LegalEntity', 'DELETE'))` },
      { name: 'policy_legalentity_auth_insert', sql: `CREATE POLICY "policy_legalentity_auth_insert" ON "${SCHEMA}"."LegalEntity" FOR INSERT TO public WITH CHECK (auth_crud('LegalEntity', 'INSERT'))` },
      { name: 'policy_legalentity_auth_update', sql: `CREATE POLICY "policy_legalentity_auth_update" ON "${SCHEMA}"."LegalEntity" FOR UPDATE TO public USING (auth_crud('LegalEntity', 'UPDATE'))` },
    ];

    for (const pol of policiesToCreate) {
      if (!existing.includes(pol.name)) {
        await client.query(pol.sql);
        console.log(`  Created: ${pol.name}`);
      } else {
        console.log(`  Skipped (exists): ${pol.name}`);
      }
    }

    // Verify
    const verify = await client.query(`SELECT DISTINCT "Type" FROM "${SCHEMA}"."LegalEntity" ORDER BY "Type"`);
    console.log('\nEnum values in use:', verify.rows.map(r => r.Type));
    
    const colInfo = await client.query(`
      SELECT data_type, udt_name FROM information_schema.columns 
      WHERE table_schema = $1 AND table_name = 'LegalEntity' AND column_name = 'Type'
    `, [SCHEMA]);
    console.log('Column info:', colInfo.rows[0]);

    console.log('\nDONE!');
  } catch (err) {
    console.error('ERROR:', err.message);
    process.exit(1);
  } finally {
    await client.end();
  }
}

main();
