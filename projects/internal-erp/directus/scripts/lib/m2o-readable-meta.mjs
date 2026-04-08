/**
 * Directus Admin list/detail views use field **display**, not only interface `options.template`.
 * Built-in display: `related-values` with `display_options.template` (same template syntax as M2O picker).
 * @see https://github.com/directus/directus (displays/related-values)
 */

export const M2O_RELATED_VALUES_DISPLAY = 'related-values';

/** Directus 11 Data Studio default M2O interface (plain `m2o` can fail to hydrate related labels). */
export const PREFERRED_M2O_INTERFACE = 'select-dropdown-m2o';

/**
 * Merge template into meta for human-readable M2O everywhere (picker + tables + item header).
 * @param {Record<string, unknown>} existingMeta - current field.meta from API
 * @param {string} template - e.g. "{{Name}}" or "{{EmployeeName}} ({{email}})"
 * @returns {Record<string, unknown>}
 */
export function mergeM2oReadableMeta(existingMeta, template) {
  if (!template) return existingMeta || {};
  const m = { ...(existingMeta || {}) };
  m.options = { ...(m.options || {}), template };
  m.display = M2O_RELATED_VALUES_DISPLAY;
  m.display_options = {
    ...(m.display_options || {}),
    template,
  };
  return m;
}

/**
 * True if this field should be patched to enforce related-values display.
 */
export function m2oReadableNeedsPatch(meta, template) {
  if (!template) return false;
  return (
    meta?.options?.template !== template ||
    meta?.display !== M2O_RELATED_VALUES_DISPLAY ||
    meta?.display_options?.template !== template
  );
}

function hasM2oInterface(meta) {
  const iface = String(meta?.interface || '');
  return iface === 'm2o' || iface.includes('m2o');
}

/** Legacy `interface: m2o` without dropdown-* sometimes leaves item views as raw PK in v11. */
function hasLegacyBareM2oInterface(meta) {
  return String(meta?.interface || '') === 'm2o';
}

function hasM2oSpecial(meta) {
  return Array.isArray(meta?.special) && meta.special.includes('m2o');
}

/**
 * True if a field listed in `/relations` still needs structural or display fixes.
 * Catches FK columns left as plain **input** (raw ID in item view) after DB introspection.
 */
export function relationFkFieldNeedsPatch(meta, template) {
  if (!template) return false;
  const needsStructural = !hasM2oInterface(meta) || !hasM2oSpecial(meta);
  return needsStructural || m2oReadableNeedsPatch(meta, template);
}

/**
 * Ensure M2O interface + special + related-values display (for relation FK fields).
 * Preserves `select-dropdown-m2o` etc.; only sets `interface: m2o` when no m2o-type interface is present.
 */
export function upgradeRelationFieldMeta(existingMeta, template) {
  const m = mergeM2oReadableMeta(existingMeta, template);
  if (!hasM2oInterface(m) || hasLegacyBareM2oInterface(m)) {
    m.interface = PREFERRED_M2O_INTERFACE;
  }
  if (!hasM2oSpecial(m)) {
    const prev = Array.isArray(m.special) ? [...m.special] : [];
    if (!prev.includes('m2o')) prev.push('m2o');
    m.special = prev;
  }
  return m;
}
