/**
 * Validates Story 1.2 config against schema_dump_final.json (no Directus required).
 */
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { describe, it } from 'node:test';
import assert from 'node:assert';

import {
  FINANCIAL_COLLECTIONS,
  COLLECTION_META,
  FINANCIAL_RELATIONS,
  FIELD_OVERRIDES,
  JOURNAL_REFERENCE_TYPE_CHOICES,
} from './lib/story-1-2-config.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const SCHEMA_PATH = join(__dirname, '../../../..', 'schema_dump_final.json');

const schema = JSON.parse(readFileSync(SCHEMA_PATH, 'utf8'));

function columnNames(table) {
  return new Set(schema[table].map((c) => c.name));
}

describe('Story 1.2 config vs schema_dump_final.json', () => {
  it('has meta for every financial collection', () => {
    for (const col of FINANCIAL_COLLECTIONS) {
      assert.ok(COLLECTION_META[col], `COLLECTION_META missing ${col}`);
      assert.ok(schema[col], `schema missing table ${col}`);
    }
  });

  it('Account + Invoice display templates match AC', () => {
    assert.strictEqual(
      COLLECTION_META.Account.display_template,
      '{{Name}} [{{LegalEntity.Name}}]',
    );
    assert.strictEqual(
      COLLECTION_META.Invoice.display_template,
      'INV-{{id}} · {{Amount}} {{Currency.CurrencyCode}}',
    );
  });

  it('every FINANCIAL_RELATION many_field exists on many_collection', () => {
    for (const r of FINANCIAL_RELATIONS) {
      assert.ok(schema[r.many_collection], `missing table ${r.many_collection}`);
      assert.ok(schema[r.one_collection], `missing table ${r.one_collection}`);
      const cols = columnNames(r.many_collection);
      assert.ok(
        cols.has(r.many_field),
        `${r.many_collection}.${r.many_field} not in schema`,
      );
    }
  });

  it('Journal.ReferenceType choices are non-empty', () => {
    assert.ok(JOURNAL_REFERENCE_TYPE_CHOICES.length >= 4);
    const texts = JOURNAL_REFERENCE_TYPE_CHOICES.map((c) => c.value);
    for (const req of ['Invoice', 'Transaction', 'BankStatement', 'Expense']) {
      assert.ok(texts.includes(req), `missing ReferenceType choice ${req}`);
    }
  });

  it('FIELD_OVERRIDES only reference existing columns', () => {
    for (const [table, fields] of Object.entries(FIELD_OVERRIDES)) {
      const cols = columnNames(table);
      for (const fname of Object.keys(fields)) {
        assert.ok(cols.has(fname), `override ${table}.${fname} not in schema`);
      }
    }
  });
});
