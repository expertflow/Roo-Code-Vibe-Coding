/**
 * Story 1.3 — organizational & HR core collections: collection meta, relations, field overrides.
 * Source columns: repo root schema_dump_final.json
 */

export const ORG_HR_COLLECTIONS = [
  'LegalEntity',
  'ProfitCenter',
  'Project',
  'CountryLocation',
  'Contact',
  'Company',
  'Employee',
  'EmployeePersonalInfo',
  'Seniority',
  'Designation',
  'department',
];

/** Sidebar / translation labels (en-US) — display templates per architecture §4.3 where noted */
export const COLLECTION_META = {
  LegalEntity: {
    singular: 'Legal Entity',
    plural: 'Legal Entities',
    display_template: '{{Name}} ({{Type}})',
    icon: 'gavel',
  },
  ProfitCenter: {
    singular: 'Profit Center',
    plural: 'Profit Centers',
    display_template: '{{Name}}',
    icon: 'hub',
  },
  Project: {
    singular: 'Project',
    plural: 'Projects',
    display_template: '{{Name}} — {{Status}}',
    icon: 'folder',
  },
  CountryLocation: {
    singular: 'Country / Location',
    plural: 'Countries / Locations',
    display_template: '{{Region}} — {{Description}}',
    icon: 'public',
  },
  Contact: {
    singular: 'Contact',
    plural: 'Contacts',
    display_template: '{{Firstname}} {{LastName}}',
    icon: 'person',
  },
  Company: {
    singular: 'Company',
    plural: 'Companies',
    display_template: '{{Domain}}',
    icon: 'business',
  },
  Employee: {
    singular: 'Employee',
    plural: 'Employees',
    display_template: '{{EmployeeName}} ({{email}})',
    icon: 'badge',
  },
  EmployeePersonalInfo: {
    singular: 'Employee Personal Info',
    plural: 'Employee Personal Info',
    display_template: '{{employee_id.EmployeeName}}',
    icon: 'shield_person',
  },
  Seniority: {
    singular: 'Seniority',
    plural: 'Seniorities',
    display_template: '{{Description}}',
    icon: 'stairs',
  },
  Designation: {
    singular: 'Designation',
    plural: 'Designations',
    display_template: '{{DesignationName}}',
    icon: 'work',
  },
  department: {
    singular: 'Department',
    plural: 'Departments',
    display_template: '{{departmentname}}',
    icon: 'corporate_fare',
  },
};

/**
 * Directus relations (many → one). Story 1.5 extends cross-domain FKs.
 * Custom PKs: `department.departmentid`, `Designation.DesignationID`
 */
export const ORG_HR_RELATIONS = [
  { many_collection: 'LegalEntity', many_field: 'CountryLocation', one_collection: 'CountryLocation' },
  { many_collection: 'LegalEntity', many_field: 'Contact', one_collection: 'Contact' },
  { many_collection: 'LegalEntity', many_field: 'Project', one_collection: 'Project' },
  { many_collection: 'Contact', many_field: 'Company', one_collection: 'Company' },
  { many_collection: 'Project', many_field: 'ProfitCenter', one_collection: 'ProfitCenter' },
  { many_collection: 'Project', many_field: 'legal_entity_id', one_collection: 'LegalEntity' },
  { many_collection: 'CountryLocation', many_field: 'Currency', one_collection: 'Currency' },
  { many_collection: 'Employee', many_field: 'Seniority', one_collection: 'Seniority' },
  {
    many_collection: 'Employee',
    many_field: 'departmentid',
    one_collection: 'department',
    field_one: 'departmentid',
  },
  {
    many_collection: 'Employee',
    many_field: 'DesignationID',
    one_collection: 'Designation',
    field_one: 'DesignationID',
  },
  { many_collection: 'Employee', many_field: 'DefaultProjectId', one_collection: 'Project' },
  { many_collection: 'Employee', many_field: 'ManagerId', one_collection: 'Employee' },
  { many_collection: 'EmployeePersonalInfo', many_field: 'employee_id', one_collection: 'Employee' },
];

/** PRD / epics — LegalEntity.Type (stored as text in DB) */
export const LEGAL_ENTITY_TYPE_CHOICES = [
  { text: 'Client', value: 'Client' },
  { text: 'Partner', value: 'Partner' },
  { text: 'Employee', value: 'Employee' },
  { text: 'Executive', value: 'Executive' },
  { text: 'Internal', value: 'Internal' },
  { text: 'Vendor', value: 'Vendor' },
];

/** Project.Status enum — confirm against DB; allow custom values */
export const PROJECT_STATUS_CHOICES = [
  { text: 'Active', value: 'Active' },
  { text: 'Inactive', value: 'Inactive' },
  { text: 'Archived', value: 'Archived' },
];

export const FIELD_OVERRIDES = {
  LegalEntity: {
    Type: {
      interface: 'select-dropdown',
      options: { choices: LEGAL_ENTITY_TYPE_CHOICES, allowOther: true },
    },
    CountryLocation: { translation: 'Country / Location' },
    DocumentFolder: { translation: 'Document Folder' },
  },
  Project: {
    Status: {
      interface: 'select-dropdown',
      options: { choices: PROJECT_STATUS_CHOICES, allowOther: true },
    },
    ProfitCenter: { translation: 'Profit Center' },
    legal_entity_id: { translation: 'Legal Entity' },
  },
  Contact: {
    Firstname: { translation: 'First name' },
    LastName: { translation: 'Last name' },
  },
  Company: {
    WebsiteURL: { translation: 'Website URL' },
  },
  Employee: {
    mobile_number: { translation: 'Mobile number' },
    employ_start_date: { translation: 'Employment start date' },
    Seniority: { translation: 'Seniority' },
    departmentid: { translation: 'Department' },
    DesignationID: { translation: 'Designation' },
    EmployeeName: { translation: 'Employee name' },
    DefaultProjectId: { translation: 'Default project' },
    ManagerId: { translation: 'Manager' },
    ProfitCenter: {
      interface: 'input',
      options: { trim: true },
      hidden: true,
    },
  },
  EmployeePersonalInfo: {
    employee_id: { translation: 'Employee' },
    personal_email: { translation: 'Personal email' },
    phone_no: { translation: 'Phone' },
    father_name: { translation: "Father's name" },
    emergency_contact_phone: { translation: 'Emergency contact phone' },
    emergency_contact_name: { translation: 'Emergency contact name' },
    date_of_birth: { translation: 'Date of birth' },
    city_area: { translation: 'City / area' },
    address_line: { translation: 'Address line' },
  },
  CountryLocation: {
    VATRate: { translation: 'VAT rate' },
  },
  Seniority: {
    Dayrate: { translation: 'Day rate' },
  },
  Designation: {
    DesignationName: { translation: 'Designation name' },
  },
  department: {
    departmentid: { translation: 'Department ID' },
    departmentname: { translation: 'Department name' },
  },
};

export function interfaceForType(pgType, fieldName, collection, m2oFields) {
  const key = `${collection}.${fieldName}`;
  if (m2oFields.has(key)) return { interface: 'select-dropdown-m2o', options: {} };

  switch (pgType) {
    case 'numeric':
      return { interface: 'input-decimal', options: {} };
    case 'integer':
      return { interface: 'input', options: {} };
    case 'date':
    case 'timestamp with time zone':
    case 'timestamp without time zone':
      return { interface: 'datetime', options: {} };
    case 'boolean':
      return { interface: 'boolean', options: {} };
    case 'text':
      return { interface: 'input', options: { trim: true } };
    case 'character varying':
      return { interface: 'input', options: { trim: true } };
    case 'interval':
      return { interface: 'input', options: {} };
    case 'USER-DEFINED':
      return { interface: 'select-dropdown', options: { allowOther: true } };
    case 'jsonb':
      return { interface: 'input-code', options: {} };
    default:
      return { interface: 'input', options: {} };
  }
}

export function buildM2oKeySet() {
  const set = new Set();
  for (const r of ORG_HR_RELATIONS) {
    set.add(`${r.many_collection}.${r.many_field}`);
  }
  return set;
}
