# ============================================================
#  Roo Code MCP Bootstrap - Resolves Vault secrets and writes
#  a resolved mcp.json that Roo Code can use directly.
#
#  Run this once per machine (or after secrets rotate).
#  Output: .roo/mcp.resolved.json  (gitignored - contains secrets)
# ============================================================

$ErrorActionPreference = "Continue"

$VAULT_ADDR   = "https://45.88.223.83:31313"
$VAULT_TOKEN  = "hvs.CAESIC0nSYZlc92KbjE36r_Vncz-MznLpY0eMplhN_V6FrVaGh4KHGh2cy5jU3Q2djJMWjc2bWJPYkZhN3ZSN1JBcUc"
$SECRET_PATH  = "cubbyhole/internal-erp/db"
$OUTPUT_FILE  = Join-Path $PSScriptRoot "mcp.resolved.json"
$WORKSPACE    = Split-Path $PSScriptRoot -Parent

Write-Host ""
Write-Host "  =============================================" -ForegroundColor Cyan
Write-Host "   Roo Code MCP Bootstrap" -ForegroundColor Cyan
Write-Host "   Fetching secrets from HashiCorp Vault..." -ForegroundColor Cyan
Write-Host "  =============================================" -ForegroundColor Cyan
Write-Host ""

# ---- Trust self-signed cert --------------------------------
try {
    Add-Type -TypeDefinition @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustVaultBoot : ICertificatePolicy {
    public bool CheckValidationResult(
        ServicePoint s, X509Certificate c, WebRequest r, int p) { return true; }
}
"@ -ErrorAction SilentlyContinue
}
catch { }

[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustVaultBoot
[System.Net.ServicePointManager]::SecurityProtocol  = [System.Net.SecurityProtocolType]::Tls12

# ---- Fetch all secrets from Vault --------------------------
$secrets = @{}
try {
    $h = @{ "X-Vault-Token" = $VAULT_TOKEN }
    $r = Invoke-RestMethod -Uri "$VAULT_ADDR/v1/$SECRET_PATH" -Headers $h -Method GET -TimeoutSec 15 -ErrorAction Stop
    $r.data.PSObject.Properties | ForEach-Object {
        $secrets[$_.Name] = $_.Value
    }
    Write-Host "  [OK] Secrets fetched from Vault. Keys: $($secrets.Keys -join ', ')" -ForegroundColor Green
}
catch {
    Write-Host "  [XX] Failed to fetch secrets from Vault: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  Cannot generate resolved mcp.json without Vault access." -ForegroundColor DarkYellow
    exit 1
}

# ---- Helper: get secret or warn ----------------------------
function Get-S {
    param([string]$key)
    if ($secrets.ContainsKey($key) -and $secrets[$key]) {
        return $secrets[$key]
    }
    Write-Host "  [!!] Secret '$key' not found in Vault at $SECRET_PATH" -ForegroundColor DarkYellow
    return ""
}

# ---- Build resolved mcp.json -------------------------------
# Key names match exactly what is stored in cubbyhole/internal-erp/db:
# ADMIN_EMAIL, ADMIN_PASSWORD, ANTHROPIC_API_KEY, BS4_DEV_PASSWORD,
# DB_PASSWORD, DIRECTUS_KEY, DIRECTUS_SECRET
$pg_conn = "postgresql://postgres:$(Get-S 'DB_PASSWORD')@$(Get-S 'pg_host'):5432/$(Get-S 'pg_database')"

$resolved = [ordered]@{
    mcpServers = [ordered]@{

        "hashicorp-vault" = [ordered]@{
            command = "npx"
            args    = @("-y", "@modelcontextprotocol/server-vault")
            env     = [ordered]@{
                VAULT_ADDR        = $VAULT_ADDR
                VAULT_TOKEN       = $VAULT_TOKEN
                VAULT_SKIP_VERIFY = "true"
            }
        }

        "postgresql" = [ordered]@{
            command = "npx"
            args    = @("-y", "@modelcontextprotocol/server-postgres", $pg_conn)
            env     = [ordered]@{
                POSTGRES_CONNECTION_STRING = $pg_conn
            }
        }

        "directus" = [ordered]@{
            command = "npx"
            args    = @("-y", "@directus/mcp-server")
            env     = [ordered]@{
                DIRECTUS_URL    = "https://bs4.expertflow.com"
                DIRECTUS_KEY    = (Get-S "DIRECTUS_KEY")
                DIRECTUS_SECRET = (Get-S "DIRECTUS_SECRET")
            }
        }

        "bmad" = [ordered]@{
            command = "npx"
            args    = @("-y", "bmad-method", "mcp")
            env     = [ordered]@{
                BMAD_DOCS_PATH = "$WORKSPACE/docs/bmad"
            }
        }

        "speckit" = [ordered]@{
            command = "npx"
            args    = @("-y", "@github/spec-kit-mcp")
            env     = [ordered]@{
                SPECS_PATH    = "$WORKSPACE/docs/specs"
                GITHUB_TOKEN  = (Get-S "github_token")
            }
        }

        "playwright" = [ordered]@{
            command = "npx"
            args    = @("-y", "@playwright/mcp@latest")
            env     = [ordered]@{
                PLAYWRIGHT_BROWSERS_PATH = "$WORKSPACE/.playwright"
            }
        }

        "vmware" = [ordered]@{
            command = "npx"
            args    = @("-y", "@modelcontextprotocol/server-vmware")
            env     = [ordered]@{
                VMWARE_HOST     = (Get-S "vmware_host")
                VMWARE_USER     = (Get-S "vmware_user")
                VMWARE_PASSWORD = (Get-S "vmware_password")
                VMWARE_INSECURE = "true"
            }
        }

        "lint" = [ordered]@{
            command = "npx"
            args    = @("-y", "@modelcontextprotocol/server-lint")
            env     = [ordered]@{
                LINT_CONFIG_PATH         = "$WORKSPACE/.eslintrc.json"
                SONAR_HOST_URL           = (Get-S "sonar_host")
                SONAR_TOKEN              = (Get-S "sonar_token")
                GHERKIN_FEATURES_PATH    = "$WORKSPACE/features"
                REQUIREMENT_LINTER_DOCS  = "$WORKSPACE/docs/bmad"
            }
        }
    }
}

# ---- Write resolved file -----------------------------------
$json = $resolved | ConvertTo-Json -Depth 10
$json | Set-Content $OUTPUT_FILE -Encoding UTF8

Write-Host ""
Write-Host "  [OK] Resolved MCP config written to:" -ForegroundColor Green
Write-Host "       $OUTPUT_FILE" -ForegroundColor Gray
Write-Host ""
Write-Host "  IMPORTANT: This file contains secrets." -ForegroundColor DarkYellow
Write-Host "  It is gitignored and must NOT be committed." -ForegroundColor DarkYellow
Write-Host ""
Write-Host "  To use: copy mcp.resolved.json path into Roo Code MCP settings," -ForegroundColor Cyan
Write-Host "  or rename it to mcp.json (it will be gitignored)." -ForegroundColor Cyan
Write-Host ""
Read-Host "  Press ENTER to close"
