/**
 * Lookup routes — reference data for the mobile expense form.
 * All endpoints are authenticated (Google SSO).
 * Direct PostgreSQL queries — no Directus.
 */

const express = require('express');
const router = express.Router();
const { requireAuth } = require('../lib/auth');
const { query } = require('../lib/db');

/**
 * GET /api/projects — Active projects
 */
router.get('/projects', requireAuth, async (req, res, next) => {
  try {
    const result = await query(
      `SELECT id, "Name", "Status" FROM "Project" WHERE "Status" = 'Open' ORDER BY "Name"`
    );
    res.json(result.rows);
  } catch (err) {
    next(err);
  }
});

/**
 * GET /api/currencies — Real currencies only (exclude HR leave types)
 */
router.get('/currencies', requireAuth, async (req, res, next) => {
  try {
    const result = await query(
      `SELECT id, "CurrencyCode", "Name" FROM "Currency"
       WHERE "CurrencyCode" NOT LIKE 'HR%'
         AND "CurrencyCode" NOT IN ('HL', 'MR - HR')
       ORDER BY "CurrencyCode"`
    );
    res.json(result.rows);
  } catch (err) {
    next(err);
  }
});

/**
 * GET /api/accounts — Company card accounts for Internal Expertflow entities
 * Filtered to internal LegalEntities only.
 */
router.get('/accounts', requireAuth, async (req, res, next) => {
  try {
    const result = await query(
      `SELECT a.id, a."Name", le."Name" AS le_name
       FROM "Account" a
       JOIN "LegalEntity" le ON a."LegalEntity" = le.id
       WHERE le."Type" = 'Internal'
         AND le."Name" ILIKE '%expertflow%'
       ORDER BY le."Name", a."Name"`
    );
    res.json(result.rows);
  } catch (err) {
    next(err);
  }
});

/**
 * GET /api/employee/me — Current employee's details
 * Resolved from the Google SSO email.
 */
router.get('/employee/me', requireAuth, async (req, res, next) => {
  try {
    // Attempt standard query. Fallback to lowercase or uppercase column logic if needed.
    const result = await query(
      `SELECT e.id, e."Email" as email, e."EmployeeName", e."DefaultProjectId"
       FROM "Employee" e
       WHERE e."Email" ILIKE $1 OR e.email ILIKE $1`,
      [req.user.email]
    ).catch(async () => {
      // If the above query fails due to column name mismatch, try lowercase "email"
      return await query(
        `SELECT e.id, e.email, e."EmployeeName", e."DefaultProjectId"
         FROM "Employee" e
         WHERE e.email ILIKE $1`,
        [req.user.email]
      );
    });

    if (!result || result.rows.length === 0) {
      console.warn(`[WARN] Employee not found in Employee table for email: ${req.user.email}`);
      return res.json({ 
        id: null, 
        email: req.user.email, 
        EmployeeName: req.user.name || req.user.email, 
        DefaultProjectId: null 
      });
    }
    res.json(result.rows[0]);
  } catch (err) {
    console.error('[ERROR] /employee/me query failed:', err);
    // Instead of throwing 500 and causing frontend logout, return a fallback.
    res.json({ 
      id: null, 
      email: req.user.email, 
      EmployeeName: req.user.name || req.user.email, 
      DefaultProjectId: null 
    });
  }
});

/**
 * GET /api/employee/ledger — Current employee's accounts, transactions, and invoices
 * Limited to last 6 months.
 */
router.get('/employee/ledger', requireAuth, async (req, res, next) => {
  try {
    // 1. Get Employee Name
    let empRes = await query(
      `SELECT e."EmployeeName"
       FROM "Employee" e
       WHERE e."Email" ILIKE $1 OR e.email ILIKE $1`,
      [req.user.email]
    ).catch(async () => {
      return await query(
        `SELECT e."EmployeeName"
         FROM "Employee" e
         WHERE e.email ILIKE $1`,
        [req.user.email]
      );
    });

    if (!empRes || empRes.rows.length === 0) {
      return res.json({ accounts: [] });
    }
    const empName = empRes.rows[0].EmployeeName;

    // 2. Get LegalEntity ID for the Employee
    const leRes = await query(
      `SELECT id FROM "LegalEntity" WHERE "Name" = $1 AND "Type" = 'Employee' LIMIT 1`,
      [empName]
    );

    if (leRes.rows.length === 0) {
      return res.json({ accounts: [] });
    }
    const leId = leRes.rows[0].id;

    // 3. Get employee's Accounts
    const accRes = await query(
      `SELECT a.id, a."Name", a."Currency", c."CurrencyCode" 
       FROM "Account" a
       LEFT JOIN "Currency" c ON a."Currency" = c.id
       WHERE a."LegalEntity" = $1`,
      [leId]
    );
    const accounts = accRes.rows;
    if (accounts.length === 0) {
      return res.json({ accounts: [] });
    }
    const accountIds = accounts.map(a => a.id);

    // 4. Get last 6 months Transactions for these accounts
    const txRes = await query(
      `SELECT id, "Amount", "Currency", "Description", "Date", "USDAmount", "OriginAccount", "DestinationAccount"
       FROM "Transaction" 
       WHERE ("OriginAccount" = ANY($1) OR "DestinationAccount" = ANY($1))
         AND "Date" >= NOW() - INTERVAL '6 months'
       ORDER BY "Date" DESC`,
      [accountIds]
    );

    // 5. Get last 6 months Invoices for these accounts
    const invRes = await query(
      `SELECT id, "Amount", "Currency", "Description", "SentDate", "DueDate", "Status", "USDAmount", "OriginAccount", "DestinationAccount"
       FROM "Invoice" 
       WHERE ("OriginAccount" = ANY($1) OR "DestinationAccount" = ANY($1))
         AND "SentDate" >= NOW() - INTERVAL '6 months'
       ORDER BY "SentDate" DESC`,
      [accountIds]
    );

    res.json({ accounts, transactions: txRes.rows, invoices: invRes.rows });
  } catch (err) {
    console.error('[ERROR] /employee/ledger query failed:', err);
    res.json({ accounts: [] });
  }
});

module.exports = router;
