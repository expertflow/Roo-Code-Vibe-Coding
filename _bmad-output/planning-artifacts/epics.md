---
stepsCompleted: [1]
inputDocuments:
  - _bmad-output/planning-artifacts/prd-ExpertflowInternalERP-2026-03-16.md
  - _bmad-output/planning-artifacts/architecture-BMADMonorepoEFInternalTools-2026-03-15.md
---

# ExpertflowInternalERP - Epic Breakdown

> **Note:** Several story implementations and logic updates have been overridden or alternatively implemented during Antigravity quick-flow sessions. Please refer to `antigravity-implementation-history.md` for consolidated implementation artifacts that may supplement or contradict these epics.

## Overview

This document provides the complete epic and story breakdown for the HubSpot-style CRM integration, decomposing the requirements from the PRD and Architecture documents into implementable stories. This work focuses on Gmail interaction syncing, polymorphic journaling, and automated GDrive attachment routing.

## Requirements Inventory

### Functional Requirements

- **FR50 (Gmail Sync Hook):** Directus backend hook to sync Gmail interactions into `Journal`.
    - Entries stored with `JournalLink.collection` = `Contact` or `Company`.
    - `` = `Email`.
    - Inheritance of RLS from parent.
- **FR51 (Attachment Storage & GDrive Routing):** Extract attachments to Google Drive.
    - Resolve target via `Contact` -> `Company` -> `LegalEntity.DocumentFolder`.
    - Fallback: "Global CRM Inbox" folder.
    - `Journal` entry for each attachment with `ResourceURL`.
- **FR52 (HubSpot-style Activity Timeline):** Custom Directus Interface/Module for `Journal` timeline.
    - Mimic HubSpot UI (vibrant icons, threaded views, previews).
    - Support: Email, Call Log, Meeting Note, System Notification.

### NonFunctional Requirements

- **NFR15 — CRM Interaction Privacy:** Journals MUST follow parent RLS (`Contact`/`Company`).
- **Additional NFRs (Architectural):**
    - Google Service Account Auth for Gmail/GDrive.
    - Polling mechanism (5-minute intervals) for Phase 1.

### Additional Requirements

- **Metadata Sync:** Capture email headers (Subject, From, To, Date) into the Journal entry for timeline rendering.
- **Unlinked Contact Handling:** Heuristic for matching incoming emails to existing Contacts (via email address) or creating new ones.

### UX Design Requirements

- **HubSpot Parity:** The "Activity Timeline" must visually approximate HubSpot's interaction history (vibrant icons, threaded views, clickable attachments).

### FR Coverage Map

| Requirement | Epic | Stories |
|-------------|------|---------|
| FR50        | Epic 7: CRM Core & Gmail Sync | 7.1, 7.2, 7.3 |
| FR51        | Epic 8: GDrive Attachment Routing | 8.1, 8.2, 8.3 |
| FR52        | Epic 9: HubSpot-Style UI | 9.1, 9.2 |
| NFR-CANONICAL | Epic 10: Schema Maintenance | 10.1 |
| NFR15       | Epic 7/8/9 | Embedded in all stories |

## Epic List

1. **Epic 7: CRM Core & Gmail Sync Infrastructure** - Backend sync engine and Journal polymorphic extensions.
2. **Epic 8: GDrive Attachment & LegalEntity Routing** - Automated filing of email attachments based on the Contact-Company-LegalEntity hierarchy.
3. **Epic 9: HubSpot-Style Activity Timeline** - Custom UI for rendering interaction history within Directus.
4. **Epic 10: Schema Maintenance & Canonical Verification** - Audit of the PostgreSQL schema against the canonical STTM definition.

---

## Epic 7: CRM Core & Gmail Sync Infrastructure

Implement the backend synchronization service that polls Gmail for interactions and persists them into the polymorphic `Journal` collection.

### Story 7.1: Gmail Synchronization Hook
As a CRM System,
I want to poll configured Gmail accounts every 5 minutes,
So that interaction history is kept up-to-date in Directus.

**Acceptance Criteria:**

**Given** a valid Google Service Account with Domain-Wide Delegation
**When** the background job executes
**Then** it retrieving new emails from the CRM-monitored inbox(es)
**And** filters out internal/personal communications based on domain exclusion lists.

### Story 7.2: Polymorphic Journal Persistence
As a CRM System,
I want to save synced emails as `Journal` entries with `JournalLink.collection` "Contact" or "Company",
So that the interaction is correctly attributed in the CRM.

**Acceptance Criteria:**

**Given** an incoming email from `customer@example.com`
**When** a matching `Contact` row is found in Directus
**Then** a new `Journal` record is created with `JournalLink.collection='Contact'` and `JournalLink.item` of that contact
**And** the `` is set to 'Email'.

### Story 7.3: CRM Interaction Privacy (NFR15)
As a Security Officer,
I want scoped Journal entries to strictly follow parent RLS policies,
So that sensitive communications are only visible to authorized account owners.

**Acceptance Criteria:**

**Given** a user who does not have access to 'Company A'
**When** that user attempts to query `Journal` entries linked to 'Company A'
**Then** the API returns zero rows
**And** the Directus Admin UI hides these interactions from the timeline.

## Epic 8: GDrive Attachment & LegalEntity Routing

Implement the resolution logic to route files from emails into the correct `LegalEntity.DocumentFolder`.

### Story 8.1: LegalEntity Folder Resolution
As an Automation Engine,
I want to resolve the target GDrive folder by navigating the Contact -> Company -> LegalEntity path,
So that documents are stored in the correct organizational silo.

**Acceptance Criteria:**

**Given** an attachment for `Contact X`
**When** `Contact X` is linked to `Company Y`, and `Company Y` is linked to `LegalEntity Z`
**Then** the destination folder is retrieved from `LegalEntity Z.DocumentFolder`.

### Story 8.2: Attachment Uploader & ResourceURL
As a CRM System,
I want to upload attachments to GDrive and store their shareable URLs in the Journal,
So that users can preview files directly from the timeline.

**Acceptance Criteria:**

**Given** an attachment in a synced email
**When** the file is successfully uploaded to the resolved GDrive folder
**Then** a `Journal` entry is created with `JournalLink.collection='Journal'` (or parent) and the `ResourceURL` pointing to the GDrive file.

### Story 8.3: GDrive Storage Fallback
As an Administrator,
I want a fallback folder for unlinked entities,
So that no attachments are lost when the resolution chain is broken.

**Acceptance Criteria:**

**Given** an attachment where no LegalEntity can be resolved
**When** the system attempts to store the file
**Then** it uses the "Global CRM Inbox" folder defined in `.env`.

## Epic 9: HubSpot-Style Activity Timeline

Implement the visual surface for the CRM within the Directus Admin UI.

### Story 9.1: Activity Timeline Interface
As a Sales Representative,
I want a HubSpot-style chronological timeline of all activities for a Contact or Company,
So that I can quickly understand the history of our relationship.

**Acceptance Criteria:**

**Given** a Contact detail page
**When** the Activity Timeline interface is rendered
**Then** it displays `Journal` entries in descending chronological order
**And** uses distinct icons for Emails, Calls, and Notes.

### Story 9.2: Activity Threading & Previews
As a Sales Representative,
I want to see email threads and attachment previews within the timeline,
So that I don't have to leave the page to understand context.

**Acceptance Criteria:**

**Given** an Email entry in the timeline
**When** clicked, it expands to show the full body
**And** displays thumbnail previews for any linked `Journal` attachments.

---

## Epic 10: Schema Maintenance & Canonical Verification

Ensure the PostgreSQL database remains synchronized with the canonical STTM definitions and handle non-canonical UI helpers as database views.

### Story 10.1: PostgreSQL Canonical Schema Audit
As a Database Administrator,
I want to verify all PostgreSQL tables against the canonical mapping file,
So that the core schema remains clean and strictly follows the STTM definition.

**Acceptance Criteria:**

**Given** the canonical mapping file `projects/internal-erp/STTMMappingBidstruct4 (1).xlsx`
**When** a comparison is performed against the current `bidstruct4` PostgreSQL schema
**Then** any "non-canonical" fields (not present in the Excel file) must be identified
**And** the user must be notified of these exceptions.
**And** any identified exceptions (e.g. matching fields for `BankStatement` in Directus) must be re-implemented as PostgreSQL Views instead of table columns.


