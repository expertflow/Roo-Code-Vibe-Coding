# Banking spreadsheet import — legacy source (traceability)

**Origin:** User-provided export; original filename: `# ImportBankSpreadsheetToBankStatement.md`  
**Purpose:** Verbatim preservation for PRD traceability. **Normative product text:** **`prd-ExpertflowInternalERP-2026-03-16.md`** **FR46** (+ **FR6**–**FR8**).  
**Security:** Do not commit real bank credentials, API keys, or database passwords in notebooks, scripts, or this repo (**PRD NFR2**).

---

# Banking Spreadsheet import

Don't store any passwords in colab notebook or in the directory of this tool.

## Preparation of BankStatement table in BS4

Many bank accounts have up to four columns of additional data for a single transaction. Increase the number of description fields in BankStaement from currenty one to four.

## General interface for each bank

The first step is to import external bank statements into the BS4 database. Expertflow has multiple bank accounts (tied to legalentity type Internal), each one with it's own format of bank statement (spreadsheet or .csv file).

I will be asking you in the future to re-import new spreadsheets for each of the bank accounts, so this will be a repetitive process executed with Gemini CLI, and I will be providing you with the new spreadsheets for you to import and you should then determine which Internal bank account this sheet corresponds to and import to the BankStatement table.

The first step is to transform the data from the bank spreadsheet so they are normalized to a common format.
Maybe store the import script in a colab.google.com notebook, so it can easily be invoked by anybody.

## Deduplication and human validation

Then, compare the existing BankStatements with each transaction in the bank spreadsheet, and import those that don't exist yet. Deduplication should be done on the basis of the amount, data and certain descriptior fields or identifiers that might be unique for each type of bank spreadsheet that you integrate with.

## Store unique local file and human validation

Create a csv file of all bank spreadsheet entries that you intend to import to BankStatements, and store this in the form of a csv file that contains the bank name and date of export, so I can review the file. Stop the process there and only proceed if I explicitly give you an additional instruction to execute the import to BS4 BankStatement table.
