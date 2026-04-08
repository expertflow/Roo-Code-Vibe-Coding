---
stepsCompleted: [1]
inputDocuments:
  - _bmad-output/planning-artifacts/prd-ExpertflowInternalERP-2026-03-16.md
  - _bmad-output/planning-artifacts/architecture-BMADMonorepoEFInternalTools-2026-03-15.md
workflowType: 'prd'
project_name: 'ExpertflowCRM'
user_name: 'Andreas'
date: '2026-03-26'
---

# Product Requirements Document — Expertflow CRM Sync (Shard 1.0)

> **Note:** Please verify against `antigravity-implementation-history.md` for alternative implemented methodologies (e.g., *HubSpot-like CRM Integration Plan*), as previous Antigravity session plans may supersede or contradict these requirements.

**Author:** Andreas
**Date:** 2026-03-26
**Status:** Initial Draft - Modular Segment
**Scope:** CRM Integration (Gmail Sync, GDrive Routing, HubSpot-style UI)

---

## 1. Executive Summary

This modular specification defines the requirements for the **Expertflow CRM Sync** module. While leveraging the core **Directus/PostgreSQL** architecture of the Internal ERP, the CRM exists as a logically separate functional segment focused on interaction history management and automated document routing.

The goal is to provide **HubSpot-like visibility** into customer interactions (Emails, Calls, Meetings) by synchronizing data from Gmail and organizing attachments within a structured Google Drive hierarchy based on the Contact-Company-LegalEntity relationship.

## 2. Shared Technical Foundation

The CRM module operates over the shared Expertflow Internal ERP infrastructure:
- **Database:** PostgreSQL (`bidstruct4`) at IP 213.55.244.201.
- **Backend:** Directus v11 (self-hosted).
- **Storage:** Google Drive (via `LegalEntity.DocumentFolder`).
- **Auth:** Google Service Account for API access.

## 3. Core CRM Functional Requirements

### 3.1 Interaction Sync (Gmail)

**CRM-FR-01 (Gmail Sync Backend):** The system SHALL implement a background polling hook to ingest emails from CRM-monitored inboxes every 5 minutes (Phase 1).
- **Persistence:** Emails SHALL be stored in the **`Journal`** collection.
- **Attribution:** New entries SHALL be automatically linked to the corresponding **`Contact`** or **`Company`** based on the email sender/recipient.

**CRM-FR-02 (Journal Polymorphism):** All CRM interactions SHALL use the `Journal` collection with:
- `JournalLink.collection` set to `Contact` or `Company`.
- `` set to `Email`, `Call`, `Meeting`, or `Note`.
- Metadata such as `Subject`, `Body`, `From`, `To`, and `InteractionDate`.

### 3.2 Attachment Management (GDrive)

**CRM-FR-03 (Resolution Chain Routing):** Attachments extracted from emails SHALL be routed to Google Drive.
- **Logic:** Resolve target folder via **`Contact` -> `Company` -> `LegalEntity.DocumentFolder`**.
- **Fallback:** If the chain is broken, route to the **"Global CRM Inbox"** folder.

**CRM-FR-04 (Evidence Linking):** Each stored attachment SHALL be represented as a `Journal` record with a `ResourceURL` pointing to the GDrive location, linked as a child to the parent interaction record.

### 3.3 CRM UISurface

**CRM-FR-05 (Activity Timeline):** Provide a custom Directus interface mimicking the HubSpot interaction timeline.
- **Features:** Chronological sorting, vibrant interaction icons, threaded email views, and integrated attachment previews.

## 4. CRM-Specific Logic & Constraints

**CRM-NFR-01 (Privacy inheritance):** Synced interactions SHALL inherit the RLS/Visibility policies of their parent `Contact` or `Company`.
- **Constraint:** Access to a contact's email history implies access to the `Contact` record itself.

**CRM-A1 (Company Stub):** For Phase 1, unlinked contacts SHALL require manual association to a `Company` for LegalEntity folder resolution.

## 5. Success Metrics

| Metric | Target |
|--------|--------|
| Sync Latency | < 5 minutes |
| Routing Accuracy | 100% (with fallback) |
| UI Parity | Visually similar to HubSpot |

