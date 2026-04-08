# ============================================================
#  HashiCorp Vault - Store Anthropic API Key
#  Run this ONCE from a machine with Vault admin/write access.
#  After this, the main installer fetches the key automatically.
# ============================================================

param(
    [string]$VaultToken,
    [string]$AnthropicKey
)

# ---- Vault settings ----------------------------------------
$VAULT_ADDR   = "https://45.88.223.83:31313"
$SECRET_PATH  = "secret/data/roocode"
$SECRET_FIELD = "anthropic_api_key"

# ---- Prompt if not passed as parameters --------------------
if (-not $VaultToken) {
    Write-Host ""
    Write-Host "  Enter your Vault ADMIN/WRITE token:" -ForegroundColor Cyan
    $VaultToken = Read-Host "  Token"
}

if (-not $AnthropicKey) {
    Write-Host ""
    Write-Host "  Enter the Anthropic API key to store:" -ForegroundColor Cyan
    $AnthropicKey = Read-Host "  API Key"
}

Write-Host ""
Write-Host "  Connecting to Vault at $VAULT_ADDR ..." -ForegroundColor Yellow

# ---- Trust self-signed cert --------------------------------
try {
    Add-Type -TypeDefinition @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllVault : ICertificatePolicy {
    public bool CheckValidationResult(
        ServicePoint s, X509Certificate c, WebRequest r, int p) { return true; }
}
"@ -ErrorAction SilentlyContinue
}
catch { }

[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllVault
[System.Net.ServicePointManager]::SecurityProtocol  = [System.Net.SecurityProtocolType]::Tls12

# ---- Write secret to Vault ---------------------------------
$headers = @{
    "X-Vault-Token" = $VaultToken
    "Content-Type"  = "application/json"
}

$body = "{`"data`":{`"$SECRET_FIELD`":`"$AnthropicKey`"}}"

try {
    $response = Invoke-RestMethod `
        -Uri         "$VAULT_ADDR/v1/$SECRET_PATH" `
        -Method      POST `
        -Headers     $headers `
        -Body        $body `
        -TimeoutSec  15 `
        -ErrorAction Stop

    Write-Host ""
    Write-Host "  [OK] Secret stored successfully!" -ForegroundColor Green
    Write-Host "       Path   : $SECRET_PATH" -ForegroundColor Gray
    Write-Host "       Field  : $SECRET_FIELD" -ForegroundColor Gray
    Write-Host "       Version: $($response.data.version)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  The installer (Install-RooCode.bat) will now fetch" -ForegroundColor Cyan
    Write-Host "  this key automatically when run on any machine." -ForegroundColor Cyan
}
catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    Write-Host ""
    Write-Host "  [XX] Failed to write secret." -ForegroundColor Red
    Write-Host "       HTTP Status : $statusCode" -ForegroundColor Red
    Write-Host "       Error       : $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""

    if ($statusCode -eq 403) {
        Write-Host "  The token does not have WRITE permission." -ForegroundColor DarkYellow
        Write-Host "  Use a root token or a token with this policy:" -ForegroundColor DarkYellow
        Write-Host ""
        Write-Host '  path "secret/data/roocode" {' -ForegroundColor Gray
        Write-Host '    capabilities = ["create", "update"]' -ForegroundColor Gray
        Write-Host '  }' -ForegroundColor Gray
    }
    elseif ($statusCode -eq 404) {
        Write-Host "  The KV secrets engine may not be enabled." -ForegroundColor DarkYellow
        Write-Host "  Enable it with: vault secrets enable -path=secret kv-v2" -ForegroundColor DarkYellow
    }
}

Write-Host ""
Read-Host "  Press ENTER to close"
