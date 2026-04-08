/**
 * Validates merged collection display templates (no Directus required).
 */
import { describe, it } from 'node:test';
import assert from 'node:assert';
import {
  DISPLAY_TEMPLATE_BY_COLLECTION,
  displayTemplateForCollection,
} from './lib/collection-display-templates.mjs';

describe('collection-display-templates', () => {
  it('includes financial + org/HR collections', () => {
    assert.ok(DISPLAY_TEMPLATE_BY_COLLECTION.Currency.includes('CurrencyCode'));
    assert.strictEqual(DISPLAY_TEMPLATE_BY_COLLECTION.ProfitCenter, '{{Name}}');
    assert.ok(DISPLAY_TEMPLATE_BY_COLLECTION.Employee.includes('EmployeeName'));
  });

  it('includes Expense fallback for legacy / external references', () => {
    assert.ok(DISPLAY_TEMPLATE_BY_COLLECTION.Expense.includes('expense'));
  });

  it('displayTemplateForCollection falls back to {{id}}', () => {
    assert.strictEqual(displayTemplateForCollection('NonexistentTable'), '{{id}}');
  });
});
