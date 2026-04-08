/**
 * PostgreSQL connection pool.
 * Direct connection — no Directus dependency.
 * 
 * On Cloud Run: uses Unix socket via Cloud SQL Auth Proxy sidecar.
 * Locally: uses direct IP with SSL.
 */

const { Pool } = require('pg');

let pool;

function getPool() {
  if (pool) return pool;

  const instanceConn = process.env.INSTANCE_CONNECTION_NAME;

  if (instanceConn) {
    // Cloud Run: Unix socket via Cloud SQL Auth Proxy
    pool = new Pool({
      user: process.env.DB_USER,
      password: process.env.DB_PASS,
      database: process.env.DB_NAME,
      host: `/cloudsql/${instanceConn}`,
    });
  } else {
    // Local dev: direct IP with SSL
    pool = new Pool({
      user: process.env.DB_USER,
      password: process.env.DB_PASS,
      database: process.env.DB_NAME,
      host: process.env.DB_HOST || '213.55.244.201',
      port: 5432,
      ssl: { rejectUnauthorized: false },
    });
  }

  pool.on('error', (err) => {
    console.error('Unexpected pool error:', err);
  });

  return pool;
}

const SCHEMA = process.env.DB_SCHEMA || 'BS4Prod09Feb2026';

/**
 * Run a parameterized query against the configured schema.
 * @param {string} sql — Use $1, $2… placeholders
 * @param {any[]} params
 * @returns {Promise<import('pg').QueryResult>}
 */
async function query(sql, params = []) {
  const client = await getPool().connect();
  try {
    // Set search_path so we don't need to qualify every table
    await client.query(`SET search_path TO "${SCHEMA}"`);
    const result = await client.query(sql, params);
    return result;
  } finally {
    client.release();
  }
}

module.exports = { query, getPool, SCHEMA };
