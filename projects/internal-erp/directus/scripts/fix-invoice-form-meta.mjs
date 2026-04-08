#!/usr/bin/env node
/**
 * One-shot: make the Invoice create/edit form sane in Directus.
 *
 * - `id` is DB-assigned (`nextval(...)`) → hide + readonly
 * - `image` is legacy / out-of-scope and was a source of `.match` errors → hide
 *
 * Usage:
 *   cd projects/internal-erp/directus
 *   DIRECTUS_URL=http://127.0.0.1:8055 DIRECTUS_ADMIN_EMAIL=... DIRECTUS_ADMIN_PASSWORD=... node scripts/fix-invoice-form-meta.mjs
 *   # or STATIC_TOKEN=...
 */

import { FIELD_OVERRIDES } from './lib/story-1-2-config.mjs';

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

const SAFE_META_PASSTHROUGH = ['note', 'required', 'width', 'group', 'sort'];

function buildInvoiceFieldMeta(field, currentMeta) {
  const override = FIELD_OVERRIDES.Invoice?.[field] || {};
  const meta = {
    interface: override.interface ?? currentMeta?.interface ?? 'input',
    options: override.options ?? currentMeta?.options ?? {},
    translations: mergeTranslation(currentMeta?.translations, override.translation ?? field),
    hidden: override.hidden === true ? true : currentMeta?.hidden === true,
    readonly: override.readonly === true ? true : currentMeta?.readonly === true,
  };

  if (field === 'image') {
    meta.special = [];
    meta.display = 'formatted-value';
    meta.display_options = {};
  } else if (Array.isArray(currentMeta?.special)) {
    meta.special = currentMeta.special;
  }

  for (const key of SAFE_META_PASSTHROUGH) {
    if (currentMeta && currentMeta[key] !== undefined && currentMeta[key] !== null && meta[key] === undefined) {
      meta[key] = currentMeta[key];
    }
  }

  return meta;
}

async function main() {
  const base = process.env.DIRECTUS_URL || 'http://127.0.0.1:8055';
  const token = dryRun ? 'dry' : await getToken(base);
  const auth = { Authorization: `Bearer ${token}` };
  const fieldsToPatch = ['id', 'image'];

  const fieldsRes = dryRun
    ? { data: fieldsToPatch.map((field) => ({ field, meta: {} })) }
    : await api(base, '/fields/Invoice', { headers: auth });
  const fields = fieldsRes.data || [];

  for (const field of fieldsToPatch) {
    const current = fields.find((row) => row.field === field);
    if (!current) {
      console.warn(`Skipping Invoice.${field}; field not found`);
      continue;
    }

    const meta = buildInvoiceFieldMeta(field, current.meta);
    console.log(dryRun ? `[dry-run] Would PATCH Invoice/${field}` : `PATCH Invoice/${field} …`);
    console.log(JSON.stringify(meta, null, 2));

    if (!dryRun) {
      await api(base, `/fields/Invoice/${encodeURIComponent(field)}`, {
        method: 'PATCH',
        headers: auth,
        body: { meta },
      });
    }
  }

  console.log('Done. Invoice form fields patched: id hidden/readonly; image hidden.');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
