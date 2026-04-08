# ============================================================
#  HashiCorp Vault - Store ALL MCP Secrets
#  Run this ONCE from a machine with Vault admin/write access.
#  Stores all secrets needed by .roo/mcp.json MCP servers.
# ============================================================

param(
    [string]$VaultToken
)

$VAULT_ADDR  = "https://45.88.223.83:31313"
$SECRET_PATH = "cubbyhole/roocode"

# ---- Trust self-signed cert --------------------------------
try {
    Add-Type -TypeDefinition @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllMCP : ICertificatePolicy {
    public bool CheckValidationResult(
        ServicePoint s, X509Certificate c, WebRequest r, int p) { return true; }
}
"@ -ErrorAction SilentlyContinue
}
catch { }

[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllMCP
[System.Net.ServicePointManager]::SecurityProtocol  = [System.Net.SecurityProtocolType]::Tls12

# ---- Header ------------------------------------------------
Clear-Host
Write-Host ""
Write-Host "  =============================================" -ForegroundColor Cyan
Write-Host "   Vault MCP Secrets Setup" -ForegroundColor Cyan
Write-Host "   Stores all secrets for .roo/mcp.json" -ForegroundColor Cyan
Write-Host "  =============================================" -ForegroundColor Cyan
Write-Host ""

# ---- Get admin token ---------------------------------------
if (-not $VaultToken) {
    Write-Host "  Enter your Vault ADMIN/WRITE token:" -ForegroundColor Yellow
    $VaultToken = Read-Host "  Token"
}

$headers = @{
    "X-Vault-Token" = $VaultToken
    "Content-Type"  = "application/json"
}

# ---- Helper: read a secret value ---------------------------
function Read-Secret {
    param([string]$prompt, [string]$default = "")
    if ($default -ne "") {
        Write-Host "  $prompt" -ForegroundColor White -NoNewline
        Write-Host " [press ENTER to skip/leave blank]: " -ForegroundColor DarkGray -NoNewline
    }
    else {
        Write-Host "  ${prompt}: " -ForegroundColor White -NoNewline
    }
    $val = Read-Host
    if ($val -eq "" -and $default -ne "") { return $default }
    return $val
}

# ---- Collect all secrets -----------------------------------
Write-Host ""
Write-Host "  ---- Anthropic API Key ----" -ForegroundColor Cyan
$anthropic_api_key = Read-Secret "Anthropic API Key (sk-ant-api03-...)"

Write-Host ""
Write-Host "  ---- PostgreSQL Connection ----" -ForegroundColor Cyan
$pg_host     = Read-Secret "PostgreSQL Host (e.g. 34.90.x.x or db.example.com)"
$pg_database = Read-Secret "PostgreSQL Database name"
$pg_user     = Read-Secret "PostgreSQL Username"
$pg_password = Read-Secret "PostgreSQL Password"

Write-Host ""
Write-Host "  ---- Directus ----" -ForegroundColor Cyan
$directus_url   = Read-Secret "Directus URL (e.g. https://bs4.expertflow.com)"
$directus_token = Read-Secret "Directus Static Token (from Directus Admin > Users)"

Write-Host ""
Write-Host "  ---- GitHub ----" -ForegroundColor Cyan
$github_token = Read-Secret "GitHub Personal Access Token (ghp_...)"

Write-Host ""
Write-Host "  ---- SonarQube ----" -ForegroundColor Cyan
$sonar_host  = Read-Secret "SonarQube Host URL (e.g. https://sonar.example.com)"
$sonar_token = Read-Secret "SonarQube Token (squ_...)"

Write-Host ""
Write-Host "  ---- VMware ----" -ForegroundColor Cyan
$vmware_host     = Read-Secret "VMware vCenter Host (e.g. vcenter.example.com)"
$vmware_user     = Read-Secret "VMware Username (e.g. administrator@vsphere.local)"
$vmware_password = Read-Secret "VMware Password"

# ---- Build JSON body ---------------------------------------
$secrets = [ordered]@{
    anthropic_api_key = $anthropic_api_key
    pg_host           = $pg_host
    pg_database       = $pg_database
    pg_user           = $pg_user
    pg_password       = $pg_password
    directus_url      = $directus_url
    directus_token    = $directus_token
    github_token      = $github_token
    sonar_host        = $sonar_host
    sonar_token       = $sonar_token
    vmware_host       = $vmware_host
    vmware_user       = $vmware_user
    vmware_password   = $vmware_password
}

# Remove empty values
$filtered = [ordered]@{}
foreach ($k in $secrets.Keys) {
    if ($secrets[$k] -and $secrets[$k].Trim() -ne "") {
        $filtered[$k] = $secrets[$k]
    }
}

$body = $filtered | ConvertTo-Json -Compress

# cubbyhole is KV v1 - POST directly to cubbyhole/roocode
Write-Host ""
Write-Host "  Storing secrets in Vault at $SECRET_PATH ..." -ForegroundColor Yellow

try {
    $response = Invoke-RestMethod `
        -Uri         "$VAULT_ADDR/v1/$SECRET_PATH" `
        -Method      POST `
        -Headers     $headers `
        -Body        $body `
        -TimeoutSec  15 `
        -ErrorAction Stop

    Write-Host ""
    Write-Host "  [OK] All secrets stored successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Stored keys:" -ForegroundColor DarkGray
    foreach ($k in $filtered.Keys) {
        $display = if ($k -match "password|token|key") {
            $filtered[$k].Substring(0, [Math]::Min(8, $filtered[$k].Length)) + "..."
        }
        else {
            $filtered[$k]
        }
        Write-Host "    $($k.PadRight(22)) = $display" -ForegroundColor DarkGray
    }
}
catch {
    $statusCode = $null
    try { $statusCode = $_.Exception.Response.StatusCode.value__ } catch {}
    Write-Host ""
    Write-Host "  [XX] Failed to store secrets." -ForegroundColor Red
    Write-Host "       HTTP Status : $statusCode" -ForegroundColor Red
    Write-Host "       Error       : $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    if ($statusCode -eq 403) {
        Write-Host "  The token does not have WRITE permission on cubbyhole." -ForegroundColor DarkYellow
        Write-Host "  Use the root token or a token with write policy." -ForegroundColor DarkYellow
    }
}

Write-Host ""
Write-Host "  ---- Verify stored secrets ----" -ForegroundColor Cyan
try {
    $verify = Invoke-RestMethod `
        -Uri         "$VAULT_ADDR/v1/$SECRET_PATH" `
        -Method      GET `
        -Headers     $headers `
        -TimeoutSec  10 `
        -ErrorAction Stop

    Write-Host "  [OK] Verification read successful. Keys in Vault:" -ForegroundColor Green
    $verify.data.PSObject.Properties | ForEach-Object {
        Write-Host "    - $($_.Name)" -ForegroundColor DarkGray
    }
}
catch {
    Write-Host "  [!!] Could not verify: $($_.Exception.Message)" -ForegroundColor DarkYellow
}

Write-Host ""
Write-Host "  The .roo/mcp.json installer will now use these secrets" -ForegroundColor Cyan
Write-Host "  automatically when Roo Code starts on any developer machine." -ForegroundColor Cyan
Write-Host ""
Read-Host "  Press ENTER to close"
