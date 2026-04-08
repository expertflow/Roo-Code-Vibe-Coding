/**
 * Story 1.9 config vs schema_dump_final.json (no Directus required).
 */
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { describe, it } from 'node:test';
import assert from 'node:assert';

import {
  RBAC_COLLECTIONS,
  COLLECTION_META,
  RBAC_RELATIONS,
  FIELD_OVERRIDES,
  buildRbacM2oKeySet,
} from './lib/story-1-9-config.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const SCHEMA_PATH = join(__dirname, '../../../..', 'schema_dump_final.json');
const schema = JSON.parse(readFileSync(SCHEMA_PATH, 'utf8'));

describe('Story 1.9 config vs schema_dump_final.json', () => {
  it('has meta for every RBAC collection', () => {
    for (const col of RBAC_COLLECTIONS) {
      assert.ok(COLLECTION_META[col], `COLLECTION_META missing ${col}`);
      assert.ok(schema[col], `schema missing table ${col}`);
    }
  });

  it('RBAC relations reference existing tables and columns', () => {
    for (const r of RBAC_RELATIONS) {
      assert.ok(schema[r.many_collection], `many ${r.many_collection}`);
      assert.ok(schema[r.one_collection], `one ${r.one_collection}`);
      const cols = new Set(schema[r.many_collection].map((c) => c.name));
      assert.ok(cols.has(r.many_field), `column ${r.many_collection}.${r.many_field}`);
    }
  });

  it('UserToRole.User is text (email storage)', () => {
    const u = schema.UserToRole.find((c) => c.name === 'User');
    assert.ok(u);
    assert.strictEqual(u.type, 'text');
  });

  it('buildRbacM2oKeySet matches relations', () => {
    const set = buildRbacM2oKeySet();
    assert.ok(set.has('RolePermissions.Role'));
    assert.ok(set.has('UserToRole.RoleName'));
  });

  it('FIELD_OVERRIDES cover UserToRole.User and AccessCondition', () => {
    assert.ok(FIELD_OVERRIDES.UserToRole.User);
    assert.ok(FIELD_OVERRIDES.RolePermissions.AccessCondition);
  });
});
