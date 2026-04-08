/**
 * Expense API — Express server
 * Direct PostgreSQL (no Directus). Deployed on Cloud Run (scale-to-zero).
 */

require('dotenv').config();
const express = require('express');
const cors = require('cors');
const submitRouter = require('./routes/submit');
const lookupsRouter = require('./routes/lookups');

const app = express();
const PORT = process.env.PORT || 8080;

// ── Middleware ───────────────────────────────────────────────────────────────
app.use(cors({
  origin: [
    'http://localhost:5173',                    // Vite dev
    'http://localhost:4173',                    // Vite preview
    /\.web\.app$/,                             // Firebase Hosting
    /\.firebaseapp\.com$/,                     // Firebase Hosting alt
    /\.run\.app$/,                             // Cloud Run
  ],
  credentials: true,
}));
app.use(express.json());

// ── Health check (Cloud Run requirement) ────────────────────────────────────
app.get('/', (req, res) => res.json({ status: 'ok', service: 'expense-api' }));
app.get('/health', (req, res) => res.json({ status: 'ok' }));

// ── Routes ──────────────────────────────────────────────────────────────────
app.use('/api', submitRouter);
app.use('/api', lookupsRouter);

// ── Error handler ───────────────────────────────────────────────────────────
app.use((err, req, res, next) => {
  console.error('Unhandled error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

// ── Start ───────────────────────────────────────────────────────────────────
app.listen(PORT, '0.0.0.0', () => {
  console.log(`expense-api listening on port ${PORT}`);
});
