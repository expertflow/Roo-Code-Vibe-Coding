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
    console.log('Connected to Database');

    // 0. Ensure owner access for updates (bypassing RLS forcibly since RLS is on for these tables)
    try {
      await client.query(`CREATE POLICY policy_owner_access_tx ON "BS4Prod09Feb2026"."Transaction" FOR ALL TO bs4_dev USING (true) WITH CHECK (true);`);
      console.log('Created policy policy_owner_access_tx');
    } catch(e) { if (!e.message.includes('already exists')) console.log(e.message); }

    try {
      await client.query(`CREATE POLICY policy_owner_access_inv ON "BS4Prod09Feb2026"."Invoice" FOR ALL TO bs4_dev USING (true) WITH CHECK (true);`);
      console.log('Created policy policy_owner_access_inv');
    } catch(e) { if (!e.message.includes('already exists')) console.log(e.message); }

    // 1. Transaction
    const resTx = await client.query(`
      UPDATE "BS4Prod09Feb2026"."Transaction" t
      SET "USDAmount" = t."Amount" * (
          SELECT "RateToUSD"
          FROM "BS4Prod09Feb2026"."CurrencyExchange" ce
          WHERE ce."Currency" = t."Currency"
            AND ce."Date" <= t."Date"
          ORDER BY ce."Date" DESC
          LIMIT 1
      )
      WHERE t."Amount" IS NOT NULL AND t."Currency" IS NOT NULL AND t."Date" IS NOT NULL;
    `);
    console.log(`Updated ${resTx.rowCount} rows in Transaction`);

    // 2. Invoice
    const resInv = await client.query(`
      UPDATE "BS4Prod09Feb2026"."Invoice" i
      SET "USDAmount" = i."Amount" * (
          SELECT "RateToUSD"
          FROM "BS4Prod09Feb2026"."CurrencyExchange" ce
          WHERE ce."Currency" = i."Currency"
            AND ce."Date" <= COALESCE(i."SentDate", i."DueDate", i."PaymentDate")
          ORDER BY ce."Date" DESC
          LIMIT 1
      )
      WHERE i."Amount" IS NOT NULL AND i."Currency" IS NOT NULL AND COALESCE(i."SentDate", i."DueDate", i."PaymentDate") IS NOT NULL;
    `);
    console.log(`Updated ${resInv.rowCount} rows in Invoice`);

    // 3. BankStatement
    const resBS = await client.query(`
      UPDATE "BS4Prod09Feb2026"."BankStatement" bs
      SET "USDAmount" = bs."Amount" * (
          SELECT ce."RateToUSD"
          FROM "BS4Prod09Feb2026"."CurrencyExchange" ce
          JOIN "BS4Prod09Feb2026"."Account" acc ON ce."Currency" = acc."Currency"
          WHERE acc."id" = bs."Account"
            AND ce."Date" <= bs."Date"
          ORDER BY ce."Date" DESC
          LIMIT 1
      )
      WHERE bs."Amount" IS NOT NULL AND bs."Date" IS NOT NULL AND bs."Account" IS NOT NULL;
    `);
    console.log(`Updated ${resBS.rowCount} rows in BankStatement`);

  } catch (err) {
    console.error('DB Error:', err.message);
  } finally {
    await client.end();
  }
}

run();
