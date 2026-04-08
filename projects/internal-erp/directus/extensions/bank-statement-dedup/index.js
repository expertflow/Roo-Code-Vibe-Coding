/**
 * Story 3-1d — BankStatement create-time deduplication (FR7/FR8).
 *
 * Key when BankTransactionID is set: Account + Date + Amount + normalized Description + BankTransactionID.
 * When BankTransactionID is empty/null: Account + Date + Amount + normalized Description (no ID token).
 * Same BankTransactionID with different Amount or Description → allowed.
 *
 * Env: BANK_STATEMENT_DEDUP_ENABLED — "false" disables (break-glass).
 */

class DuplicateBankStatementError extends Error {
  constructor() {
    super('A bank statement line with the same account, date, amount, description, and bank transaction id already exists.');
    this.status = 400;
    this.code = 'DUPLICATE_BANK_STATEMENT';
    this.extensions = { code: 'DUPLICATE_BANK_STATEMENT' };
  }
}

function enabled() {
  const v = process.env.BANK_STATEMENT_DEDUP_ENABLED;
  if (v === undefined || v === '') return true;
  return String(v).toLowerCase() !== 'false' && v !== '0';
}

/** Align with import / UI: trim and collapse whitespace (incl. newlines). */
function normalizeDescription(s) {
  if (s == null) return '';
  return String(s)
    .replace(/\r\n/g, '\n')
    .replace(/\r/g, '\n')
    .replace(/\n/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function coerceCreatePayload(input) {
  if (input == null) return [];
  if (Array.isArray(input)) return input;
  if (typeof input === 'object' && input.payload != null) {
    const p = input.payload;
    return Array.isArray(p) ? p : [p];
  }
  if (typeof input === 'object' && Array.isArray(input.data)) return input.data;
  return [input];
}

function hasDedupKeyFields(item) {
  return item && item.Account != null && item.Date != null && item.Amount != null;
}

async function existsDuplicate(database, item) {
  const account = item.Account;
  const dateVal = item.Date;
  const amount = item.Amount;
  const desc = normalizeDescription(item.Description);
  const bid = item.BankTransactionID != null ? String(item.BankTransactionID).trim() : '';

  const q = database('BankStatement')
    .where({ Account: account })
    .where('Date', dateVal)
    .whereRaw('"Amount" = ?::numeric', [String(amount)])
    .whereRaw(`trim(regexp_replace(coalesce("Description", ''), '\\s+', ' ', 'g')) = ?`, [desc]);

  if (bid) {
    q.andWhere('BankTransactionID', bid);
  } else {
    q.where(function emptyTxnId() {
      this.whereNull('BankTransactionID').orWhere('BankTransactionID', '');
    });
  }

  const row = await q.first();
  return !!row;
}

export default ({ filter }) => {
  filter('items.create', async (input, meta, { database }) => {
    if (!enabled()) return input;
    if (meta.collection !== 'BankStatement') return input;

    const items = coerceCreatePayload(input);
    for (const item of items) {
      if (!hasDedupKeyFields(item)) continue;
      if (await existsDuplicate(database, item)) {
        throw new DuplicateBankStatementError();
      }
    }
    return input;
  });
};
