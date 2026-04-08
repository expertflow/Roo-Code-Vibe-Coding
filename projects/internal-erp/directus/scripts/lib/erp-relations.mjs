/**
 * All M2O relations defined by Story 1.2 + 1.3 configs (used to ensure rows exist in Directus).
 */
import { FINANCIAL_RELATIONS } from './story-1-2-config.mjs';
import { ORG_HR_RELATIONS } from './story-1-3-config.mjs';
import { RBAC_RELATIONS } from './story-1-9-config.mjs';

export const ALL_CONFIGURED_ERP_RELATIONS = [
  ...FINANCIAL_RELATIONS,
  ...ORG_HR_RELATIONS,
  ...RBAC_RELATIONS,
];

export function erpRelationKey(rel) {
  return `${rel.many_collection}.${rel.many_field}`;
}

/**
 * Payload attempts for POST /relations (Directus versions differ).
 * 1) Docs shape: collection_many / field_many / collection_one / field_one
 * 2) Some 11.x builds expect: collection / field / related_collection (+ optional meta.one_field)
 */
export function erpRelationPostBodyAttempts(rel) {
  const legacy = {
    collection_many: rel.many_collection,
    collection_one: rel.one_collection,
    field_many: rel.many_field,
    field_one: rel.field_one ?? null,
  };
  const flat = {
    collection: rel.many_collection,
    field: rel.many_field,
    related_collection: rel.one_collection,
  };
  if (rel.field_one != null) {
    flat.meta = { one_field: rel.field_one };
  }
  return [legacy, flat];
}

/** @deprecated use first attempt only when single format required */
export function erpRelationPostBody(rel) {
  return erpRelationPostBodyAttempts(rel)[0];
}
