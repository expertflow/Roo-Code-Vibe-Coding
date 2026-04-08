/**
 * Story 1.9 — PostgreSQL RBAC tables in Directus: `Role`, `RolePermissions`, `UserToRole`.
 * Aligns `UserToRole.User` (text) with IdP verified email / RLS `app.user_email` (normalize per Architecture).
 */

export const RBAC_COLLECTIONS = ['Role', 'RolePermissions', 'UserToRole'];

export const COLLECTION_META = {
  Role: {
    singular: 'App Role',
    plural: 'App Roles',
    display_template: '{{Name}}',
    icon: 'admin_panel_settings',
    note: 'PostgreSQL `Role` — not Directus `directus_roles`',
  },
  RolePermissions: {
    singular: 'Role Permission',
    plural: 'Role Permissions',
    display_template: '{{TableName}} ({{Role.Name}})',
    icon: 'rule_folder',
  },
  UserToRole: {
    singular: 'User to Role',
    plural: 'User to Roles',
    display_template: '{{User}} → {{RoleName.Name}}',
    icon: 'link',
  },
};

/** M2O FKs in RBAC tables (Story 1.5 may add more cross-links later). */
export const RBAC_RELATIONS = [
  { many_collection: 'RolePermissions', many_field: 'Role', one_collection: 'Role' },
  { many_collection: 'UserToRole', many_field: 'RoleName', one_collection: 'Role' },
];

export const FIELD_OVERRIDES = {
  Role: {
    Name: { translation: 'Role name' },
  },
  RolePermissions: {
    Role: { translation: 'App role' },
    TableName: { translation: 'Table / collection name' },
    Create: { translation: 'Create' },
    Read: { translation: 'Read' },
    Update: { translation: 'Update' },
    Delete: { translation: 'Delete' },
    AccessCondition: {
      interface: 'input-multiline',
      options: { placeholder: 'PostgreSQL condition (optional)' },
      translation: 'Access condition',
    },
  },
  UserToRole: {
    User: {
      interface: 'input',
      options: {
        trim: true,
        placeholder: 'Lowercase email — must match IdP verified email & RLS app.user_email',
      },
      translation: 'User (email)',
    },
    RoleName: { translation: 'App role' },
  },
};

export function buildRbacM2oKeySet() {
  const set = new Set();
  for (const r of RBAC_RELATIONS) {
    set.add(`${r.many_collection}.${r.many_field}`);
  }
  return set;
}
