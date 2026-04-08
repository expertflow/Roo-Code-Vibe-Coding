import { describe, it } from 'node:test';
import assert from 'node:assert';
import {
  ALL_CONFIGURED_ERP_RELATIONS,
  erpRelationKey,
  erpRelationPostBody,
  erpRelationPostBodyAttempts,
} from './lib/erp-relations.mjs';

describe('erp-relations', () => {
  it('includes Project.ProfitCenter → ProfitCenter', () => {
    const hit = ALL_CONFIGURED_ERP_RELATIONS.find(
      (r) => r.many_collection === 'Project' && r.many_field === 'ProfitCenter',
    );
    assert.ok(hit);
    assert.strictEqual(hit.one_collection, 'ProfitCenter');
  });

  it('erpRelationPostBody passes field_one when set', () => {
    const b = erpRelationPostBody({
      many_collection: 'Employee',
      many_field: 'departmentid',
      one_collection: 'department',
      field_one: 'departmentid',
    });
    assert.strictEqual(b.field_one, 'departmentid');
  });

  it('erpRelationPostBodyAttempts provides legacy + flat shapes', () => {
    const attempts = erpRelationPostBodyAttempts({
      many_collection: 'Project',
      many_field: 'ProfitCenter',
      one_collection: 'ProfitCenter',
    });
    assert.strictEqual(attempts.length, 2);
    assert.strictEqual(attempts[1].collection, 'Project');
    assert.strictEqual(attempts[1].related_collection, 'ProfitCenter');
  });

  it('erpRelationKey is stable', () => {
    assert.strictEqual(
      erpRelationKey({ many_collection: 'Project', many_field: 'ProfitCenter' }),
      'Project.ProfitCenter',
    );
  });

  it('includes Story 1.9 RBAC relations', () => {
    const rp = ALL_CONFIGURED_ERP_RELATIONS.find(
      (r) => r.many_collection === 'RolePermissions' && r.many_field === 'Role',
    );
    assert.ok(rp);
    assert.strictEqual(rp.one_collection, 'Role');
    const utr = ALL_CONFIGURED_ERP_RELATIONS.find(
      (r) => r.many_collection === 'UserToRole' && r.many_field === 'RoleName',
    );
    assert.ok(utr);
    assert.strictEqual(utr.one_collection, 'Role');
  });
});
