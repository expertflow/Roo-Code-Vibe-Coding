#!/usr/bin/env node
/**
 * One-shot: reset Invoice.image to plain text meta (no file special/display/validation merge).
 * Use when Story 1.2 already ran but Directus still 500s on Invoice create with `.match`.
 *
 *   cd projects/internal-erp/directus
 *   DIRECTUS_URL=http://127.0.0.1:8055 DIRECTUS_ADMIN_EMAIL=... DIRECTUS_ADMIN_PASSWORD=... node scripts/fix-invoice-image-field-meta.mjs
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

const PLAIN_FIELD_META_PASSTHROUGH = ['note', 'hidden', 'readonly', 'required', 'width', 'group', 'sort'];

function metaForPlainTextAfterClearingFile(currentMeta, iface, options, translation) {
  const m = {
    interface: iface,
    options: options ?? {},
    translations: mergeTranslation(currentMeta?.translations, translation),
    special: [],
    display: 'formatted-value',
    display_options: {},
  };
  for (const k of PLAIN_FIELD_META_PASSTHROUGH) {
    if (currentMeta && currentMeta[k] !== undefined && currentMeta[k] !== null) {
      m[k] = currentMeta[k];
    }
  }
  return m;
}

async function main() {
  const base = process.env.DIRECTUS_URL || 'http://127.0.0.1:8055';
  const override = FIELD_OVERRIDES.Invoice?.image;
  if (!override?.clearSpecial) {
    throw new Error('FIELD_OVERRIDES.Invoice.image.clearSpecial missing — check story-1-2-config.mjs');
  }
  const token = dryRun ? 'dry' : await getToken(base);
  const auth = { Authorization: `Bearer ${token}` };

  const fieldsRes = dryRun ? { data: [{ field: 'image', meta: {} }] } : await api(base, '/fields/Invoice', { headers: auth });
  const current = (fieldsRes.data || []).find((f) => f.field === 'image');
  if (!current) throw new Error('Field Invoice.image not found');

  const meta = metaForPlainTextAfterClearingFile(
    current.meta,
    override.interface,
    override.options,
    override.translation,
  );

  console.log(dryRun ? '[dry-run] Would PATCH Invoice/image with:' : 'PATCH Invoice/image …');
  console.log(JSON.stringify(meta, null, 2));

  if (!dryRun) {
    await api(base, '/fields/Invoice/image', {
      method: 'PATCH',
      headers: auth,
      body: { meta },
    });
    console.log('Done. Open Admin → Invoice → image → Interface tab: should be Input; Special empty.');
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
