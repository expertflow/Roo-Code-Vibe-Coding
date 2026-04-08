#!/usr/bin/env node
/**
 * Check that STATIC_TOKEN (or email/password) works for this DIRECTUS_URL before running
 * apply-m2o-dropdown-templates.mjs or other metadata scripts.
 *
 * A 401 on /relations often means the token never persisted: generate token → **Save user** → copy once.
 *
 * Env (same as apply-m2o-dropdown-templates.mjs):
 *   DIRECTUS_URL (default http://127.0.0.1:8055)
 *   STATIC_TOKEN or DIRECTUS_STATIC_TOKEN — OR —
 *   DIRECTUS_ADMIN_EMAIL + DIRECTUS_ADMIN_PASSWORD
 *
 * Usage:
 *   node verify-directus-auth.mjs
 *   node verify-directus-auth.mjs --relations   # also GET /relations?limit=1 (metadata)
 */

async function api(base, path, opts = {}) {
  const url = `${base.replace(/\/$/, '')}${path}`;
  const method = opts.method || 'GET';
  const res = await fetch(url, {
    ...opts,
    headers: {
      'Content-Type': 'application/json',
      ...(opts.headers || {}),
    },
    body: opts.body ? JSON.stringify(opts.body) : undefined,
  });
  const text = await res.text();
  let json;
  try {
    json = text ? JSON.parse(text) : {};
  } catch {
    throw new Error(`${method} ${path} → ${res.status} non-JSON: ${text.slice(0, 400)}`);
  }
  if (!res.ok) {
    let msg = `${method} ${path} → ${res.status}: ${JSON.stringify(json)}`;
    if (res.status === 401 && path !== '/auth/login') {
      msg +=
        '\n  Hint (401): Token rejected. Save the user after generating the token; copy the raw value (no `Bearer `). Try the same URL you use in the browser. If KEY/SECRET in .env changed, regenerate the token.';
    }
    throw new Error(msg);
  }
  return json;
}

function normalizeStaticToken(raw) {
  if (raw == null) return '';
  let t = String(raw).trim();
  if (/^bearer\s+/i.test(t)) t = t.replace(/^bearer\s+/i, '').trim();
  return t;
}

async function getToken(base) {
  const staticToken = normalizeStaticToken(
    process.env.STATIC_TOKEN || process.env.DIRECTUS_STATIC_TOKEN,
  );
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

async function main() {
  const base = process.env.DIRECTUS_URL || 'http://127.0.0.1:8055';
  const checkRelations = process.argv.includes('--relations');

  const usingStatic = Boolean(
    normalizeStaticToken(process.env.STATIC_TOKEN || process.env.DIRECTUS_STATIC_TOKEN),
  );

  console.log('DIRECTUS_URL:', base);
  console.log('Auth mode:', usingStatic ? 'STATIC_TOKEN' : 'DIRECTUS_ADMIN_EMAIL + password');

  const token = await getToken(base);
  const auth = { Authorization: `Bearer ${token}` };

  const me = await api(base, '/users/me', { headers: auth });
  const u = me.data;
  console.log('OK — GET /users/me');
  console.log('  id:', u?.id);
  console.log('  email:', u?.email);
  console.log('  status:', u?.status);
  if (u?.role != null) console.log('  role:', u.role);

  if (checkRelations) {
    const rel = await api(base, '/relations?limit=1', { headers: auth });
    const n = Array.isArray(rel.data) ? rel.data.length : 0;
    console.log('OK — GET /relations?limit=1 (rows:', n + ')');
  }

  console.log('\nAuth OK for this instance. Run apply-m2o-dropdown-templates.mjs with the same env.');
}

main().catch((e) => {
  console.error(e.message || e);
  process.exit(1);
});
