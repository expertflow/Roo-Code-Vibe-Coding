/**
 * Validates Story 1.3 config against schema_dump_final.json (no Directus required).
 */
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { describe, it } from 'node:test';
import assert from 'node:assert';

import {
  ORG_HR_COLLECTIONS,
  COLLECTION_META,
  ORG_HR_RELATIONS,
  FIELD_OVERRIDES,
  LEGAL_ENTITY_TYPE_CHOICES,
  PROJECT_STATUS_CHOICES,
} from './lib/story-1-3-config.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const SCHEMA_PATH = join(__dirname, '../../../..', 'schema_dump_final.json');

const schema = JSON.parse(readFileSync(SCHEMA_PATH, 'utf8'));

function columnNames(table) {
  return new Set(schema[table].map((c) => c.name));
}

describe('Story 1.3 config vs schema_dump_final.json', () => {
  it('has meta for every org/HR collection', () => {
    for (const col of ORG_HR_COLLECTIONS) {
      assert.ok(COLLECTION_META[col], `COLLECTION_META missing ${col}`);
      assert.ok(schema[col], `schema missing table ${col}`);
    }
  });

  it('display templates match architecture §4.3 / story AC', () => {
    assert.strictEqual(
      COLLECTION_META.Employee.display_template,
      '{{EmployeeName}} ({{email}})',
    );
    assert.strictEqual(
      COLLECTION_META.LegalEntity.display_template,
      '{{Name}} ({{Type}})',
    );
    assert.strictEqual(
      COLLECTION_META.Project.display_template,
      '{{Name}} — {{Status}}',
    );
    assert.ok(COLLECTION_META.EmployeePersonalInfo.display_template.includes('employee_id'));
  });

  it('every ORG_HR_RELATION many_field exists on many_collection', () => {
    for (const r of ORG_HR_RELATIONS) {
      assert.ok(schema[r.many_collection], `missing table ${r.many_collection}`);
      assert.ok(schema[r.one_collection], `missing table ${r.one_collection}`);
      const cols = columnNames(r.many_collection);
      assert.ok(
        cols.has(r.many_field),
        `${r.many_collection}.${r.many_field} not in schema`,
      );
      if (r.field_one) {
        const oneCols = columnNames(r.one_collection);
        assert.ok(
          oneCols.has(r.field_one),
          `${r.one_collection}.${r.field_one} not in schema`,
        );
      }
    }
  });

  it('LegalEntity.Type + Project.Status choice lists are non-empty', () => {
    assert.ok(LEGAL_ENTITY_TYPE_CHOICES.length >= 4);
    assert.ok(PROJECT_STATUS_CHOICES.length >= 3);
  });

  it('FIELD_OVERRIDES only reference existing columns', () => {
    for (const [table, fields] of Object.entries(FIELD_OVERRIDES)) {
      const cols = columnNames(table);
      for (const fname of Object.keys(fields)) {
        assert.ok(cols.has(fname), `override ${table}.${fname} not in schema`);
      }
    }
  });

  it('Employee.ProfitCenter is hidden in overrides (FR22 / A2)', () => {
    assert.strictEqual(FIELD_OVERRIDES.Employee.ProfitCenter.hidden, true);
  });
});
