# =============================================================================
# vault-fetch-secrets.ps1
# Fetches secrets from HashiCorp Vault and writes:
#   - projects/internal-erp/directus/.env
#
# Supports two Vault layouts:
#   SHARED mode  (after admin runs vault-admin-setup.ps1):
#     bs4/postgresql  -> DB credentials
#     bs4/directus    -> Directus credentials
#     bs4/ai-tools    -> Anthropic API key
#
#   LEGACY mode  (original single-path cubbyhole):
#     cubbyhole/internal-erp/db  -> all secrets flat
#
# Usage:
#   $env:VAULT_TOKEN = "hvs.xxx"
#   .\vault-fetch-secrets.ps1
#
# Or just run it -- it will prompt for the token.
# =============================================================================

$VAULT_ADDR          = "https://45.88.223.83:31313"
$VAULT_PATH_PG       = "bs4/postgresql"
$VAULT_PATH_DIRECTUS = "bs4/directus"
$VAULT_PATH_AI       = "bs4/ai-tools"
$VAULT_PATH_LEGACY   = "cubbyhole/internal-erp/db"

$SCRIPT_DIR   = $PSScriptRoot
$ENV_OUT      = Join-Path $SCRIPT_DIR ".env"

Write-Host ""
Write-Host "========================================"
Write-Host " Vault Secret Fetch -- internal-erp"
Write-Host "========================================"
Write-Host ""

# ── Token ─────────────────────────────────────────────────────────────────────
$VAULT_TOKEN = $env:VAULT_TOKEN
if (-not $VAULT_TOKEN) {
    $secureToken = Read-Host -AsSecureString "Enter VAULT_TOKEN"
    $bstr        = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
    $VAULT_TOKEN = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
}
if (-not $VAULT_TOKEN -or $VAULT_TOKEN.Length -lt 10) {
    Write-Host "ERROR: No Vault token provided." -ForegroundColor Red
    exit 1
}

# ── Helper: GET a KV v1 path ──────────────────────────────────────────────────
function Get-VaultSecret([string]$Path) {
    $raw = curl.exe -sk -H "X-Vault-Token: $VAULT_TOKEN" "$VAULT_ADDR/v1/$Path" 2>&1
    try { $parsed = $raw | ConvertFrom-Json } catch { return $null }
    if ($parsed.PSObject.Properties['errors'] -and $parsed.errors) { return $null }
    return $parsed.data
}

function Require-Field([object]$Data, [string]$Key, [string]$Path) {
    if (-not $Data -or -not $Data.PSObject.Properties[$Key] -or -not $Data.$Key) {
        Write-Host "ERROR: Required field '$Key' missing in Vault at $Path" -ForegroundColor Red
        exit 1
    }
    return $Data.$Key
}

# ── Auto-detect layout ────────────────────────────────────────────────────────
Write-Host "Detecting Vault secret layout..." -ForegroundColor Gray
$pgData       = Get-VaultSecret $VAULT_PATH_PG
$directusData = Get-VaultSecret $VAULT_PATH_DIRECTUS
$aiData       = Get-VaultSecret $VAULT_PATH_AI

if ($pgData -and $directusData -and $aiData) {
    # ── SHARED MODE ───────────────────────────────────────────────────────────
    Write-Host "  Mode: SHARED (bs4/ KV engine)" -ForegroundColor Green
    Write-Host "  bs4/postgresql  -> DB credentials"
    Write-Host "  bs4/directus    -> Directus credentials"
    Write-Host "  bs4/ai-tools    -> Anthropic API key"

    $DB_PASSWORD       = Require-Field $pgData       "sterile_dev_password" $VAULT_PATH_PG
    $BS4_DEV_PASSWORD  = Require-Field $pgData       "bs4_dev_password"     $VAULT_PATH_PG
    $ADMIN_PASSWORD    = Require-Field $directusData "admin_password"       $VAULT_PATH_DIRECTUS
    $ADMIN_EMAIL       = Require-Field $directusData "admin_email"          $VAULT_PATH_DIRECTUS
    $DIRECTUS_KEY      = Require-Field $directusData "key"                  $VAULT_PATH_DIRECTUS
    $DIRECTUS_SECRET   = Require-Field $directusData "secret"               $VAULT_PATH_DIRECTUS
    $DIRECTUS_TOKEN    = Require-Field $directusData "token"                $VAULT_PATH_DIRECTUS
    $ANTHROPIC_API_KEY = Require-Field $aiData       "anthropic_api_key"    $VAULT_PATH_AI

} else {
    # ── LEGACY MODE ───────────────────────────────────────────────────────────
    Write-Host "  Mode: LEGACY (cubbyhole/internal-erp/db)" -ForegroundColor Yellow
    Write-Host "  (Run vault-admin-setup.ps1 to upgrade to shared mode)"

    $legacyData = Get-VaultSecret $VAULT_PATH_LEGACY
    if (-not $legacyData) {
        Write-Host "ERROR: Cannot read from Vault. Tried bs4/* and $VAULT_PATH_LEGACY." -ForegroundColor Red
        Write-Host "  Check your token and network access to $VAULT_ADDR" -ForegroundColor Red
        exit 1
    }

    $DB_PASSWORD       = Require-Field $legacyData "DB_PASSWORD"       $VAULT_PATH_LEGACY
    $BS4_DEV_PASSWORD  = Require-Field $legacyData "BS4_DEV_PASSWORD"  $VAULT_PATH_LEGACY
    $ADMIN_PASSWORD    = Require-Field $legacyData "ADMIN_PASSWORD"    $VAULT_PATH_LEGACY
    $ADMIN_EMAIL       = Require-Field $legacyData "ADMIN_EMAIL"       $VAULT_PATH_LEGACY
    $DIRECTUS_KEY      = Require-Field $legacyData "DIRECTUS_KEY"      $VAULT_PATH_LEGACY
    $DIRECTUS_SECRET   = Require-Field $legacyData "DIRECTUS_SECRET"   $VAULT_PATH_LEGACY
    $DIRECTUS_TOKEN    = Require-Field $legacyData "DIRECTUS_TOKEN"    $VAULT_PATH_LEGACY
    $ANTHROPIC_API_KEY = Require-Field $legacyData "ANTHROPIC_API_KEY" $VAULT_PATH_LEGACY
}

Write-Host "  All 8 secrets retrieved." -ForegroundColor Green

# ── Write .env ────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "Writing .env to: $ENV_OUT"

$envContent = @"
# AUTO-GENERATED by vault-fetch-secrets.ps1 -- DO NOT EDIT MANUALLY
# Source: $VAULT_ADDR
# Regenerate: .\vault-fetch-secrets.ps1

# --- Directus secrets ---
KEY=$DIRECTUS_KEY
SECRET=$DIRECTUS_SECRET

# --- Public URL (local) ---
PUBLIC_URL=http://localhost:8055

# --- PostgreSQL via Cloud SQL Auth Proxy on host ---
DB_CLIENT=pg
DB_HOST=host.docker.internal
DB_PORT=5432
DB_DATABASE=bidstruct4
DB_USER=sterile_dev
DB_PASSWORD=$DB_PASSWORD

# Break-glass / migrations user (bs4_dev)
BS4_DEV_PASSWORD=$BS4_DEV_PASSWORD

# --- First-time admin (Directus bootstrap) ---
ADMIN_EMAIL=$ADMIN_EMAIL
ADMIN_PASSWORD=$ADMIN_PASSWORD
"@

$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($ENV_OUT, $envContent, $utf8NoBom)

Write-Host "  Written: $ENV_OUT" -ForegroundColor Green

# Protect the file (Windows: remove inherited permissions, restrict to current user)
try {
    $acl  = Get-Acl $ENV_OUT
    $acl.SetAccessRuleProtection($true, $false)
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        [System.Security.Principal.WindowsIdentity]::GetCurrent().Name,
        "FullControl", "Allow"
    )
    $acl.SetAccessRule($rule)
    Set-Acl $ENV_OUT $acl
    Write-Host "  Permissions restricted to current user." -ForegroundColor Green
} catch {
    Write-Host "  WARN: Could not restrict file permissions: $_" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================"
Write-Host " Done! Start Directus with:"
Write-Host "   docker compose up"
Write-Host "========================================"
Write-Host ""
