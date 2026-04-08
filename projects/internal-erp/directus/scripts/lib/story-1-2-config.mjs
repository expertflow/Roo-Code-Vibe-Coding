/**
 * Story 1.2 — financial collections: collection meta, relations, field overrides.
 * Source columns: repo root schema_dump_final.json
 */

export const FINANCIAL_COLLECTIONS = [
  'Account',
  'BankStatement',
  'Transaction',
  'Invoice',
  'Allocation',
  'Accruals',
  'Journal',
  'Currency',
  'CurrencyExchange',
];

/** Sidebar / translation labels (en-US) */
export const COLLECTION_META = {
  Account: {
    singular: 'Account',
    plural: 'Accounts',
    display_template: '{{Name}} [{{LegalEntity.Name}}]',
    icon: 'account_balance_wallet',
  },
  BankStatement: {
    singular: 'Bank Statement',
    plural: 'Bank Statements',
    display_template: '{{Date}} · {{Amount}} · {{Description}}',
    icon: 'receipt_long',
  },
  Transaction: {
    singular: 'Transaction',
    plural: 'Transactions',
    display_template: 'TXN-{{id}} · {{Amount}} · {{Date}}',
    icon: 'swap_horiz',
  },
  Invoice: {
    singular: 'Invoice',
    plural: 'Invoices',
    display_template: 'INV-{{id}} · {{Amount}} {{Currency.CurrencyCode}}',
    icon: 'receipt',
  },
  Allocation: {
    singular: 'Allocation',
    plural: 'Allocations',
    display_template: '{{id}} · {{Amount}}',
    icon: 'pie_chart',
  },
  Accruals: {
    singular: 'Accrual',
    plural: 'Accruals',
    display_template: '{{id}} · {{FiscalYear}}',
    icon: 'calendar_month',
  },
  Journal: {
    singular: 'Journal Entry',
    plural: 'Journal Entries',
    display_template: '{{id}} · {{ReferenceType}} #{{ReferenceID}}',
    icon: 'article',
  },
  Currency: {
    singular: 'Currency',
    plural: 'Currencies',
    display_template: '{{CurrencyCode}} — {{Name}}',
    icon: 'payments',
  },
  CurrencyExchange: {
    singular: 'Currency Exchange Rate',
    plural: 'Currency Exchange Rates',
    display_template: '{{Key}} · {{Day}}',
    icon: 'trending_up',
  },
};

/**
 * Directus relations (many → one). Establishes M2O for FK integers.
 * Story 1.5 completes the full schema; this subset satisfies Story 1.2 AC for Invoice/Account.
 */
export const FINANCIAL_RELATIONS = [
  { many_collection: 'Account', many_field: 'Currency', one_collection: 'Currency' },
  { many_collection: 'Account', many_field: 'LegalEntity', one_collection: 'LegalEntity' },
  { many_collection: 'BankStatement', many_field: 'Account', one_collection: 'Account' },
  { many_collection: 'BankStatement', many_field: 'Transaction', one_collection: 'Transaction' },
  { many_collection: 'Transaction', many_field: 'OriginAccount', one_collection: 'Account' },
  { many_collection: 'Transaction', many_field: 'DestinationAccount', one_collection: 'Account' },
  { many_collection: 'Transaction', many_field: 'Currency', one_collection: 'Currency' },
  { many_collection: 'Transaction', many_field: 'Project', one_collection: 'Project' },
  { many_collection: 'Transaction', many_field: 'BankStatementId', one_collection: 'BankStatement' },
  { many_collection: 'Invoice', many_field: 'OriginAccount', one_collection: 'Account' },
  { many_collection: 'Invoice', many_field: 'DestinationAccount', one_collection: 'Account' },
  { many_collection: 'Invoice', many_field: 'Currency', one_collection: 'Currency' },
  { many_collection: 'Invoice', many_field: 'Project', one_collection: 'Project' },
  { many_collection: 'Invoice', many_field: 'Transaction', one_collection: 'Transaction' },
  { many_collection: 'Allocation', many_field: 'Invoice', one_collection: 'Invoice' },
  { many_collection: 'Allocation', many_field: 'Transaction', one_collection: 'Transaction' },
  { many_collection: 'Allocation', many_field: 'OriginAccount', one_collection: 'Account' },
  { many_collection: 'Allocation', many_field: 'DestinationAccount', one_collection: 'Account' },
  { many_collection: 'Accruals', many_field: 'Project', one_collection: 'Project' },
  { many_collection: 'Accruals', many_field: 'Currency', one_collection: 'Currency' },
];

/** Phase-1 polymorphic link targets (Journal.ReferenceType) — per epics AC */
export const JOURNAL_REFERENCE_TYPE_CHOICES = [
  { text: 'Invoice', value: 'Invoice' },
  { text: 'Transaction', value: 'Transaction' },
  { text: 'BankStatement', value: 'BankStatement' },
  { text: 'Expense', value: 'Expense' },
  { text: 'Allocation', value: 'Allocation' },
  { text: 'Accruals', value: 'Accruals' },
  { text: 'InternalCost', value: 'InternalCost' },
];

/** Suggested invoice statuses (free text in DB — allow custom) */
export const INVOICE_STATUS_CHOICES = [
  { text: 'Draft', value: 'Draft' },
  { text: 'Sent', value: 'Sent' },
  { text: 'Paid', value: 'Paid' },
  { text: 'Overdue', value: 'Overdue' },
  { text: 'Cancelled', value: 'Cancelled' },
];

/**
 * Per-field overrides: translation = English label in Admin.
 * interface/options only where type mapping alone is insufficient.
 */
export const FIELD_OVERRIDES = {
  Invoice: {
    /**
     * PostgreSQL assigns this via `nextval(...)`; showing it on create in Directus is confusing.
     * Keep it out of the create form.
     */
    id: {
      hidden: true,
      readonly: true,
    },
    /**
     * DB column is `character varying` (URL/path text). If Admin leaves or infers a file/image
     * interface, Directus can throw INTERNAL_SERVER_ERROR: Cannot read properties of undefined (reading 'match').
     */
    image: {
      interface: 'input',
      options: { trim: true },
      translation: 'Image URL or path',
      /** Must clear Directus `meta.special` / file display — spread of old meta kept `file` and caused `.match` 500s */
      clearSpecial: true,
      hidden: true,
    },
    Amount: { interface: 'input-decimal', options: {} },
    Status: {
      interface: 'select-dropdown',
      options: { choices: INVOICE_STATUS_CHOICES, allowOther: true },
    },
    SentDate: { interface: 'datetime' },
    DueDate: { interface: 'datetime' },
    PaymentDate: { interface: 'datetime' },
    OriginAccount: { translation: 'Origin Account' },
    DestinationAccount: { translation: 'Destination Account' },
  },
  Journal: {
    ReferenceType: {
      interface: 'select-dropdown',
      options: { choices: JOURNAL_REFERENCE_TYPE_CHOICES },
    },
    ReferenceID: { translation: 'Reference ID' },
    EntryType: { translation: 'Entry Type' },
    ResourceURL: { translation: 'Resource URL' },
    document_file: { translation: 'Document File' },
  },
  BankStatement: {
    BankTransactionID: { translation: 'Bank Transaction ID' },
  },
  Transaction: {
    OriginAccount: { translation: 'Origin Account' },
    DestinationAccount: { translation: 'Destination Account' },
    BankStatementId: { translation: 'Bank Statement' },
    expense_id: {
      translation: 'Expense',
      hidden: true,
    },
  },
  CurrencyExchange: {
    RateToUSD: { translation: 'Rate To USD' },
    Currency: { translation: 'Currency Code' },
  },
};

/** Map schema_dump_final.json type → Directus interface when not M2O */
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
  for (const r of FINANCIAL_RELATIONS) {
    set.add(`${r.many_collection}.${r.many_field}`);
  }
  return set;
}
