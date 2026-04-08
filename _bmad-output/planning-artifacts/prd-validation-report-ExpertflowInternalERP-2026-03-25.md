---
validationTarget: '_bmad-output/planning-artifacts/prd-ExpertflowInternalERP-2026-03-16.md'
validationDate: '2026-03-25'
inputDocuments:
  - projects/internal-erp/vision.md
  - docs/governance.md
  - schema_dump_final.json
  - _bmad-output/planning-artifacts/architecture-BMADMonorepoEFInternalTools-2026-03-15.md
  - _bmad-output/planning-artifacts/identity-provider.md
  - _bmad-output/planning-artifacts/data-admin-surface-requirements.md
validationStepsCompleted:
  - step-v-01-discovery
  - step-v-02-format-detection
  - step-v-03-density-validation
  - step-v-04-brief-coverage-validation
  - step-v-05-measurability-validation
  - step-v-06-traceability-validation
  - step-v-07-implementation-leakage-validation
  - step-v-08-domain-compliance-validation
  - step-v-09-project-type-validation
  - step-v-10-smart-validation
  - step-v-11-holistic-quality-validation
  - step-v-12-completeness-validation
validationStatus: COMPLETE
holisticQualityRating: '4/5'
overallStatus: Warning
additionalReferences: []
---

# PRD Validation Report

**PRD being validated:** `_bmad-output/planning-artifacts/prd-ExpertflowInternalERP-2026-03-16.md`  
**Validation date:** 2026-03-25  
**Validator role:** Validation Architect / QA (BMAD workflow `validate-prd`)

## Input documents

| Document | Loaded |
|----------|--------|
| PRD (self) | Yes |
| `projects/internal-erp/vision.md` | Assumed present per PRD frontmatter (not re-verified byte-for-byte in this run) |
| `docs/governance.md` | As above |
| `schema_dump_final.json` | As above |
| `architecture-BMADMonorepoEFInternalTools-2026-03-15.md` | As above |
| `identity-provider.md` | As above |
| `data-admin-surface-requirements.md` | As above |
| Product Brief | None in frontmatter — Step 4 N/A |

## Validation findings

### Format detection

**PRD structure (## headers, order):**

1. Executive Summary  
2. Scope & Boundaries  
3. User Journeys  
4. Target Users & Access Control Model  
5. Functional Requirements  
6. Non-Functional Requirements  
7. Data Model Reference  
8. Success Metrics & Acceptance Criteria  
9. Open Questions & Assumptions  

**BMAD core sections present**

| Core section (BMAD) | PRD mapping | Status |
|---------------------|-------------|--------|
| Executive Summary | §1 | Present |
| Success Criteria | §8 Success Metrics & Acceptance Criteria | Present (label variant) |
| Product Scope | §2 Scope & Boundaries | Present |
| User Journeys | §3 | Present |
| Functional Requirements | §5 | Present |
| Non-Functional Requirements | §6 | Present |

**Format classification:** **BMAD Standard** (6/6 core section intent satisfied).  
**Core sections present:** 6/6  

---

### Information density validation

**Conversational filler:** 0 occurrences of scanned patterns (`In order to`, `It is important to note`, `The system will allow users to`, etc.).  

**Wordy phrases:** 0 occurrences of scanned patterns (`Due to the fact that`, `In the event of`, `At this point in time`, etc.).  

**Redundant phrases:** 0 occurrences of scanned redundant intensifiers (`Past history`, `Absolutely essential`, etc.).  

**Total violations:** 0  

**Severity:** **Pass**  

**Recommendation:** PRD maintains high information density; normative **SHALL** style is appropriate for this regulated internal-ERP context.

---

### Product brief coverage

**Status:** N/A — No Product Brief was listed in PRD `inputDocuments`.

---

### Measurability validation

**Totals:** ~71 numbered FR / FR.x lines (including dotted IDs such as FR46.6); ~14 NFR lines.

**Format (strict BMAD “[Actor] can [capability]”):** The PRD consistently uses **EARS / RFC-style “The system SHALL …”** and role-matrix language. This is **acceptable for enterprise ERP** but **differs from the strict template** in step-v-05, so count as **format drift**, not hard failure.

**Subjective adjectives:** No matches for `easy`, `fast`, `simple`, `intuitive`, `user-friendly`, `quick`, `efficient` (unqualified) in a quick scan.

**Vague quantifiers:** Controlled use of **multiple** / **many** / **some** (e.g. FR46 multi-bank accounts, FR12 many Journal rows, FR291 “some roles”). Most are tied to named collections or bounded behaviors — **low risk**; a few **some** usages (e.g. layout visibility) are slightly soft.

**Implementation terms in FR/NFR:** Extensive references to **Directus**, **Docker**, **PostgreSQL**, **Cloud Run**, **Google Cloud** — see Implementation Leakage section; counted there rather than double-penalized.

**NFR metrics:** Several NFRs include concrete targets (e.g. **NFR5** 5s / 10k rows). Others are policy-complete but not numerically bounded (e.g. dual-layer security) — **appropriate** for security architecture but weaker on strict “metric + measurement method” template.

**FR violations total (format drift + minor vague terms):** ~**8–12** informational (dominated by SHALL-vs-actor format).  

**NFR violations total:** ~**3–5** informational (missing explicit measurement method on a subset).  

**Combined severity:** **Warning** (usable; not Critical).

**Recommendation:** If you want strict BMAD measurability scoring, add a short **“Requirement style”** note in the PRD declaring EARS/SHALL as canonical for this product. Optionally add measurement hooks for policy NFRs (e.g. “verified by penetration test / access review quarterly”).

---

### Traceability validation

**Executive Summary → Success criteria (§8):** **Intact** — Phase 1 strategy, security, and Directus-first delivery align with acceptance themes in §8.

**Success criteria → User journeys:** **Mostly intact** — Finance, HR, Employee, Executive, Line Manager journeys map to FR clusters (ledger, HR, self-service).

**User journeys → FRs:** **Strong** — Role matrix (§4) and FR33/FR40/FR41 bind journeys to enforcement.

**Scope → FR alignment:** **Intact** — Out-of-scope CPQ/CRM called out in §2; FRs focus on in-scope modules.

**Orphan FRs:** **Few** — Some cross-cutting FRs (e.g. platform FR1–FR5) trace to **executive / NFR** objectives rather than a single persona sentence; **acceptable**.

**Notable post-change coherence:** **FR40.1**, **FR46.6**, and **2026-03-24** executive note align with Architecture **ADR-16** and Story **3-1** direction.

**Total traceability issues:** **0 Critical**, **2 Informational** (implicit trace for a few infrastructure FRs).

**Severity:** **Pass**

**Recommendation:** Optional traceability matrix spreadsheet for auditors; not required for BMAD pass.

---

### Implementation leakage validation

**Category counts (capability-relevant vs leakage):** This PRD **intentionally** names the Phase 1 stack (**Directus v11**, **Docker**, **PostgreSQL** / `bidstruct4`, **Cloud SQL Auth Proxy**, **Cloud Run**, **Secret Manager**, **REST API**). For a **brownfield schema-locked** program, that is **product constraint**, not accidental leakage.

| Category | Count (indicative) | Notes |
|----------|-------------------|--------|
| Databases (PostgreSQL, bidstruct4) | Many | Required for scope |
| Infrastructure (Docker, Cloud Run, GCP) | Many | Required for deployment story |
| Product platform (Directus) | Many | Core deliverable |
| Libraries / alternate frontends | Low | e.g. deferred Lovable/React mentioned as **deferred** |

**Total “pure” leakage violations** (technology with no requirement justification): **~0**  
**Total stack-specific statements:** **High** — if judged against **generic** PRD purity, severity **Warning**; if judged as **constrained internal ERP**, **Pass**.

**Severity:** **Warning** (template strictness) / **Pass** (brownfield intent)

**Recommendation:** Keep stack names in **§5.1 / NFRs**; avoid introducing **new** implementation choices in FRs without moving rationale to Architecture.

---

### Domain compliance validation

**PRD frontmatter:** No `classification.domain` field.

**Assessment per workflow:** Treated as **general / low complexity** for **CSV-driven mandatory sections**.

**Content note:** Substantively the product is **internal financial + HR ERP** (banking, payroll, RLS). The PRD already contains **strong security, audit, and segregation** language (**NFR1**, **NFR8**, **FR40**, **FR12** URL inheritance). It does **not** include a separate **fintech compliance matrix** (PCI/SOC2 checklist) as a dedicated section.

**Severity:** **Pass** against workflow gate; **Informational** for regulated-org stakeholders: consider a **short compliance appendix** if Legal requests explicit control mapping.

---

### Project-type compliance validation

**PRD frontmatter:** No `classification.projectType` (workflow default: **web_app**).

**Required sections (from `project-types.csv` for web_app):** `browser_matrix`, `responsive_design`, `performance_targets`, `seo_strategy`, `accessibility_level` — **not** present as explicitly titled sections.

**Partial coverage:** **NFR5** (performance), **NFR14** (admin UX), Phase 1 Directus-only strategy, deferred SPA — partially substitute for `performance_targets` / `browser_matrix`.

**Compliance score (literal CSV):** **~40–50%**  
**Severity:** **Warning**

**Recommendation:** Add a **short §2.x Phase 1 clients** subsection: supported browsers (if any policy), accessibility target (e.g. WCAG intent for Admin), SEO N/A for internal tool.

---

### SMART requirements validation

**Method:** Representative assessment across **§5** (not every FR scored 1–5 in this report — full grid would be ~355 cells).

**Pattern:** FRs are **Specific** and **Relevant**; **Measurable** varies (policy FRs vs timed NFR-linked FRs); **Attainable** generally credible for Phase 1; **Traceable** strong after recent bank-statement amendments.

**Approximate distribution (expert estimate):**

- All SMART dimensions ≥ 3: **~75–85%** of FRs  
- Any dimension &lt; 3 (often **Measurable**): **~15–25%**  

**Flag examples (Measurable &lt; 3 without further quantification):** Some **MAY** / **SHOULD** UX statements; **“clear error”** in FR46.6 (good operator intent; could add test scenario).

**Severity:** **Warning**

**Recommendation:** For top-risk flows (bank import, reconciliation), add **acceptance scenarios** in §8 or story files — PRD stays lean.

---

### Holistic quality assessment

**Document flow & coherence:** **Good** — Executive → Scope → Personas → FR/NFR → Success → Assumptions reads logically; recent **2026-03-24** bank note reduces drift vs Architecture.

**Dual audience:**

- **Humans:** Strong for **Finance/HR/Implementers**; executives may want a one-page **OKR** summary (optional).  
- **LLMs:** Strong — numbered FRs, stable anchors (**FR40.1**, **FR46.6**), cross-links to Architecture and identity doc.

**BMAD principles:**

| Principle | Status | Notes |
|-----------|--------|--------|
| Information density | Met | |
| Measurability | Partial | Policy-heavy FRs |
| Traceability | Met | |
| Domain awareness | Partial | Implicit fintech/ERP |
| Anti-patterns | Met | Low filler |
| Dual audience | Met | |
| Markdown structure | Met | Consistent `##` |

**Principles met:** **5–6 / 7** (depending on strictness on domain appendix)

**Overall quality rating:** **4/5 — Good** (strong internal ERP spec; minor template gaps vs generic web_app CSV)

**Top 3 improvements**

1. **Frontmatter classification** — Add optional `classification.domain` / `classification.projectType` and a one-line **browser/accessibility** statement for web_app CSV alignment.  
2. **Project-type sections** — Explicit **performance / client** subsection referencing NFR5 and internal-only SEO stance.  
3. **Requirement style note** — Declare **SHALL/EARS** as canonical to close measurability workflow gap vs “[Actor] can”.

---

### Completeness validation

**Template variables:** **None** found (`{{`, `{placeholder}`). **TBD** appears in **§9 assumptions** table (A5) — **acceptable** as open assumption, not a draft template leak.

**Content completeness:**

| Section | Status |
|---------|--------|
| Executive Summary | Complete |
| Success criteria (§8) | Complete |
| Scope (§2) | Complete |
| User journeys (§3) | Complete |
| Functional requirements (§5) | Complete |
| Non-functional requirements (§6) | Complete |

**Frontmatter:**

| Field | Status |
|-------|--------|
| stepsCompleted | Present |
| inputDocuments | Present |
| date | Present |
| classification.domain | Missing |
| classification.projectType | Missing |

**Frontmatter completeness:** **3/5** relevant fields (if classification expected)

**Overall completeness:** **~92%**

**Severity:** **Pass** with informational frontmatter gap

---

## Executive summary of validation

| Check | Result |
|-------|--------|
| Format | BMAD Standard (6/6) |
| Information density | Pass |
| Product brief | N/A |
| Measurability | Warning |
| Traceability | Pass |
| Implementation leakage | Warning (strict) / Pass (brownfield) |
| Domain compliance | Pass (workflow); informational for fintech depth |
| Project-type (web_app default) | Warning |
| SMART quality | Warning |
| Holistic quality | **4/5 Good** |
| Completeness | Pass |

**Overall status:** **Warning** — PRD is **fit for implementation** and **aligned** with recent Architecture/Story **3-1** changes; remaining gaps are **template/metadata** and **explicit web_client** packaging, not logical holes.

**Critical issues:** None  

**Warnings:** Measurability template vs EARS; project-type CSV literal sections; heavy stack naming (justified for brownfield).

**Strengths:** Dense FR set, strong security traceability (**FR33/FR40/FR40.1**), bank import requirements (**FR46.6**) explicit, good LLM parseability.

---

## Next steps (BMAD menu)

- **[R]** Walk this report section-by-section with the team.  
- **[E]** Run **Edit PRD** workflow using these findings for targeted edits.  
- **[F]** Quick wins: add `classification` block + short §2.x client/browser note.  
- **[X]** Close validation; file stored at this path for audit.

**Validation report path:** `_bmad-output/planning-artifacts/prd-validation-report-ExpertflowInternalERP-2026-03-25.md`
