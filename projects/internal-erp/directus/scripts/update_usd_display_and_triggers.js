// update_usd_display_and_triggers.js
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

    // 1. Update Directus display parameters to remove decimals
    const displayOptions = JSON.stringify({ format: true, maximumFractionDigits: 0, minimumFractionDigits: 0 });
    
    await client.query(`
      UPDATE directus.directus_fields
      SET display = 'formatted-value', display_options = $1
      WHERE collection IN ('Transaction', 'Invoice', 'BankStatement')
        AND field IN ('Amount', 'USDAmount');
    `, [displayOptions]);
    
    console.log('Updated Directus field display options successfully');

    // 2. Create Triggers
    const createTxTrigger = `
      CREATE OR REPLACE FUNCTION update_transaction_usd_amount() RETURNS TRIGGER AS $$
      BEGIN
        IF NEW."Amount" IS NOT NULL AND NEW."Currency" IS NOT NULL AND NEW."Date" IS NOT NULL THEN
          NEW."USDAmount" := NEW."Amount" * (
            SELECT "RateToUSD"
            FROM "BS4Prod09Feb2026"."CurrencyExchange"
            WHERE "Currency" = NEW."Currency" AND "Date" <= NEW."Date"
            ORDER BY "Date" DESC LIMIT 1
          );
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;

      DROP TRIGGER IF EXISTS trigger_transaction_usd_amount ON "BS4Prod09Feb2026"."Transaction";
      CREATE TRIGGER trigger_transaction_usd_amount
      BEFORE INSERT OR UPDATE OF "Amount", "Currency", "Date"
      ON "BS4Prod09Feb2026"."Transaction"
      FOR EACH ROW
      EXECUTE FUNCTION update_transaction_usd_amount();
    `;
    await client.query(createTxTrigger);
    console.log('Created Transaction trigger');

    const createInvTrigger = `
      CREATE OR REPLACE FUNCTION update_invoice_usd_amount() RETURNS TRIGGER AS $$
      BEGIN
        IF NEW."Amount" IS NOT NULL AND NEW."Currency" IS NOT NULL AND COALESCE(NEW."SentDate", NEW."DueDate", NEW."PaymentDate") IS NOT NULL THEN
          NEW."USDAmount" := NEW."Amount" * (
            SELECT "RateToUSD"
            FROM "BS4Prod09Feb2026"."CurrencyExchange"
            WHERE "Currency" = NEW."Currency" AND "Date" <= COALESCE(NEW."SentDate", NEW."DueDate", NEW."PaymentDate")
            ORDER BY "Date" DESC LIMIT 1
          );
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;

      DROP TRIGGER IF EXISTS trigger_invoice_usd_amount ON "BS4Prod09Feb2026"."Invoice";
      CREATE TRIGGER trigger_invoice_usd_amount
      BEFORE INSERT OR UPDATE OF "Amount", "Currency", "SentDate", "DueDate", "PaymentDate"
      ON "BS4Prod09Feb2026"."Invoice"
      FOR EACH ROW
      EXECUTE FUNCTION update_invoice_usd_amount();
    `;
    await client.query(createInvTrigger);
    console.log('Created Invoice trigger');

    const createBSTrigger = `
      CREATE OR REPLACE FUNCTION update_bankstatement_usd_amount() RETURNS TRIGGER AS $$
      DECLARE
        v_currency INT;
      BEGIN
        IF NEW."Amount" IS NOT NULL AND NEW."Account" IS NOT NULL AND NEW."Date" IS NOT NULL THEN
           SELECT "Currency" INTO v_currency FROM "BS4Prod09Feb2026"."Account" WHERE id = NEW."Account";
          IF v_currency IS NOT NULL THEN
            NEW."USDAmount" := NEW."Amount" * (
              SELECT "RateToUSD"
              FROM "BS4Prod09Feb2026"."CurrencyExchange"
              WHERE "Currency" = v_currency AND "Date" <= NEW."Date"
              ORDER BY "Date" DESC LIMIT 1
            );
          END IF;
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;

      DROP TRIGGER IF EXISTS trigger_bankstatement_usd_amount ON "BS4Prod09Feb2026"."BankStatement";
      CREATE TRIGGER trigger_bankstatement_usd_amount
      BEFORE INSERT OR UPDATE OF "Amount", "Account", "Date"
      ON "BS4Prod09Feb2026"."BankStatement"
      FOR EACH ROW
      EXECUTE FUNCTION update_bankstatement_usd_amount();
    `;
    await client.query(createBSTrigger);
    console.log('Created BankStatement trigger');

  } catch (err) {
    console.error('Error:', err);
  } finally {
    await client.end();
  }
}

run();
