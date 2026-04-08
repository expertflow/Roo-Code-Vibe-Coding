# GCP migration kickoff checklist

**BMAD:** Epic 1 Story **1.1**, **ADR-10** (Cloud Run target), **`gcp-directus-deployment.md`**.

## 1. Backup (local Directus) — done via repo scripts

| Artifact | Path | Notes |
|----------|------|--------|
| **Dated backup** | `projects/internal-erp/directus/schema-backup-2026-03-16.json` | Point-in-time metadata export. |
| **Canonical snapshot** | `projects/internal-erp/directus/schema.json` | Story **1.7** file — commit when ready. |

Commands used:

```powershell
cd projects\internal-erp\directus
.\scripts\snapshot-schema.ps1 schema-backup-2026-03-16.json
.\scripts\snapshot-schema.ps1 schema.json
```

**Not included in `schema snapshot`:** uploaded files under **`uploads/`** (gitignored). For a full backup, copy `uploads/` to durable storage (GCS bucket, zip on NAS) if you rely on local files.

**Database:** `bidstruct4` already lives on **Cloud SQL** — use **Cloud SQL automated backups / export** for DB-level DR (separate from Directus metadata snapshot).

**Directus CLI note:** Snapshot may warn that **`ChatLogs`** has no primary key and is ignored — expected until that table is fixed.

---

## 2. Start migration to GCP (engineering order)

1. **Choose first production shape**
   - **Target (ADR-10):** **Cloud Run** + **Secret Manager** + **Cloud SQL connector / proxy**.
   - **GCE VM path (step-by-step):** **`docs/gcp-directus-deployment.md`** — IAM, firewall, `gcloud compute instances create`, `scripts/gcp-vm-bootstrap.sh`, `docker-compose.gcp-vm.example.yml`, **`.env.gcp-vm.example`**.

2. **Secrets (prod)**  
   Create Secret Manager entries: `KEY`, `SECRET`, `DB_PASSWORD` (and `AUTH_GOOGLE_CLIENT_SECRET` if SSO). Map into the Cloud Run service or VM startup — **PRD NFR2**.

3. **Networking**  
   Cloud SQL **private IP** (recommended) or authorized networks; VPC connector for Cloud Run if required.

4. **Deploy image**  
   Build/push the same **`Dockerfile`** (regnamespace patch) to **Artifact Registry**; reference in Cloud Run or pull on VM.

5. **Environment**  
   Set **`PUBLIC_URL`** to the final **https://** URL. Update **Google OAuth** origins + redirect URIs — `docs/story-1-8-google-sso.md`.

6. **Post-deploy**  
   Restart once; run **`python scripts/sync_directus_from_postgresql.py`** and **`purge_stale_directus_ui.py`** if metadata drifted between envs.

7. **Optional:** `npx directus schema apply` — **only** when intentionally overwriting metadata on a target DB (dangerous on shared prod — review Directus docs).

---

## 3. References

- `docs/gcp-directus-deployment.md` — VM / TLS / proxy
- `_bmad-output/planning-artifacts/migration-plan-postgres-directus-cloud-wave1.md` — waves
- `_bmad-output/implementation-artifacts/1-1-docker-compose-google-cloud-run-setup.md` — Story 1.1
- `README.md` — Story **1.7** schema snapshot
