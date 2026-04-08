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

  const S = 'BS4Prod09Feb2026';

  // Helper: HR role check subquery
  const hrCheck = `(CURRENT_USER = 'looker_hr_svc'::name OR EXISTS (
    SELECT 1 FROM "${S}"."UserToRole"
    WHERE lower("UserToRole"."User") = lower(current_setting('app.user_email', true))
    AND "UserToRole"."RoleName" = (SELECT "Role".id FROM "${S}"."Role" WHERE "Role"."Name" = 'HR')
  ))`;

  // Helper: Employee type via Account->LegalEntity JOIN
  const isEmployeeVia = (table, accountCol) => `EXISTS (
    SELECT 1 FROM "${S}"."Account" a 
    JOIN "${S}"."LegalEntity" l ON a."LegalEntity" = l.id
    WHERE a.id = "${table}"."${accountCol}" AND l."Type" = 'Employee'
  )`;

  // Helper: Sterile/public exclusion (Employee or Executive)
  const excludeHRVia = (table, accountCol) => `NOT EXISTS (
    SELECT 1 FROM "${S}"."Account" a 
    JOIN "${S}"."LegalEntity" l ON a."LegalEntity" = l.id
    WHERE a.id = "${table}"."${accountCol}" AND l."Type" IN ('Employee', 'Executive')
  )`;

  const policies = [
    // --- Transaction ---
    {
      name: 'policy_transaction_sterile_select',
      table: 'Transaction',
      cmd: 'SELECT',
      roles: 'sterile_dev',
      using: excludeHRVia('Transaction', 'DestinationAccount'),
    },
    {
      name: 'policy_transaction_public_read',
      table: 'Transaction',
      cmd: 'SELECT',
      roles: 'public',
      using: excludeHRVia('Transaction', 'DestinationAccount'),
    },
    {
      name: 'policy_transaction_hr_select',
      table: 'Transaction',
      cmd: 'SELECT',
      roles: 'public',
      using: `${hrCheck} AND (${isEmployeeVia('Transaction', 'DestinationAccount')} OR ${isEmployeeVia('Transaction', 'OriginAccount')})`,
    },

    // --- Invoice ---
    {
      name: 'policy_invoice_sterile_select',
      table: 'Invoice',
      cmd: 'SELECT',
      roles: 'sterile_dev',
      using: excludeHRVia('Invoice', 'DestinationAccount'),
    },
    {
      name: 'policy_invoice_public_read',
      table: 'Invoice',
      cmd: 'SELECT',
      roles: 'public',
      using: excludeHRVia('Invoice', 'DestinationAccount'),
    },
    {
      name: 'policy_invoice_hr_select',
      table: 'Invoice',
      cmd: 'SELECT',
      roles: 'public',
      using: `${hrCheck} AND ${isEmployeeVia('Invoice', 'DestinationAccount')}`,
    },

    // --- Allocation ---
    {
      name: 'policy_allocation_sterile_select',
      table: 'Allocation',
      cmd: 'SELECT',
      roles: 'sterile_dev',
      using: excludeHRVia('Allocation', 'DestinationAccount'),
    },
    {
      name: 'policy_allocation_public_read',
      table: 'Allocation',
      cmd: 'SELECT',
      roles: 'public',
      using: excludeHRVia('Allocation', 'DestinationAccount'),
    },
    {
      name: 'policy_allocation_hr_select',
      table: 'Allocation',
      cmd: 'SELECT',
      roles: 'public',
      using: `${hrCheck} AND ${isEmployeeVia('Allocation', 'DestinationAccount')}`,
    },
    {
      name: 'policy_allocation_hr_update',
      table: 'Allocation',
      cmd: 'UPDATE',
      roles: 'public',
      using: `${hrCheck} AND ${isEmployeeVia('Allocation', 'DestinationAccount')} AND auth_crud('Allocation', 'UPDATE')`,
    },
    {
      name: 'policy_allocation_hr_delete',
      table: 'Allocation',
      cmd: 'DELETE',
      roles: 'public',
      using: `${hrCheck} AND ${isEmployeeVia('Allocation', 'DestinationAccount')} AND auth_crud('Allocation', 'DELETE')`,
    },

    // --- BankStatement ---
    {
      name: 'policy_bankstatement_public_read',
      table: 'BankStatement',
      cmd: 'SELECT',
      roles: 'public',
      using: excludeHRVia('BankStatement', 'Account'),
    },
    {
      name: 'policy_bankstatement_hr_select',
      table: 'BankStatement',
      cmd: 'SELECT',
      roles: 'public',
      using: `${hrCheck} AND ${isEmployeeVia('BankStatement', 'Account')}`,
    },
    {
      name: 'policy_bankstatement_hr_update',
      table: 'BankStatement',
      cmd: 'UPDATE',
      roles: 'public',
      using: `${hrCheck} AND ${isEmployeeVia('BankStatement', 'Account')} AND auth_crud('BankStatement', 'UPDATE')`,
    },
    {
      name: 'policy_bankstatement_hr_delete',
      table: 'BankStatement',
      cmd: 'DELETE',
      roles: 'public',
      using: `${hrCheck} AND ${isEmployeeVia('BankStatement', 'Account')} AND auth_crud('BankStatement', 'DELETE')`,
    },
  ];

  try {
    for (const pol of policies) {
      const sql = `CREATE POLICY "${pol.name}" ON "${S}"."${pol.table}" FOR ${pol.cmd} TO ${pol.roles} USING (${pol.using})`;
      await client.query(sql);
      console.log(`Created: ${pol.name} on ${pol.table}`);
    }

    console.log('\nAll dropped policies restored! Done.');
  } catch (err) {
    console.error('ERROR:', err.message);
    console.error(err.stack);
    process.exit(1);
  } finally {
    await client.end();
  }
}

main();
