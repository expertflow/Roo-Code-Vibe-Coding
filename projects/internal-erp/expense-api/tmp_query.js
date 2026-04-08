const { query } = require('./lib/db');
async function run() {
  try {
    const res = await query(`
      SELECT le.id, le."Name", le."Type", e."EmployeeName", e.email 
      FROM "LegalEntity" le 
      LEFT JOIN "Employee" e ON le."Name" = e."EmployeeName" 
      WHERE le."Type" = 'Employee' 
      LIMIT 5
    `);
    console.log("Employees via Name Match:", res.rows);
    
    // How about checking if there's direct correlation via email?
    // Let's also check Account
    const acc = await query(`
      SELECT a.id, a."Name", a."LegalEntity", le."Type", le."Name" as le_name 
      FROM "Account" a
      LEFT JOIN "LegalEntity" le ON a."LegalEntity" = le.id
      WHERE le."Type" = 'Employee'
      LIMIT 5
    `);
    console.log("Employee Accounts:", acc.rows);
  } catch (err) {
    console.error(err);
  } finally {
    process.exit();
  }
}
run();
