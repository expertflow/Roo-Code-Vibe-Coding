# Migration plan — PostgreSQL → canonical model + Directus (cloud) — Finance / HR first slice

**Status:** Draft plan — align with **`prd-ExpertflowInternalERP-2026-03-16.md`**, **`architecture-BMADMonorepoEFInternalTools-2026-03-15.md`**, **`identity-provider.md`**.  
**Owner:** Andreas / program — update dates as waves complete.  
**Last updated:** 2026-03-16 (Wave 0.3b VM interim + BMAD cross-refs: 2026-03-23)  

**Coherence (schema ↔ PRD ↔ stories):** Use **`canonical-schema-prd-story-traceability.md`** — especially if **RBAC/RLS is already largely done**; focus remaining effort on **non-canonical field retirement** and **story coverage** for **A12** / **FR11** / **FR15** / **FR28**.

---

## 1. Purpose

Move from **today’s `bidstruct4` PostgreSQL** plus local/ad-hoc Directus toward the **canonical product shape** (PRD + Architecture) and **Directus on Google Cloud Run**, so **Finance** and **HR** can **productively** use:

| Priority | Capability | Collections / surfaces (canonical names) |
|----------|------------|------------------------------------------|
| **P0 — go-live slice** | Ledger + bank + cash visibility | `Account`, `LegalEntity`, `Project`, `Currency`, `CurrencyExchange`, `BankStatement`, `Transaction`, `Invoice`, `Allocation`, `Journal`, `Accruals` (Finance-only), Insights / reporting for **FR47** (cash) per PRD |
| **P0** | Security + RBAC | **Directus** roles + item filters; **PostgreSQL RLS** + `UserToRole` / `Role` / `RolePermissions`; **OIDC** per **`identity-provider.md`**; Directus **`sterile_dev`** (not `bs4_dev`) |
| **P1** | HR master + read paths | `Employee`, `EmployeePersonalInfo`, reference tables (`Seniority`, `Designation`, `department`) — **as needed** for Finance workflows and HR **read** on employee-ledger rows (**FR33**) |
| **P2 (defer for productivity milestone)** | Time, leave, tasks | `TimeEntry`, `Leaves`, `Task` — configure **after** P0 stable |
| **Out of scope for this milestone** | Ticketing, CRM, CPQ | `tickets`, `Deal`, etc. — **hidden** from navigation; no training investment |

---

## 2. Current state vs canonical target

### 2.1 Database (`bidstruct4`)

- **Brownfield:** Schema already exists; “migration” is **incremental alignment**, not a one-shot new database.
- **Canonical rules** (non-exhaustive — see PRD §5, §7, Architecture):
  - **`BankStatement.Transaction`** nullable until reconcile (**FR6**/**FR10**).
  - **No** canonical `Expense` for employee spend — **FR28** path (**`Transaction`/`Invoice` + `Journal`**) when you enable that flow.
  - **`Journal`** polymorphic evidence; deprecate parallel receipt columns where PRD says so (**A12**).
  - **`InternalCost`**: no `TimeEntryId`; monthly **FR43** when you turn on internal costing (**P2+** for job).
  - **RLS:** 12 sensitive tables enforced; Directus extension sets **`SET LOCAL ROLE`** + **`app.user_email`** (**ADR-13**, **NFR13**).

### 2.2 Directus

- **Target:** Same Docker image pattern as local → **Cloud Run**; **Cloud SQL** (existing instance or dedicated) via connector/proxy; **Secret Manager** for secrets (**Architecture** §2.2, §3.1, ADR-02/03/10).
- **Interim (BMAD Story 1.1 family, documented 2026-03):** **GCE VM + Docker Compose** + **Cloud SQL Auth Proxy** as a Compose service — **`projects/internal-erp/directus/docs/gcp-directus-deployment.md`**. Same image as local; use until Cloud Run (Wave 0.3) is live or for orgs that standardize on VM first.

### 2.3 Identity

- **Production:** External **OIDC/OAuth**; **JIT** for allowlisted domains (**NFR12**, **`identity-provider.md`**, Story **1.8**).
- **`UserToRole.User`** must match IdP-verified **email** used for RLS.

---

## 3. Guiding principles

1. **Security before features:** No cloud URL for Finance/HR until **RLS + Directus RBAC + IdP** path is proven for **at least one** Finance user and one HR user.
2. **Dual-layer zero-trust:** Directus permissions **and** PostgreSQL RLS (**NFR1**) — same rules, documented matrix (Architecture §5.2–5.3).
3. **Smallest shippable slice:** **Transactions, Invoices, BankStatements, cash reporting** + references; defer **time / holidays / CRM / tickets** from **training and support** perspective (collections may stay in DB but **hidden**).
4. **One database truth:** Avoid forked DBs; use **migrations** + feature flags in Directus (hidden collections, bookmarks).

---

## 4. Phased migration (waves)

### Wave 0 — Platform & secrets (no business UAT yet)

| # | Task | Outcome |
|---|------|---------|
| 0.1 | Confirm **Cloud SQL** instance, DB user **`sterile_dev`** for Directus runtime, **`bs4_dev`** break-glass only | Matches ADR-13 |
| 0.2 | **Secret Manager** entries: `DB_*`, Directus `KEY`/`SECRET`, IdP client secrets | No secrets in repo |
| 0.3 | **Cloud Run** service skeleton for Directus; health check; connect to Cloud SQL | Empty or stub Directus boots |
| 0.3b | *(Optional interim)* **GCE VM** + **`docker-compose.gcp-vm.example.yml`** (proxy sidecar + Directus) for shared URL — see **`projects/internal-erp/directus/docs/gcp-directus-deployment.md`**; Epic 1 **Story 1.1** artifact | Colleague access before 0.3 complete |
| 0.4 | Network: ingress policy (internal / IAP / VPN per org) | Documented |

---

### Wave 1 — Security & RBAC foundation (blocking)

| # | Task | Outcome |
|---|------|---------|
| 1.1 | Implement **Story 1.8** / **`identity-provider.md`**: OIDC with **JIT**; **`directus_users`** linked to email | Login works in cloud |
| 1.2 | **Directus extension** (or equivalent): **`SET LOCAL ROLE directus_rls_subject`** + **`SET LOCAL app.user_email`** on authenticated `items.*` | RLS active for API (**NFR13**) |
| 1.3 | **`UserToRole`** seeded for pilot **Finance** (role **115**) and **HR** (role **116**) test users | RLS tier correct in PostgreSQL |
| 1.4 | Create **five Directus roles**; map to app access; **collection-level** deny for out-of-scope domains (**Epic 2** pattern) | CPQ/CRM/tickets not visible |
| 1.5 | **Item-level filters** for **HR** on `Transaction`/`Invoice`/`BankStatement`/`Account` (**FR33**) and **Finance** unrestricted on finance tables | Matches PRD |
| 1.6 | **Regression tests:** HR cannot see Executive-ledger rows; baseline user cannot see Employee/Executive amount rows | Evidence recorded |

**Exit criteria — Wave 1:** Two pilot users (Finance + HR) can authenticate, pass RLS, and **see only** allowed collections/rows (even if tables are still sparse).

---

### Wave 2 — Canonical schema deltas on PostgreSQL (parallelizable with Wave 1 after 1.2)

| # | Task | Outcome |
|---|------|---------|
| 2.1 | Migration scripts: **`BankStatement.Transaction`** nullable if not already; constraints for **0–2** bank lines per `Transaction` (hooks + DB checks per Architecture) | FR6/FR10 |
| 2.2 | Drop or hide non-canonical columns per PRD (**A12**): legacy `Expense` UX off; receipt columns toward **`Journal`** | Reduced confusion |
| 2.3 | **`Employee.DefaultProjectId`** present if missing; **`Seniority.DayRate`** for **FR43** when you enable costing | FR22/FR24.1 |
| 2.4 | RLS policy audit: **either-leg** `Employee`/`Executive` on `Transaction`/`Invoice`/`Allocation` | FR40 |

**Exit criteria — Wave 2:** Migrations applied to **staging** Cloud SQL; no owner-access on Directus pool user.

---

### Wave 3 — Directus cloud: Finance + HR **productivity slice**

Register and configure **only** what pilots need (P0):

| Collection group | Finance | HR | Notes |
|------------------|---------|-----|--------|
| Reference / org | CRUD where PRD | Read | `LegalEntity`, `Account`, `Project`, `ProfitCenter`, `Currency`, `CurrencyExchange` |
| Bank + ledger | Full CRUD | Read employee-ledger only | `BankStatement`, `Transaction`, `Invoice`, `Allocation` |
| Accruals | Full CRUD | **No access** | **FR17**/**FR41** |
| Journal | Full CRUD | Scoped read | **FR12**/**FR41** |
| Insights | Cash dashboard per **FR47**/**FR47.9** (defaults OK) | If policy allows | May be **Finance-first**; exec later |
| HR master | Read (optional CRUD later) | Full CRUD | `Employee`, `EmployeePersonalInfo`, refs — **minimum** to support org context |

**Explicitly not in pilot training (P2 / hidden):**

- `TimeEntry`, `Leaves`, `Task` — leave **unregistered** or **hidden** in Admin for pilots until Wave 4.
- **Ticketing, CRM, CPQ** — **hidden** (PRD §2.2).

**Exit criteria — Wave 3:** Finance completes **import → reconcile → transaction** loop and **invoice** CRUD; HR can **look up employees** and **read** permitted ledger rows; **cash** panel visible to authorized roles per **FR47.1**.

---

### Wave 4 — HR operations & employee flows (lower priority per your note)

- `TimeEntry`, `Leaves`, `Task`, **FR28** spend flow, **FR43** monthly `InternalCost` job.
- Train HR/Employees after Wave 3 stable.

---

## 5. Directus → cloud checklist (condensed)

- [ ] Image build CI → Artifact Registry  
- [ ] Cloud Run: CPU/memory, min instances (if needed), **VPC connector** or **Cloud SQL connector**  
- [ ] Env vars from Secret Manager; **`DB_USER=sterile_dev`** in prod  
- [ ] `PUBLIC_URL` / CORS for IdP redirect URIs  
- [ ] Directus `schema.json` or bootstrap snapshot applied to **prod** metadata  
- [ ] Smoke: `POST /auth/login` (OIDC flow), `GET /items/Transaction` with RLS  
- [ ] Runbook: break-glass **`bs4_dev`**, rotation, who approves schema migration  

---

## 6. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| RLS bypass if extension fails open | Staging tests + monitoring; deny-by-default on sensitive collections in Directus |
| IdP email ≠ `UserToRole.User` | Automated check on login; admin alert |
| Insights can’t do FR47.9 params | PRD allows **successor tool** — time-box spike; ship **defaults** first (**Architecture §10.5–10.7**) |
| Schema drift local vs cloud | Single migration pipeline; no hand-edited prod |

---

## 7. Traceability

| Artifact | Use |
|----------|-----|
| PRD | FR6–FR10, FR12–FR21, FR28–FR29, FR33, FR40–FR41, FR45–FR47, NFR1, NFR12–NFR13 |
| Architecture | ADR-02, 07, 10, 11, 12, 13, 14; §5 RBAC; §8 RLS |
| `identity-provider.md` | Production login contract |
| Epics | **1.x** platform, **2.x** RBAC, **3.x** bank/ledger, **6.x** Insights/cash |

---

## 8. Suggested next actions

1. **Name** pilot users + confirm IdP tenant (**Wave 1**).  
2. **Freeze** “P0 collection list” for Directus navigation (this doc §Wave 3).  
3. **Schedule** RLS + OIDC integration test in **staging Cloud SQL** before prod URL.  
4. Add **target dates** per wave in a copy of this file or Jira/Linear.

---

*This plan does not replace epics/stories; it sequences them for **cloud go-live with Finance/HR on ledger + cash first**.*
