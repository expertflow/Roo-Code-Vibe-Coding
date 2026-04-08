#!/usr/bin/env node
/**
 * Story 1.9 — Apply collection labels, display templates, M2O relations, and field interfaces
 * for PostgreSQL RBAC tables: `Role`, `RolePermissions`, `UserToRole`.
 *
 * Prerequisites: tables introspected in Directus (collections exist).
 *
 * Usage:
 *   DIRECTUS_URL=http://localhost:8055 DIRECTUS_ADMIN_EMAIL=... DIRECTUS_ADMIN_PASSWORD=... node apply-story-1-9-rbac-meta.mjs
 *   node apply-story-1-9-rbac-meta.mjs --dry-run
 */

import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

import {
  RBAC_COLLECTIONS,
  COLLECTION_META,
  RBAC_RELATIONS,
  FIELD_OVERRIDES,
  buildRbacM2oKeySet,
} from './lib/story-1-9-config.mjs';
import { interfaceForType } from './lib/story-1-3-config.mjs';
import { displayTemplateForCollection } from './lib/collection-display-templates.mjs';
import { mergeM2oReadableMeta } from './lib/m2o-readable-meta.mjs';
import { erpRelationPostBodyAttempts } from './lib/erp-relations.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = join(__dirname, '../../../..');
const SCHEMA_PATH = join(REPO_ROOT, 'schema_dump_final.json');

const dryRun = process.argv.includes('--dry-run');

function humanLabel(field) {
  const spaced = field
    .replace(/_/g, ' ')
    .replace(/([a-z])([A-Z])/g, '$1 $2')
    .trim();
  if (!spaced) return field;
  return spaced.replace(/\b\w/g, (c) => c.toUpperCase());
}

async function api(base, path, opts = {}) {
  const url = `${base.replace(/\/$/, '')}${path}`;
  if (dryRun) {
    console.log(`[dry-run] ${opts.method || 'GET'} ${url}`, opts.body ? JSON.stringify(opts.body).slice(0, 240) : '');
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
    throw new Error(`${opts.method || 'GET'} ${path} → ${res.status} non-JSON: ${text.slice(0, 500)}`);
  }
  if (!res.ok) {
    throw new Error(`${opts.method || 'GET'} ${path} → ${res.status}: ${JSON.stringify(json)}`);
  }
  return json;
}

async function getToken(base) {
  const staticToken = process.env.STATIC_TOKEN || process.env.DIRECTUS_STATIC_TOKEN;
  if (staticToken) return staticToken;
  const email = process.env.DIRECTUS_ADMIN_EMAIL;
  const password = process.env.DIRECTUS_ADMIN_PASSWORD;
  if (!email || !password) {
    throw new Error(
      'Set STATIC_TOKEN or DIRECTUS_ADMIN_EMAIL + DIRECTUS_ADMIN_PASSWORD',
    );
  }
  const r = await api(base, '/auth/login', {
    method: 'POST',
    body: { email, password, mode: 'json' },
  });
  return r.data.access_token;
}

function relationKey(rel) {
  return `${rel.many_collection}.${rel.many_field}`;
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

function defaultFieldFlags(fieldName) {
  if (fieldName === 'id') {
    return { hidden: true, readonly: true };
  }
  return { hidden: false, readonly: false };
}

async function postErpRelation(base, auth, rel) {
  const attempts = erpRelationPostBodyAttempts(rel);
  let lastErr;
  for (const body of attempts) {
    try {
      await api(base, '/relations', { method: 'POST', headers: auth, body });
      return { ok: true };
    } catch (e) {
      lastErr = e;
    }
  }
  return { ok: false, error: lastErr };
}

async function main() {
  const base = process.env.DIRECTUS_URL || 'http://127.0.0.1:8055';
  const schema = JSON.parse(readFileSync(SCHEMA_PATH, 'utf8'));
  const m2oKeys = buildRbacM2oKeySet();
  const m2oRelatedCollection = new Map();
  for (const r of RBAC_RELATIONS) {
    m2oRelatedCollection.set(`${r.many_collection}.${r.many_field}`, r.one_collection);
  }
  const token = dryRun ? 'dry' : await getToken(base);
  const auth = { Authorization: `Bearer ${token}` };

  if (!dryRun) {
    console.log('Story 1.9 — applying RBAC collection metadata to', base);
  }

  for (const col of RBAC_COLLECTIONS) {
    if (!schema[col]) {
      throw new Error(`schema_dump_final.json missing table "${col}"`);
    }
    if (!dryRun) {
      try {
        await api(base, `/collections/${encodeURIComponent(col)}`, { headers: auth });
      } catch (e) {
        throw new Error(
          `Collection "${col}" not found in Directus. Introspect DB in Admin first.\n${e.message}`,
        );
      }
    }
  }

  let existingRels = [];
  if (!dryRun) {
    const relRes = await api(base, '/relations', { headers: auth });
    existingRels = relRes.data || [];
  }
  const existingRelKeys = new Set(
    existingRels.map((r) => {
      const col =
        r.collection ?? r.many_collection ?? r.meta?.many_collection;
      const fld = r.field ?? r.many_field ?? r.meta?.many_field;
      return col && fld ? `${col}.${fld}` : '';
    }).filter(Boolean),
  );

  for (const rel of RBAC_RELATIONS) {
    const key = relationKey(rel);
    if (existingRelKeys.has(key)) continue;
    if (dryRun) {
      console.log('[dry-run] POST /relations', erpRelationPostBodyAttempts(rel)[0]);
      continue;
    }
    const result = await postErpRelation(base, auth, rel);
    if (result.ok) {
      console.log('Created relation', key, '→', rel.one_collection);
      existingRelKeys.add(key);
    } else {
      console.warn('Relation skip/fail (may already exist):', key, result.error?.message || result.error);
    }
  }

  for (const col of RBAC_COLLECTIONS) {
    const meta = COLLECTION_META[col];
    if (!meta) continue;
    const body = {
      meta: {
        icon: meta.icon,
        display_template: meta.display_template,
        hidden: false,
        translations: [
          {
            language: 'en-US',
            translation: meta.singular,
            singular: meta.singular,
            plural: meta.plural,
          },
        ],
      },
    };
    if (dryRun) {
      console.log('[dry-run] PATCH /collections/' + col, JSON.stringify(body));
      continue;
    }
    await api(base, `/collections/${encodeURIComponent(col)}`, {
      method: 'PATCH',
      headers: auth,
      body,
    });
    console.log('Patched collection', col);
  }

  for (const col of RBAC_COLLECTIONS) {
    const columns = schema[col];
    const fieldsRes = dryRun
      ? { data: columns.map((c) => ({ field: c.name, type: c.type })) }
      : await api(base, `/fields/${encodeURIComponent(col)}`, { headers: auth });
    const fields = fieldsRes.data || [];

    for (const row of columns) {
      const name = row.name;
      const pgType = row.type;
      const overrides = (FIELD_OVERRIDES[col] && FIELD_OVERRIDES[col][name]) || {};
      const defaultFlags = defaultFieldFlags(name);
      const key = `${col}.${name}`;
      let iface = overrides.interface;
      let options = overrides.options;
      if (!iface) {
        const inferred = interfaceForType(pgType, name, col, m2oKeys);
        iface = inferred.interface;
        options = inferred.options;
      }
      const relatedCol = m2oRelatedCollection.get(key);
      const translation = overrides.translation || humanLabel(name);

      if (!dryRun) {
        const current = fields.find((f) => f.field === name);
        if (!current) {
          console.warn('Field missing in Directus (skip):', col, name);
          continue;
        }
        const meta = {
          ...(current.meta || {}),
          interface: iface,
          options: options ?? {},
          translations: mergeTranslation(current.meta?.translations, translation),
        };
        if (iface === 'm2o' || String(iface).includes('m2o')) {
          meta.special = Array.from(new Set([...(current.meta?.special || []), 'm2o']));
        }
        if ((iface === 'm2o' || String(iface).includes('m2o')) && relatedCol) {
          const tpl = displayTemplateForCollection(relatedCol);
          Object.assign(meta, mergeM2oReadableMeta(meta, tpl));
        }
        if (overrides.hidden === true || defaultFlags.hidden === true) {
          meta.hidden = true;
        }
        if (overrides.readonly === true || defaultFlags.readonly === true) {
          meta.readonly = true;
        }
        await api(base, `/fields/${encodeURIComponent(col)}/${encodeURIComponent(name)}`, {
          method: 'PATCH',
          headers: auth,
          body: { meta },
        });
      } else {
        console.log(
          `[dry-run] PATCH /fields/${col}/${name} → ${iface}${overrides.hidden || defaultFlags.hidden ? ' (hidden)' : ''}${overrides.readonly || defaultFlags.readonly ? ' (readonly)' : ''}`,
        );
      }
    }
    if (!dryRun) console.log('Patched fields for', col);
  }

  console.log(
    dryRun
      ? 'Dry run complete.'
      : 'Story 1.9 apply complete. Run apply-m2o-dropdown-templates.mjs if M2O display needs refresh. Epic 2 locks down non-Admin visibility.',
  );
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
