# Legal Entity Insights & Dashboard Architecture

## Objective
Provide expert-level financial and operational visibility into each Corporate Legal Entity across Expertflow by unifying Accounts, Open Invoices, and Transactions natively inside the Directus ERP.

## Components

### 1. Global Insights Dashboard
A Directus Insights Dashboard ("Legal Entity Overview") was created to allow filtering by Legal Entity.
- Three specialized Panels load `Account`, `Invoice`, and `Transaction` data.
- They utilize Directus Global relational filters mapped specifically against the scalar `LegalEntity.id`.

### 2. Legal Entity Item View (M2M Data Grids)
To fulfill the requirement of showing real-time, nested `Invoice` and `Transaction` grids on the Legal Entity Data Entry screen, we bypassed Directus limitations surrounding SQL Proxies/Views by leveraging a pure **Physical Junction Table + Postgres Trigger** strategy.

#### Junction Tables
Two physical bridging tables exist within the database:
- `LegalEntity_Invoice`: Links a Legal Entity to an Invoice.
- `LegalEntity_Transaction`: Links a Legal Entity to a Transaction.

#### Postgres Background Triggers
We attached automated background PL/pgSQL triggers (`sync_invoice_legal_entities`, `sync_transaction_legal_entities`) to both the `Invoice` and `Transaction` collections.
- Upon strictly ANY insertion or update to `OriginAccount` or `DestinationAccount` inside an Invoice or Transaction, the DB recursively queries the `Account` table to isolate that Account's `LegalEntity`.
- It dynamically maps this parent Legal Entity ID perfectly into the physical Junction Table, meaning the relational links are kept exactly 1:1 without manual intervention.

#### Directus Interface Overrides
Through standard Directus schema tables (`directus_fields` and `directus_relations`), we registered the junction collections and stitched them directly as M2M `list-m2m` Alias interfaces.
- `invoices` alias: M2M linking to `LegalEntity_Invoice` junction.
- `transactions` alias: M2M linking to `LegalEntity_Transaction` junction.
- The layout options natively unpack these complex joins into visually pleasing standard data grids, showing exactly `Amount`, `Currency`, `Description`, `Status`, and raw `Account` linkage IDs directly on the Legal Entity page!

## Maintenance 
- Directus caching governs the Layout JSONs in `directus_fields`. If fields are ever heavily modified or drop down options change, `POST /utils/cache/clear` or a docker container restart clears the schema reflection.
- The PostgreSQL Triggers are strictly immune to Directus API operations and strictly govern logical synchronization natively on the lowest database tier.
