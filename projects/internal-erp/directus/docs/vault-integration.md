# HashiCorp Vault Integration

This document explains how database passwords and secrets are fetched from HashiCorp Vault and injected into the project **without changing any existing implementation** (docker-compose.yml, .env.example, or application code remain untouched).

---

## Architecture

```
HashiCorp Vault
  └── secret/data/internal-erp/db
        ├── DB_PASSWORD          ← sterile_dev runtime password
        ├── BS4_DEV_PASSWORD     ← bs4_dev break-glass/migrations password
        ├── ADMIN_PASSWORD       ← Directus bootstrap admin password
        ├── ADMIN_EMAIL          ← Directus bootstrap admin email
        ├── DIRECTUS_KEY         ← Directus KEY (32-char random)
        ├── DIRECTUS_SECRET      ← Directus SECRET (long random)
        └── DIRECTUS_TOKEN       ← Directus static admin token (MCP)

         ↓  vault-fetch-secrets.ps1 / .sh

projects/internal-erp/directus/.env   ← read by docker-compose.yml (unchanged)
.roo/mcp.json                          ← read by Roo Code MCP servers (unchanged)
```

The fetch scripts are the **only new files**. Everything else (docker-compose.yml, .env.example, application code) is unchanged.

---

## Vault Secret Keys

Store the following keys at path `secret/data/internal-erp/db` in your Vault KV v2 engine:

| Key | Description |
|-----|-------------|
| `DB_PASSWORD` | Password for `sterile_dev` PostgreSQL user (Directus runtime) |
| `BS4_DEV_PASSWORD` | Password for `bs4_dev` PostgreSQL user (migrations / break-glass) |
| `ADMIN_PASSWORD` | Directus bootstrap admin password |
| `ADMIN_EMAIL` | Directus bootstrap admin email |
| `DIRECTUS_KEY` | Directus `KEY` — 32-character random string |
| `DIRECTUS_SECRET` | Directus `SECRET` — long random string |
| `DIRECTUS_TOKEN` | Directus static admin token (used by Roo Code MCP) |

### Writing secrets to Vault (one-time setup)

```bash
vault kv put secret/internal-erp/db \
  DB_PASSWORD="your_sterile_dev_password" \
  BS4_DEV_PASSWORD="your_bs4_dev_password" \
  ADMIN_PASSWORD="your_directus_admin_password" \
  ADMIN_EMAIL="admin@expertflow.com" \
  DIRECTUS_KEY="$(openssl rand -hex 16)" \
  DIRECTUS_SECRET="$(openssl rand -hex 32)" \
  DIRECTUS_TOKEN="your_directus_static_token"
```

---

## Usage

### Windows (PowerShell) — Local Dev

```powershell
# 1. Copy the vault config template
Copy-Item projects/internal-erp/directus/.env.vault.example `
          projects/internal-erp/directus/.env.vault

# 2. Edit .env.vault — set VAULT_ADDR and VAULT_TOKEN
notepad projects/internal-erp/directus/.env.vault

# 3. Load vault env vars into current shell
Get-Content projects/internal-erp/directus/.env.vault |
  Where-Object { $_ -match '^[^#].*=.*' } |
  ForEach-Object {
    $parts = $_ -split '=', 2
    [System.Environment]::SetEnvironmentVariable($parts[0].Trim(), $parts[1].Trim())
  }

# 4. Fetch secrets and write .env + .roo/mcp.json
cd projects/internal-erp/directus
.\vault-fetch-secrets.ps1

# 5. Start Directus (unchanged command)
docker compose up
```

**Self-signed TLS certificate** (Vault at `https://45.88.223.83:31313`):
```powershell
.\vault-fetch-secrets.ps1 -SkipTlsVerify
```

**Dry run** (preview without writing files):
```powershell
.\vault-fetch-secrets.ps1 -DryRun
```

---

### Linux / GCP VM (bash)

```bash
# 1. Copy the vault config template
cp projects/internal-erp/directus/.env.vault.example \
   projects/internal-erp/directus/.env.vault

# 2. Edit .env.vault — set VAULT_ADDR and VAULT_TOKEN
nano projects/internal-erp/directus/.env.vault

# 3. Load vault env vars into current shell
set -a && source projects/internal-erp/directus/.env.vault && set +a

# 4. Fetch secrets and write .env + .roo/mcp.json
cd projects/internal-erp/directus
bash vault-fetch-secrets.sh

# 5. Start Directus (unchanged command)
docker compose up
```

**Self-signed TLS certificate**:
```bash
VAULT_SKIP_TLS=true bash vault-fetch-secrets.sh
```

**Dry run**:
```bash
DRY_RUN=true bash vault-fetch-secrets.sh
```

---

## Files Created / Modified

| File | Status | Purpose |
|------|--------|---------|
| [`vault-fetch-secrets.ps1`](../vault-fetch-secrets.ps1) | **New** | Windows: fetch from Vault → write `.env` + `mcp.json` |
| [`vault-fetch-secrets.sh`](../vault-fetch-secrets.sh) | **New** | Linux/GCP VM: fetch from Vault → write `.env` + `mcp.json` |
| [`.env.vault.example`](../.env.vault.example) | **New** | Template for Vault credentials (committed, no real values) |
| [`docs/vault-integration.md`](./vault-integration.md) | **New** | This document |
| [`.gitignore`](../../../../.gitignore) | **Updated** | Added `.env.vault`, `.vault-token` exclusions |

### Files NOT changed

- `docker-compose.yml` — still reads `.env` via `env_file: .env`
- `.env.example` — still the blank template for reference
- `.roo/mcp.json` — structure unchanged; only credential values are refreshed
- All application code, extensions, SQL scripts — untouched

---

## Security Notes

- **`.env.vault`** is gitignored — never commit it
- **`.env`** is gitignored — never commit it
- **`.roo/mcp.json`** contains live credentials after the fetch — treat it as a secret file
- The fetch scripts write files with `chmod 600` on Linux (owner read/write only)
- Rotate the `VAULT_TOKEN` regularly; use a short-TTL token or Vault AppRole for CI/CD
- If the Vault TLS certificate is self-signed, set `VAULT_SKIP_TLS=true` — do not disable TLS entirely in production

---

## Troubleshooting

| Error | Fix |
|-------|-----|
| `VAULT_ADDR is not set` | Export `VAULT_ADDR` or add it to `.env.vault` |
| `VAULT_TOKEN is not set` | Export `VAULT_TOKEN` or add it to `.env.vault` |
| `403 Forbidden` | Token lacks read permission on `secret/data/internal-erp/db` |
| `404 Not Found` | Secret path wrong — check KV v2 path includes `/data/` |
| TLS certificate error | Add `-SkipTlsVerify` (PS) or `VAULT_SKIP_TLS=true` (bash) |
| `jq: command not found` (bash) | `apt-get install -y jq` |
| `Required key 'X' not found` | Add the missing key to Vault at `secret/data/internal-erp/db` |
