#!/usr/bin/env node
/**
 * One-shot: hide + mark readonly every plain `id` field across current Directus collections.
 *
 * Usage:
 *   cd projects/internal-erp/directus
 *   DIRECTUS_URL=http://127.0.0.1:8055 DIRECTUS_ADMIN_EMAIL=... DIRECTUS_ADMIN_PASSWORD=... node scripts/fix-all-id-fields-meta.mjs
 *   # or STATIC_TOKEN=...
 */

import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const SCHEMA_PATH = join(__dirname, '../../../..', 'schema_dump_final.json');
const dryRun = process.argv.includes('--dry-run');

async function api(base, path, opts = {}) {
  const url = `${base.replace(/\/$/, '')}${path}`;
  if (dryRun) {
    console.log(`[dry-run] ${opts.method || 'GET'} ${url}`, opts.body ? JSON.stringify(opts.body) : '');
    return { data: null };
  }
  const res = await fetch(url, {
    ...opts,
    headers: { 'Content-Type': 'application/json', ...(opts.headers || {}) },
    body: opts.body ? JSON.stringify(opts.body) : undefined,
  });
  const text = await res.text();
  let json;
  try {
    json = text ? JSON.parse(text) : {};
  } catch {
    throw new Error(`${opts.method || 'GET'} ${path} → ${res.status} non-JSON: ${text.slice(0, 500)}`);
  }
  if (!res.ok) throw new Error(`${opts.method || 'GET'} ${path} → ${res.status}: ${JSON.stringify(json)}`);
  return json;
}

async function getToken(base) {
  const staticToken = process.env.STATIC_TOKEN || process.env.DIRECTUS_STATIC_TOKEN;
  if (staticToken) return staticToken;
  const email = process.env.DIRECTUS_ADMIN_EMAIL;
  const password = process.env.DIRECTUS_ADMIN_PASSWORD;
  if (!email || !password) {
    throw new Error('Set STATIC_TOKEN or DIRECTUS_ADMIN_EMAIL + DIRECTUS_ADMIN_PASSWORD');
  }
  const r = await api(base, '/auth/login', {
    method: 'POST',
    body: { email, password, mode: 'json' },
  });
  return r.data.access_token;
}

function mergeTranslation(existingTranslations, translation) {
  const lang = 'en-US';
  const arr = Array.isArray(existingTranslations) ? [...existingTranslations] : [];
  const idx = arr.findIndex((t) => t.language === lang);
  const row = { language: lang, translation };
  if (idx >= 0) arr[idx] = { ...arr[idx], ...row };
  else arr.push(row);
  return arr;
}

async function main() {
  const base = process.env.DIRECTUS_URL || 'http://127.0.0.1:8055';
  const schema = JSON.parse(readFileSync(SCHEMA_PATH, 'utf8'));
  const collections = Object.keys(schema).filter((collection) =>
    Array.isArray(schema[collection]) && schema[collection].some((col) => col.name === 'id'),
  );
  const token = dryRun ? 'dry' : await getToken(base);
  const auth = { Authorization: `Bearer ${token}` };

  for (const collection of collections) {
    let current = { field: 'id', meta: {} };
    if (!dryRun) {
      try {
        const fieldsRes = await api(base, `/fields/${encodeURIComponent(collection)}`, { headers: auth });
        current = (fieldsRes.data || []).find((row) => row.field === 'id');
      } catch (err) {
        console.warn(`Skipping ${collection}.id; collection not available in Directus?`, err.message);
        continue;
      }
    }

    if (!current) continue;

    const meta = {
      ...(current.meta || {}),
      translations: mergeTranslation(current.meta?.translations, 'ID'),
      hidden: true,
      readonly: true,
    };

    console.log(dryRun ? `[dry-run] Would PATCH ${collection}/id` : `PATCH ${collection}/id …`);

    if (!dryRun) {
      await api(base, `/fields/${encodeURIComponent(collection)}/id`, {
        method: 'PATCH',
        headers: auth,
        body: { meta },
      });
    }
  }

  console.log('Done. All visible plain `id` fields were patched hidden + readonly where available.');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
