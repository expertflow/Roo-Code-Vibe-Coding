---
stepsCompleted: [1, 2]
inputDocuments:
  - _bmad-output/planning-artifacts/prd-CRM-HubSpotSync-2026-03-26.md
  - _bmad-output/planning-artifacts/epics.md
---

# ExpertflowCRM - Epic 7 Story Breakdown

## Epic 7: CRM Core & Gmail Sync Infrastructure

Decompose the sync engine and polymorphic journaling requirements into implementable stories.

### Story 7.1: Gmail Authentication (Service Account)
As a System Admin,
I want the CRM to authenticate with Google APIs using a Service Account,
So that interactions can be synced without individual user consent.

**Acceptance Criteria:**

**Given** a JSON key at `projects/internal-erp/directus/.secrets/expertflowerp-5e9250b3ab23.json`
**When** the CRM Sync service initializes
**Then** it successfully authenticates with the Gmail API via Domain-Wide Delegation
**And** it can impersonate configured CRM mailboxes (e.g., `sales@expertflow.com`).

**Linkable requirements:** CRM-FR-01, NFR2.

### Story 7.2: Gmail Polling & Incremental Sync
As a Sales Representative,
I want interactions to sync within 5 minutes,
So that I have a near-real-time view of communication.

**Acceptance Criteria:**

**Given** a set of monitored CRM inboxes
**When** the background job runs every 300 seconds
**Then** it identifies new emails received since the last `maxHistoryId` or `timestamp`
**And** it markers successful syncs to avoid duplicates in the next run.

**Linkable requirements:** CRM-FR-01, Success Metrics.

### Story 7.3: Polymorphic Journal Creation (Email)
As a CRM System,
I want to transform Gmail messages into `Journal` entries with correct polymorphic references,
So that they appear in the activity timeline of the right Contact.

**Acceptance Criteria:**

**Given** an incoming email from `someone@external.com`
**When** the system finds a `Contact` with `email = 'someone@external.com'`
**Then** it creates a `Journal` entry with:
  - `JournalLink.collection`: "Contact"
  - `JournalLink.item`: <Contact_UUID>
  - ``: "Email"
  - `Subject`: <Email_Subject>
  - `Body`: <Email_Body_HTML_Stripped>
  - `Date_Created`: <Email_Date_Header>

**Technical Constraint:** Use `directus_users` email for internal user matching if applicable.

**Linkable requirements:** CRM-FR-02.

### Story 7.4: Privacy Inheritance for Interactions (NFR15)
As a Security Officer,
I want Journal interaction visibility to be driven by the parent Contact/Company permissions,
So that we adhere to zero-trust principles.

**Acceptance Criteria:**

**Given** a `Journal` record linked to `Contact X`
**When** a user's Directus role or RLS denies access to `Contact X`
**Then** the `Journal` record is excluded from all API and UI results for that user.

**Linkable requirements:** CRM-NFR-01.

