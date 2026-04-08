import { describe, it } from 'node:test';
import assert from 'node:assert';
import {
  mergeM2oReadableMeta,
  m2oReadableNeedsPatch,
  relationFkFieldNeedsPatch,
  upgradeRelationFieldMeta,
  M2O_RELATED_VALUES_DISPLAY,
} from './lib/m2o-readable-meta.mjs';

describe('m2o-readable-meta', () => {
  it('sets related-values display + matching templates', () => {
    const m = mergeM2oReadableMeta({ interface: 'm2o', options: { enableCreate: false } }, '{{Name}}');
    assert.strictEqual(m.display, M2O_RELATED_VALUES_DISPLAY);
    assert.strictEqual(m.options.template, '{{Name}}');
    assert.strictEqual(m.display_options.template, '{{Name}}');
    assert.strictEqual(m.interface, 'm2o');
    assert.strictEqual(m.options.enableCreate, false);
  });

  it('relationFkFieldNeedsPatch detects plain input FK (Project.ProfitCenter case)', () => {
    assert.strictEqual(
      relationFkFieldNeedsPatch({ interface: 'input', options: {} }, '{{Name}}'),
      true,
    );
  });

  it('upgradeRelationFieldMeta forces select-dropdown-m2o + special from input', () => {
    const m = upgradeRelationFieldMeta({ interface: 'input', options: {} }, '{{Name}}');
    assert.strictEqual(m.interface, 'select-dropdown-m2o');
    assert.ok(m.special.includes('m2o'));
    assert.strictEqual(m.display, M2O_RELATED_VALUES_DISPLAY);
  });

  it('upgradeRelationFieldMeta upgrades legacy bare m2o interface', () => {
    const m = upgradeRelationFieldMeta(
      { interface: 'm2o', special: ['m2o'], display: M2O_RELATED_VALUES_DISPLAY, display_options: { template: '{{Name}}' }, options: { template: '{{Name}}' } },
      '{{Name}}',
    );
    assert.strictEqual(m.interface, 'select-dropdown-m2o');
  });

  it('m2oReadableNeedsPatch detects missing display', () => {
    assert.strictEqual(
      m2oReadableNeedsPatch({ options: { template: '{{Name}}' } }, '{{Name}}'),
      true,
    );
    assert.strictEqual(
      m2oReadableNeedsPatch(
        {
          display: M2O_RELATED_VALUES_DISPLAY,
          options: { template: '{{Name}}' },
          display_options: { template: '{{Name}}' },
        },
        '{{Name}}',
      ),
      false,
    );
  });
});
