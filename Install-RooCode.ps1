# ============================================================
#  Roo Code - Universal Extension Installer & Profile Setup
#  Supports: VS Code, VS Code Insiders, Cursor, Windsurf, VSCodium
#  Version : 2.0  (HashiCorp Vault secrets integration)
# ============================================================

param(
    [switch]$Silent
)

$ErrorActionPreference = "Continue"

# ---- Vault Configuration -----------------------------------
# Secrets are fetched live from HashiCorp Vault at runtime.
# Nothing sensitive is stored in this script file.
$VAULT_ADDR  = "https://45.88.223.83:31313"
$VAULT_TOKEN = "hvs.CAESIC0nSYZlc92KbjE36r_Vncz-MznLpY0eMplhN_V6FrVaGh4KHGh2cy5jU3Q2djJMWjc2bWJPYkZhN3ZSN1JBcUc"

# cubbyhole is a KV v1 backend - path has no /data/ prefix
$VAULT_SECRET_PATH  = "cubbyhole/roocode"
$VAULT_SECRET_FIELD = "anthropic_api_key"

# ---- Static Configuration ----------------------------------
$ROO_EXTENSION_ID = "RooVeterinaryInc.roo-cline"
$GCP_PROJECT_ID   = "expertflowerp"
$GCP_REGION       = "us-central1"

# ---- Console helpers ----------------------------------------
function Write-Header {
    Clear-Host
    Write-Host ""
    Write-Host "  =============================================" -ForegroundColor Cyan
    Write-Host "   ROO CODE - Universal Installer  v2.0" -ForegroundColor Cyan
    Write-Host "   VS Code | Cursor | Windsurf | VSCodium" -ForegroundColor Cyan
    Write-Host "   Secrets via HashiCorp Vault" -ForegroundColor DarkCyan
    Write-Host "  =============================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step {
    param([string]$msg)
    Write-Host "  > $msg" -ForegroundColor Yellow
}

function Write-OK {
    param([string]$msg)
    Write-Host "  [OK] $msg" -ForegroundColor Green
}

function Write-Warn {
    param([string]$msg)
    Write-Host "  [!!] $msg" -ForegroundColor DarkYellow
}

function Write-Fail {
    param([string]$msg)
    Write-Host "  [XX] $msg" -ForegroundColor Red
}

function Write-Section {
    param([string]$title)
    Write-Host ""
    Write-Host "  ---- $title ----" -ForegroundColor Cyan
    Write-Host ""
}

# ---- Fetch secret from HashiCorp Vault ----------------------
function Get-VaultSecret {
    param(
        [string]$vaultAddr,
        [string]$vaultToken,
        [string]$secretPath,
        [string]$fieldName
    )

    Write-Step "Connecting to HashiCorp Vault at $vaultAddr ..."

    try {
        # Disable SSL certificate validation for self-signed certs on private servers
        if (-not ([System.Management.Automation.PSTypeName]'TrustAllCerts').Type) {
            Add-Type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCerts : ICertificatePolicy {
    public bool CheckValidationResult(
        ServicePoint srvPoint, X509Certificate certificate,
        WebRequest request, int certificateProblem) { return true; }
}
"@
        }
        [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCerts
        [System.Net.ServicePointManager]::SecurityProtocol  = [System.Net.SecurityProtocolType]::Tls12

        $headers = @{
            "X-Vault-Token" = $vaultToken
        }

        $uri      = "$vaultAddr/v1/$secretPath"
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method GET -ErrorAction Stop

        # cubbyhole / KV v1: response is { "data": { "field": "value" } }
        # KV v2:             response is { "data": { "data": { "field": "value" } } }
        $secret = $null
        if ($response.data -and $response.data.$fieldName) {
            # KV v1 / cubbyhole
            $secret = $response.data.$fieldName
        }
        elseif ($response.data.data -and $response.data.data.$fieldName) {
            # KV v2
            $secret = $response.data.data.$fieldName
        }

        if ($secret) {
            Write-OK "Secret '$fieldName' retrieved from Vault successfully."
            return $secret
        }
        else {
            Write-Fail "Field '$fieldName' not found in Vault path '$secretPath'."
            Write-Warn "Make sure you have stored the secret at: $vaultAddr/ui/vault/secrets"
            Write-Warn "Expected path : $secretPath"
            Write-Warn "Expected field: $fieldName"
            return $null
        }
    }
    catch {
        Write-Fail "Failed to connect to Vault: $($_.Exception.Message)"
        Write-Warn "Vault URL : $vaultAddr"
        Write-Warn "Secret path: $secretPath"
        return $null
    }
}

# ---- Detect installed IDEs ----------------------------------
function Get-InstalledIDEs {
    $ides = @()

    $candidates = @(
        @{
            Name         = "VS Code"
            CLI          = "code"
            SettingsBase = "$env:APPDATA\Code\User"
            ExtraPaths   = @(
                "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd",
                "C:\Program Files\Microsoft VS Code\bin\code.cmd",
                "C:\Program Files (x86)\Microsoft VS Code\bin\code.cmd"
            )
        },
        @{
            Name         = "VS Code Insiders"
            CLI          = "code-insiders"
            SettingsBase = "$env:APPDATA\Code - Insiders\User"
            ExtraPaths   = @(
                "$env:LOCALAPPDATA\Programs\Microsoft VS Code Insiders\bin\code-insiders.cmd",
                "C:\Program Files\Microsoft VS Code Insiders\bin\code-insiders.cmd"
            )
        },
        @{
            Name         = "Cursor"
            CLI          = "cursor"
            SettingsBase = "$env:APPDATA\Cursor\User"
            ExtraPaths   = @(
                "$env:LOCALAPPDATA\Programs\cursor\resources\app\bin\cursor",
                "$env:LOCALAPPDATA\Programs\Cursor\cursor.exe",
                "$env:LOCALAPPDATA\cursor\cursor.exe",
                "C:\Program Files\Cursor\resources\app\bin\cursor",
                "$env:USERPROFILE\AppData\Local\Programs\cursor\Cursor.exe"
            )
        },
        @{
            Name         = "Windsurf"
            CLI          = "windsurf"
            SettingsBase = "$env:APPDATA\Windsurf\User"
            ExtraPaths   = @(
                "$env:LOCALAPPDATA\Programs\Windsurf\bin\windsurf.cmd",
                "C:\Program Files\Windsurf\bin\windsurf.cmd"
            )
        },
        @{
            Name         = "VSCodium"
            CLI          = "codium"
            SettingsBase = "$env:APPDATA\VSCodium\User"
            ExtraPaths   = @(
                "$env:LOCALAPPDATA\Programs\VSCodium\bin\codium.cmd",
                "C:\Program Files\VSCodium\bin\codium.cmd"
            )
        }
    )

    foreach ($ide in $candidates) {
        # 1. Try PATH first
        $cliPath = Get-Command $ide.CLI -ErrorAction SilentlyContinue
        if ($cliPath) {
            $ide["CLIPath"] = $cliPath.Source
            $ides += $ide
            continue
        }

        # 2. Try extra known paths
        $found = $false
        foreach ($p in $ide.ExtraPaths) {
            if (Test-Path $p) {
                $ide["CLIPath"] = $p
                $ides += $ide
                $found = $true
                break
            }
        }

        # 3. If settings folder exists, IDE is installed even if CLI not found
        if (-not $found -and (Test-Path $ide.SettingsBase)) {
            $ide["CLIPath"] = $null
            $ides += $ide
        }
    }

    return $ides
}

# ---- Install extension via CLI ------------------------------
function Install-Extension {
    param(
        [hashtable]$ide,
        [string]$extensionId
    )

    Write-Step "Installing '$extensionId' in $($ide.Name) ..."

    $cli = if ($ide.CLIPath) { $ide.CLIPath } else { $ide.CLI }

    if (-not $cli) {
        Write-Warn "$($ide.Name) - CLI not found, skipping extension install."
        return $false
    }

    try {
        $result    = & "$cli" --install-extension $extensionId --force 2>&1
        $exitCode  = $LASTEXITCODE
        $resultStr = ($result -join " ")

        if ($exitCode -eq 0 -or $resultStr -match "successfully installed|already installed") {
            Write-OK "$($ide.Name) - Roo Code extension installed successfully."
            return $true
        }
        else {
            Write-Warn "$($ide.Name) - Possible issue (exit $exitCode): $resultStr"
            return $false
        }
    }
    catch {
        Write-Fail "$($ide.Name) - Exception during install: $($_.Exception.Message)"
        return $false
    }
}

# ---- Build Roo Code profile objects -------------------------
function New-RooProfiles {
    param([string]$anthropicKey)

    $p1 = [ordered]@{
        id              = "11111111-1111-1111-1111-111111111001"
        name            = "Gemini-2.5-pro"
        apiProvider     = "vertex"
        vertexProjectId = $GCP_PROJECT_ID
        vertexRegion    = $GCP_REGION
        apiModelId      = "gemini-2.5-pro"
    }

    $p2 = [ordered]@{
        id              = "11111111-1111-1111-1111-111111111002"
        name            = "Gemini-2.5-flash"
        apiProvider     = "vertex"
        vertexProjectId = $GCP_PROJECT_ID
        vertexRegion    = $GCP_REGION
        apiModelId      = "gemini-2.5-flash"
    }

    $p3 = [ordered]@{
        id          = "11111111-1111-1111-1111-111111111003"
        name        = "Claude Sonnet"
        apiProvider = "anthropic"
        apiKey      = $anthropicKey
        apiModelId  = "claude-sonnet-4-6"
    }

    $p4 = [ordered]@{
        id          = "11111111-1111-1111-1111-111111111004"
        name        = "Claude Opus"
        apiProvider = "anthropic"
        apiKey      = $anthropicKey
        apiModelId  = "claude-opus-4-6"
    }

    return @($p1, $p2, $p3, $p4)
}

# ---- Write profiles into IDE's Roo Code storage -------------
function Set-RooProfiles {
    param(
        [hashtable]$ide,
        [array]$profiles,
        [string]$anthropicKey
    )

    $settingsDir = $ide.SettingsBase

    # Create settings dir if it does not exist yet
    if (-not (Test-Path $settingsDir)) {
        try {
            New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null
            Write-OK "$($ide.Name) - Created settings directory."
        }
        catch {
            Write-Warn "$($ide.Name) - Cannot create settings dir: $settingsDir - $($_.Exception.Message)"
            return $false
        }
    }

    # Write Roo Code globalStorage settings.json
    $rooDir = Join-Path $settingsDir "globalStorage\RooVeterinaryInc.roo-cline"
    if (-not (Test-Path $rooDir)) {
        New-Item -ItemType Directory -Path $rooDir -Force | Out-Null
    }

    $rooSettingsFile = Join-Path $rooDir "settings.json"

    # Preserve any existing settings, only overwrite profile keys
    $rooSettings = [ordered]@{}
    if (Test-Path $rooSettingsFile) {
        try {
            $existing = Get-Content $rooSettingsFile -Raw -Encoding UTF8
            if ($existing -and $existing.Trim() -ne "") {
                $parsed = $existing | ConvertFrom-Json
                $parsed.PSObject.Properties | ForEach-Object {
                    $rooSettings[$_.Name] = $_.Value
                }
            }
        }
        catch {
            Write-Warn "$($ide.Name) - Could not parse existing settings.json, starting fresh."
            $rooSettings = [ordered]@{}
        }
    }

    $rooSettings["apiProfiles"]         = $profiles
    $rooSettings["currentApiProfileId"] = $profiles[0].id

    $rooSettings | ConvertTo-Json -Depth 10 | Set-Content $rooSettingsFile -Encoding UTF8
    Write-OK "$($ide.Name) - Profiles written to globalStorage."

    # Also patch the IDE's user settings.json
    $userSettingsFile = Join-Path $settingsDir "settings.json"
    $userSettings = [ordered]@{}

    if (Test-Path $userSettingsFile) {
        try {
            $raw = Get-Content $userSettingsFile -Raw -Encoding UTF8
            if ($raw -and $raw.Trim() -ne "") {
                $parsedUser = $raw | ConvertFrom-Json
                $parsedUser.PSObject.Properties | ForEach-Object {
                    $userSettings[$_.Name] = $_.Value
                }
            }
        }
        catch {
            Write-Warn "$($ide.Name) - Could not parse user settings.json, will create new."
            $userSettings = [ordered]@{}
        }
    }

    # Set default provider so Roo Code works immediately on first open
    $userSettings["roo-cline.apiProvider"] = "anthropic"
    $userSettings["roo-cline.apiKey"]      = $anthropicKey
    $userSettings["roo-cline.apiModelId"]  = "claude-sonnet-4-6"

    $userSettings | ConvertTo-Json -Depth 10 | Set-Content $userSettingsFile -Encoding UTF8
    Write-OK "$($ide.Name) - User settings.json updated with default provider."

    return $true
}

# ============================================================
#  MAIN EXECUTION
# ============================================================
Write-Header

# Step 0: Fetch API key from Vault
Write-Section "Step 0 of 4 - Fetching Secrets from HashiCorp Vault"

$ANTHROPIC_API_KEY = Get-VaultSecret `
    -vaultAddr   $VAULT_ADDR `
    -vaultToken  $VAULT_TOKEN `
    -secretPath  $VAULT_SECRET_PATH `
    -fieldName   $VAULT_SECRET_FIELD

if (-not $ANTHROPIC_API_KEY) {
    Write-Host ""
    Write-Fail "Could not retrieve the Anthropic API key from Vault."
    Write-Host ""
    Write-Host "  Please ensure:" -ForegroundColor DarkYellow
    Write-Host "  1. Vault is reachable at: $VAULT_ADDR" -ForegroundColor DarkYellow
    Write-Host "  2. The token is valid and has read access." -ForegroundColor DarkYellow
    Write-Host "  3. A secret exists at path: $VAULT_SECRET_PATH" -ForegroundColor DarkYellow
    Write-Host "  4. The secret has a field named: $VAULT_SECRET_FIELD" -ForegroundColor DarkYellow
    Write-Host ""
    Write-Host "  To create the secret, run in Vault CLI:" -ForegroundColor Gray
    Write-Host "  vault kv put secret/roocode anthropic_api_key=sk-ant-api03-..." -ForegroundColor Gray
    Write-Host ""
    if (-not $Silent) {
        Read-Host "  Press ENTER to exit"
    }
    exit 1
}

# Step 1: Detect IDEs
Write-Section "Step 1 of 4 - Detecting Installed IDEs"
$ides = Get-InstalledIDEs

if ($ides.Count -eq 0) {
    Write-Fail "No supported IDE found on this machine."
    Write-Host ""
    Write-Host "  Supported: VS Code, VS Code Insiders, Cursor, Windsurf, VSCodium" -ForegroundColor DarkGray
    Write-Host "  Install at least one IDE and re-run this script." -ForegroundColor DarkGray
    Write-Host ""
    if (-not $Silent) {
        Read-Host "  Press ENTER to exit"
    }
    exit 1
}

foreach ($ide in $ides) {
    $cliDisplay = if ($ide.CLIPath) { $ide.CLIPath } else { "(CLI not in PATH - settings only)" }
    Write-OK "Found: $($ide.Name)  ->  $cliDisplay"
}

# Step 2: Install Roo Code extension
Write-Section "Step 2 of 4 - Installing Roo Code Extension"

$installResults = @{}
foreach ($ide in $ides) {
    $ok = Install-Extension -ide $ide -extensionId $ROO_EXTENSION_ID
    $installResults[$ide.Name] = $ok
}

# Step 3: Build profiles
Write-Section "Step 3 of 4 - Building Configuration Profiles"
$profiles = New-RooProfiles -anthropicKey $ANTHROPIC_API_KEY

Write-OK "Profile 1 -> Gemini-2.5-pro    (GCP Vertex AI | Project: $GCP_PROJECT_ID | Region: $GCP_REGION)"
Write-OK "Profile 2 -> Gemini-2.5-flash  (GCP Vertex AI | Project: $GCP_PROJECT_ID | Region: $GCP_REGION)"
Write-OK "Profile 3 -> Claude Sonnet     (Anthropic | Model: claude-sonnet-4-6)"
Write-OK "Profile 4 -> Claude Opus       (Anthropic | Model: claude-opus-4-6)"

# Step 4: Write profiles to each IDE
Write-Section "Step 4 of 4 - Writing Profiles to IDE Settings"

$profileResults = @{}
foreach ($ide in $ides) {
    $ok = Set-RooProfiles -ide $ide -profiles $profiles -anthropicKey $ANTHROPIC_API_KEY
    $profileResults[$ide.Name] = $ok
}

# Final Summary
Write-Section "Installation Complete - Summary"

$allGood = $true
foreach ($ide in $ides) {
    $extOk      = $installResults[$ide.Name]
    $profOk     = $profileResults[$ide.Name]
    $extStatus  = if ($extOk)  { "[OK] Extension" } else { "[!!] Extension (check manually)" }
    $profStatus = if ($profOk) { "[OK] Profiles"  } else { "[!!] Profiles (check manually)"  }
    if (-not $extOk -or -not $profOk) {
        $allGood = $false
    }
    Write-Host "  $($ide.Name.PadRight(24)) $extStatus  |  $profStatus" -ForegroundColor White
}

Write-Host ""
Write-Host "  -----------------------------------------------" -ForegroundColor DarkGray

if ($allGood) {
    Write-Host "  SUCCESS! All IDEs configured." -ForegroundColor Green
}
else {
    Write-Host "  Done with some warnings. Check items marked [!!] above." -ForegroundColor DarkYellow
}

Write-Host ""
Write-Host "  NEXT STEPS:" -ForegroundColor Cyan
Write-Host "  1. Restart your IDE(s)" -ForegroundColor White
Write-Host "  2. Open Roo Code from the sidebar" -ForegroundColor White
Write-Host "  3. Select a profile from the dropdown at the top of Roo Code" -ForegroundColor White
Write-Host ""
Write-Host "  NOTE: For Gemini profiles, authenticate with Google Cloud:" -ForegroundColor DarkYellow
Write-Host "        gcloud auth application-default login" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Profiles created:" -ForegroundColor DarkGray
Write-Host "    - Gemini-2.5-pro   (Vertex AI)" -ForegroundColor DarkGray
Write-Host "    - Gemini-2.5-flash (Vertex AI)" -ForegroundColor DarkGray
Write-Host "    - Claude Sonnet    (Anthropic - Ready to use!)" -ForegroundColor DarkGray
Write-Host "    - Claude Opus      (Anthropic - Ready to use!)" -ForegroundColor DarkGray
Write-Host ""

if (-not $Silent) {
    Read-Host "  Press ENTER to close this window"
}
