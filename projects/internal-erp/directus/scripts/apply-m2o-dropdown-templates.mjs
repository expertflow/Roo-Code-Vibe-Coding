#!/usr/bin/env node
/**
 * For every ERP row in `/relations`, patch the FK field: **M2O interface + special** (fixes plain
 * `input` columns that show raw IDs in item views, e.g. `Project.ProfitCenter`) and **related-values**
 * display + template (list/detail + picker).
 * Uses Story 1.2 / 1.3 display templates + GET /collections fallback + sensible defaults.
 *
 * Usage:
 *   node apply-m2o-dropdown-templates.mjs --dry-run
 *   DIRECTUS_URL=... DIRECTUS_ADMIN_EMAIL=... DIRECTUS_ADMIN_PASSWORD=... node apply-m2o-dropdown-templates.mjs
 *   # Re-apply even when API meta looks OK (fixes item views still showing raw PKs):
 *   node apply-m2o-dropdown-templates.mjs --force
 */

import {
  DISPLAY_TEMPLATE_BY_COLLECTION,
  displayTemplateForCollection,
} from './lib/collection-display-templates.mjs';
import { relationFkFieldNeedsPatch, upgradeRelationFieldMeta } from './lib/m2o-readable-meta.mjs';
import {
  ALL_CONFIGURED_ERP_RELATIONS,
  erpRelationKey,
  erpRelationPostBodyAttempts,
} from './lib/erp-relations.mjs';

const dryRun = process.argv.includes('--dry-run');
const force = process.argv.includes('--force');

async function api(base, path, opts = {}) {
  const url = `${base.replace(/\/$/, '')}${path}`;
  const method = opts.method || 'GET';
  const isWrite = ['POST', 'PATCH', 'PUT', 'DELETE'].includes(method);
  // Allow real login during --dry-run so GET /relations works; skip other writes.
  if (dryRun && isWrite && !path.startsWith('/auth/login')) {
    console.log(`[dry-run] ${method} ${path}`, opts.body ? JSON.stringify(opts.body).slice(0, 160) : '');
    return { data: null };
  }
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
    throw new Error(`${opts.method || 'GET'} ${path} → ${res.status} non-JSON: ${text.slice(0, 400)}`);
  }
  if (!res.ok) {
    let msg = `${opts.method || 'GET'} ${path} → ${res.status}: ${JSON.stringify(json)}`;
    if (res.status === 401 && path !== '/auth/login') {
      msg +=
        '\n  Hint (401): Static token invalid or user not saved. Regenerate token in Admin → User → Token, click Save, copy the full value once. Or use DIRECTUS_ADMIN_EMAIL + DIRECTUS_ADMIN_PASSWORD if default auth is enabled.';
    }
    throw new Error(msg);
  }
  return json;
}

/** Strip whitespace; allow env to accidentally include `Bearer ` prefix. */
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

/** Normalize Directus relation row (shape differs slightly by version). */
function relationTriples(data) {
  const rows = Array.isArray(data) ? data : [];
  const out = [];
  for (const r of rows) {
    const m = r.meta || {};
    const many = m.many_collection ?? r.collection;
    const field = m.many_field ?? r.field;
    const one = m.one_collection ?? r.related_collection;
    if (many && field && one) out.push({ many, field, one });
  }
  return out;
}

async function resolveTemplate(base, auth, oneCollection) {
  if (DISPLAY_TEMPLATE_BY_COLLECTION[oneCollection]) {
    return DISPLAY_TEMPLATE_BY_COLLECTION[oneCollection];
  }
  try {
    const res = await api(base, `/collections/${encodeURIComponent(oneCollection)}`, {
      headers: auth,
    });
    const tpl = res.data?.meta?.display_template;
    if (tpl && String(tpl).trim()) return tpl;
  } catch {
    /* collection missing or no access */
  }
  return displayTemplateForCollection(oneCollection);
}

/** POST /relations — try payload shapes until one succeeds (Directus API variance). */
async function postErpRelation(base, auth, rel) {
  const attempts = erpRelationPostBodyAttempts(rel);
  let lastErr;
  for (const body of attempts) {
    try {
      await api(base, '/relations', { method: 'POST', headers: auth, body });
      return { ok: true, body };
    } catch (e) {
      lastErr = e;
    }
  }
  return { ok: false, error: lastErr };
}

async function main() {
  const base = process.env.DIRECTUS_URL || 'http://127.0.0.1:8055';
  const token = await getToken(base);
  const auth = { Authorization: `Bearer ${token}` };

  const relRes = await api(base, '/relations?limit=-1', { headers: auth });
  const triples = relationTriples(relRes.data || []);

  /** Ensure Story 1.2 / 1.3 M2O rows exist (without them, item views stay raw PKs). */
  const allRelationKeys = new Set(triples.map((t) => `${t.many}.${t.field}`));
  let relationsMutated = false;
  for (const rel of ALL_CONFIGURED_ERP_RELATIONS) {
    const rk = erpRelationKey(rel);
    if (allRelationKeys.has(rk)) continue;
    if (dryRun) {
      console.log('[dry-run] POST /relations (missing)', erpRelationPostBodyAttempts(rel)[0]);
      continue;
    }
    const result = await postErpRelation(base, auth, rel);
    if (result.ok) {
      console.log('Created ERP relation', rk, '→', rel.one_collection);
      allRelationKeys.add(rk);
      relationsMutated = true;
    } else {
      console.warn('ERP relation skip/fail:', rk, result.error?.message || result.error);
    }
  }

  let triplesForFields = triples;
  if (relationsMutated && !dryRun) {
    const rr = await api(base, '/relations?limit=-1', { headers: auth });
    triplesForFields = relationTriples(rr.data || []);
  }

  /** Skip Directus system collections on the "many" side */
  const erpRels = triplesForFields.filter((t) => !String(t.many).startsWith('directus_'));

  const byMany = new Map();
  for (const t of erpRels) {
    if (!byMany.has(t.many)) byMany.set(t.many, new Map());
    byMany.get(t.many).set(t.field, t);
  }

  let patched = 0;
  let skipped = 0;

  for (const [many, fieldMap] of byMany) {
    const items = [...fieldMap.values()];
    let fieldsRes;
    try {
      fieldsRes = await api(base, `/fields/${encodeURIComponent(many)}`, { headers: auth });
    } catch (e) {
      console.warn('Skip collection (no fields):', many, e.message);
      continue;
    }
    const fields = fieldsRes.data || [];

    for (const { field, one } of items) {
      const current = fields.find((f) => f.field === field);
      if (!current) {
        console.warn('Field not found:', `${many}.${field}`);
        skipped++;
        continue;
      }

      const template = await resolveTemplate(base, auth, one);
      const needsPatch = relationFkFieldNeedsPatch(current.meta, template);
      if (!force && !needsPatch) {
        skipped++;
        continue;
      }

      const meta = upgradeRelationFieldMeta(current.meta || {}, template);

      if (dryRun) {
        console.log(
          '[dry-run] PATCH',
          `${many}.${field}`,
          force && !needsPatch ? '(force) ' : '',
          'display=related-values template=',
          template,
          '(one=',
          one + ')',
        );
        patched++;
        continue;
      }

      await api(base, `/fields/${encodeURIComponent(many)}/${encodeURIComponent(field)}`, {
        method: 'PATCH',
        headers: auth,
        body: { meta },
      });
      console.log(
        'Relation FK',
        `${many}.${field}`,
        '→',
        one,
        ':',
        template,
        force && !needsPatch ? '(forced) ' : '',
        '(select-dropdown-m2o + related-values)',
      );
      patched++;
    }
  }

  console.log(
    dryRun
      ? `Dry run: would patch ${patched} field(s); skipped ${skipped} (already OK).`
      : `Done. Patched ${patched} relation FK field(s), skipped ${skipped} (already OK).`,
  );
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
