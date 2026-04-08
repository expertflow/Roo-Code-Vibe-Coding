/**
 * Merged collection display templates for relation dropdowns (M2O "template" option).
 * Sources: Story 1.2 + 1.3 COLLECTION_META, plus common FK targets not in those stories.
 */

import { COLLECTION_META as FINANCIAL_META } from './story-1-2-config.mjs';
import { COLLECTION_META as ORG_HR_META } from './story-1-3-config.mjs';

/** Extra targets referenced by FKs before those collections get their own story meta */
export const EXTRA_COLLECTION_DISPLAY = {
  Expense: '{{expense_date}} · {{expense_amount}} — {{expense_description}}',
  InternalCost: '{{Date}} · {{Amount}} (PC {{FromPC}}→{{ToPC}})',
  Role: '{{Name}}',
  /** directus_users — rarely shown as M2O from custom tables; safe default */
  directus_users: '{{first_name}} {{last_name}} ({{email}})',
};

/** collection name → display template string for M2O dropdowns */
export function buildDisplayTemplateByCollection() {
  const out = {};
  for (const [name, meta] of Object.entries(FINANCIAL_META)) {
    if (meta.display_template) out[name] = meta.display_template;
  }
  for (const [name, meta] of Object.entries(ORG_HR_META)) {
    if (meta.display_template) out[name] = meta.display_template;
  }
  for (const [name, tpl] of Object.entries(EXTRA_COLLECTION_DISPLAY)) {
    if (!out[name]) out[name] = tpl;
  }
  return out;
}

export const DISPLAY_TEMPLATE_BY_COLLECTION = buildDisplayTemplateByCollection();

/**
 * @param {string} collectionName
 * @param {string | null} [fallback] default when unknown
 */
export function displayTemplateForCollection(collectionName, fallback = '{{id}}') {
  return DISPLAY_TEMPLATE_BY_COLLECTION[collectionName] || fallback;
}
