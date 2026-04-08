# BankStatement allocation views — legacy source (traceability)

**Origin:** User-provided export; original filename: `# BankStatement Allocation Views in Apps.md`  
**Purpose:** Verbatim preservation for PRD traceability. **Normative product text** is **`prd-ExpertflowInternalERP-2026-03-16.md`** **FR45** (+ **FR6** / **FR9** / **FR10** / **FR16**).  
**Alignment discussion:** See [`bank-statement-allocation-prd-alignment.md`](./bank-statement-allocation-prd-alignment.md).

---

# Bank Statement

# BankStatement Allocation Views (legacy internal tooling)

BankStatement reconciliation

Create a view that lists only BankStatements for which no Transaction has been created, or where the Transaction doesn't have both OriginAccount and DestinationAccount set.

## Create Transaction if not existing

When user chooses a BankStatement:
System creates a Transaction if it doesn't exist yet. If BankStatement.Amount is negative, Transaction.OriginAccount is set to BankStatement.Account, otherwise sets Transaction.DestinationAccount to BankStatement.Account. Copies absolute value of BankStatement.Amount to Transaction.Amount. Sets Transaction.Date to BankStatement.Date. Sets Transaction.Description to BankStatement.Description.

## Show invoices

Shows Invoices whose Transactions haven't been allocated yet and that roughly (+-5%) match the Amount and either the Transaction.OriginAccount or Transaction.DestinationAccount.
If user selects an invoice, copy either the missing OriginAccount or DestinationAccount from Invoice to Transaction. System then creates an entry in the allocation table joining that transaction and that invoice. User can edit the Allocation, for example accept the TransferLoss (or creates follow-up invoice manually). System suggests copies from Invoice to Transaction the missing pieces (Project, Description)

## if no matching invoice, show matching accounts

If no matching invoice is found, system verifies whether the BankStatement.Description is similar to earlier BankStatement.Descriptions, where the Counterparty (OriginAccount or DestinationAccount) was already selected.
If no previous similar BankStatement.Description exist, system shows Accounts whose name is similar to the name of the BankStatement.Description.

User picks a Counterparty, can select amongst the existing accounts or create a new account.

## End status:

BankStatement is linked to a Transaction.
Transaction has both OriginAccount, DestinationAccount and Project set.
Transaction is allocated to an Invoice if such an invoice exists via the Allocation table.
