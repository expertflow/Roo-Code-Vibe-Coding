# BS4 Team — Shared HashiCorp Vault Space

## Overview

This document describes the shared secret space for the BS4 team on HashiCorp Vault.

**Vault URL:** `https://45.88.223.83:31313`

---

## Why a Shared Space?

The original setup used `cubbyhole/` which is **private per-token** — each Vault token has its own isolated cubbyhole that no other token can read. This works for one person but cannot be shared across the team.

The shared space uses a **KV v1 engine mounted at `bs4/`** which all team members can read using a token with the `bs4-team-readonly` policy.

---

## Secret Paths

| Path | Contents |
|------|----------|
| `bs4/postgresql` | PostgreSQL host, port, database, user credentials |
| `bs4/directus` | Directus URL, admin email/password, key, secret, token |
| `bs4/ai-tools` | Anthropic API key, model list |
| `bs4/gcp` | GCP project ID, region, Vault address |

### `bs4/postgresql`

| Field | Description |
|-------|-------------|
| `host` | PostgreSQL host (`34.65.200.86`) |
| `port` | Port (`5432`) |
| `database` | Database name (`bidstruct4`) |
| `sterile_dev_user` | Read/write app user (`sterile_dev`) |
| `sterile_dev_password` | Password for `sterile_dev` |
| `bs4_dev_user` | Break-glass / migrations user (`bs4_dev`) |
| `bs4_dev_password` | Password for `bs4_dev` |
| `ssl_mode` | SSL mode (`require`) |

### `bs4/directus`

| Field | Description |
|-------|-------------|
| `url` | Directus public URL |
| `admin_email` | Admin login email |
| `admin_password` | Admin login password |
| `key` | Directus `KEY` (JWT signing) |
| `secret` | Directus `SECRET` (JWT signing) |
| `token` | Static API token for MCP/automation |

### `bs4/ai-tools`

| Field | Description |
|-------|-------------|
| `anthropic_api_key` | Anthropic API key for Claude Sonnet + Opus |
| `anthropic_models` | Comma-separated model list |

### `bs4/gcp`

| Field | Description |
|-------|-------------|
| `project_id` | GCP project (`expertflowerp`) |
| `region` | GCP region (`europe-west6`) |
| `vault_addr` | Vault address |

---

## One-Time Admin Setup

**Who:** The person with the Vault root/admin token (the one who set up the Vault server).

**When:** Run once. After this, all engineers use the team token.

### Windows (PowerShell)

```powershell
# From the repo root:
.\vault-admin-setup.ps1
```

### Linux / GCP VM (Bash)

```bash
chmod +x vault-admin-setup.sh
./vault-admin-setup.sh
```

The script will:
1. Enable the `bs4/` KV v1 engine
2. Write all secrets to `bs4/postgresql`, `bs4/directus`, `bs4/ai-tools`, `bs4/gcp`
3. Create the `bs4-team-readonly` policy (read + list on `bs4/*`)
4. Create a 30-day renewable team token with that policy
5. Print the new team token — **share this with all engineers**

---

## Engineer Onboarding (After Admin Setup)

Engineers receive the team token and run the one-click setup:

```
Double-click: Start Roo Code.bat
  -> Choose IDE (VS Code / Cursor / Windsurf)
  -> Enter the team Vault token
  -> Everything is configured automatically
```

Or manually:

```powershell
$env:VAULT_TOKEN = "hvs.TEAM_TOKEN_HERE"
.\setup.ps1
```

---

## Vault Policies

### `bs4-team-readonly`

```hcl
# Read and list all BS4 team secrets
path "bs4/*" {
  capabilities = ["read", "list"]
}

# Allow token self-lookup
path "auth/token/lookup-self" {
  capabilities = ["read"]
}
```

This policy is **read-only**. Engineers can fetch secrets but cannot modify them.

To update a secret, the admin uses the Vault UI at `https://45.88.223.83:31313/ui/` or runs the admin setup script again.

---

## Updating a Secret

### Via Vault UI

1. Go to `https://45.88.223.83:31313/ui/vault/secrets/bs4/list`
2. Click the path (e.g. `postgresql`)
3. Click **Edit** → update the field → **Save**

### Via PowerShell (admin token required)

```powershell
$VAULT_ADDR  = "https://45.88.223.83:31313"
$VAULT_TOKEN = "hvs.ADMIN_TOKEN"

# Read current values first
$current = curl.exe -sk -H "X-Vault-Token: $VAULT_TOKEN" "$VAULT_ADDR/v1/bs4/postgresql" | ConvertFrom-Json

# Update one field (KV v1 requires full overwrite)
$updated = $current.data
$updated.sterile_dev_password = "new-password-here"

$json = $updated | ConvertTo-Json -Compress
$tmp = [System.IO.Path]::GetTempFileName()
[System.IO.File]::WriteAllText($tmp, $json, (New-Object System.Text.UTF8Encoding $false))
curl.exe -sk -X POST "$VAULT_ADDR/v1/bs4/postgresql" -H "X-Vault-Token: $VAULT_TOKEN" -H "Content-Type: application/json" --data-binary "@$tmp"
Remove-Item $tmp
```

---

## Legacy Mode (Cubbyhole)

If the `bs4/` engine has not been set up yet, all scripts automatically fall back to:

```
cubbyhole/internal-erp/db
```

This is the original single-path flat secret. It works but is **private to the token that wrote it** — other team members cannot read it with their own tokens.

**Migration path:** Admin runs `vault-admin-setup.ps1` once → all scripts automatically switch to shared mode.

---

## Token Renewal

Team tokens expire after 30 days but are renewable. To renew:

```powershell
curl.exe -sk -X POST "https://45.88.223.83:31313/v1/auth/token/renew-self" `
    -H "X-Vault-Token: hvs.TEAM_TOKEN_HERE"
```

Or the admin creates a new token and distributes it.

---

## File Reference

| File | Purpose |
|------|---------|
| `vault-admin-setup.ps1` | One-time admin setup (Windows) |
| `vault-admin-setup.sh` | One-time admin setup (Linux/GCP VM) |
| `setup.ps1` | Engineer one-click setup (auto-detects shared vs legacy) |
| `Start Roo Code.bat` | Double-click launcher for Windows engineers |
| `projects/internal-erp/directus/vault-fetch-secrets.ps1` | Standalone fetch for Directus .env (Windows) |
| `projects/internal-erp/directus/vault-fetch-secrets.sh` | Standalone fetch for Directus .env (Linux) |
