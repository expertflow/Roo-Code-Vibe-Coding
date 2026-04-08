# ============================================================
#  Roo Code - Universal Extension Installer & Profile Setup
#  Supports: VS Code, Cursor, Antigravity
#  Version : 3.0  (Windows Credential Manager - correct storage)
# ============================================================

param(
    [switch]$Silent
)

$ErrorActionPreference = "Continue"

# ---- Vault Configuration -----------------------------------
$VAULT_ADDR  = "https://45.88.223.83:31313"
$VAULT_TOKEN = "hvs.CAESIC0nSYZlc92KbjE36r_Vncz-MznLpY0eMplhN_V6FrVaGh4KHGh2cy5jU3Q2djJMWjc2bWJPYkZhN3ZSN1JBcUc"
$VAULT_SECRET_PATH  = "cubbyhole/internal-erp/db"
$VAULT_SECRET_FIELD = "ANTHROPIC_API_KEY"

# ---- Static Configuration ----------------------------------
$ROO_EXTENSION_ID = "RooVeterinaryInc.roo-cline"
$GCP_PROJECT_ID   = "expertflowerp"
$GCP_REGION       = "us-central1"

# ---- Windows Credential Manager C# type --------------------
$CredManSource = @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public class CredMan {
    [DllImport("advapi32.dll", EntryPoint="CredReadW", CharSet=CharSet.Unicode, SetLastError=true)]
    public static extern bool CredRead(string target, int type, int flags, out IntPtr credential);

    [DllImport("advapi32.dll", EntryPoint="CredWriteW", CharSet=CharSet.Unicode, SetLastError=true)]
    public static extern bool CredWrite(ref CREDENTIAL credential, int flags);

    [DllImport("advapi32.dll", SetLastError=true)]
    public static extern void CredFree(IntPtr buffer);

    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
    public struct CREDENTIAL {
        public int    Flags;
        public int    Type;
        public string TargetName;
        public string Comment;
        public long   LastWritten;
        public int    CredentialBlobSize;
        public IntPtr CredentialBlob;
        public int    Persist;
        public int    AttributeCount;
        public IntPtr Attributes;
        public string TargetAlias;
        public string UserName;
    }

    public static string Read(string target) {
        IntPtr ptr;
        if (!CredRead(target, 1, 0, out ptr)) return null;
        var c     = (CREDENTIAL)Marshal.PtrToStructure(ptr, typeof(CREDENTIAL));
        var bytes = new byte[c.CredentialBlobSize];
        Marshal.Copy(c.CredentialBlob, bytes, 0, c.CredentialBlobSize);
        CredFree(ptr);
        return Encoding.Unicode.GetString(bytes);
    }

    public static bool Write(string target, string username, string secret) {
        var blob  = Encoding.Unicode.GetBytes(secret);
        var blobPtr = Marshal.AllocHGlobal(blob.Length);
        Marshal.Copy(blob, 0, blobPtr, blob.Length);
        var cred = new CREDENTIAL {
            Flags              = 0,
            Type               = 1,
            TargetName         = target,
            Comment            = null,
            LastWritten        = 0,
            CredentialBlobSize = blob.Length,
            CredentialBlob     = blobPtr,
            Persist            = 2,
            AttributeCount     = 0,
            Attributes         = IntPtr.Zero,
            TargetAlias        = null,
            UserName           = username
        };
        bool ok = CredWrite(ref cred, 0);
        Marshal.FreeHGlobal(blobPtr);
        return ok;
    }
}
"@

# ---- Console helpers ----------------------------------------
function Write-Header {
    Clear-Host
    Write-Host ""
    Write-Host "  =============================================" -ForegroundColor Cyan
    Write-Host "   ROO CODE - Universal Installer  v3.0" -ForegroundColor Cyan
    Write-Host "   VS Code | Cursor | Antigravity" -ForegroundColor Cyan
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

# ---- Load CredMan type once ---------------------------------
function Initialize-CredMan {
    if (-not ([System.Management.Automation.PSTypeName]'CredMan').Type) {
        try {
            Add-Type -TypeDefinition $CredManSource -Language CSharp
            return $true
        }
        catch {
            Write-Fail "Failed to load CredMan type: $($_.Exception.Message)"
            return $false
        }
    }
    return $true
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

        $headers  = @{ "X-Vault-Token" = $vaultToken }
        $uri      = "$vaultAddr/v1/$secretPath"
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method GET -ErrorAction Stop

        $secret = $null
        if ($response.data -and $response.data.$fieldName) {
            $secret = $response.data.$fieldName
        }
        elseif ($response.data.data -and $response.data.data.$fieldName) {
            $secret = $response.data.data.$fieldName
        }

        if ($secret) {
            Write-OK "Secret '$fieldName' retrieved from Vault successfully."
            return $secret
        }
        else {
            Write-Fail "Field '$fieldName' not found in Vault path '$secretPath'."
            return $null
        }
    }
    catch {
        Write-Fail "Failed to connect to Vault: $($_.Exception.Message)"
        return $null
    }
}

# ---- Detect installed IDEs ----------------------------------
function Get-InstalledIDEs {
    $ides = @()

    $candidates = @(
        @{
            Name            = "VS Code"
            CLI             = "code"
            SettingsBase    = "$env:APPDATA\Code\User"
            CredentialScope = "vscode"
            ExtensionScope  = "RooVeterinaryInc.roo-cline"
            ExtraPaths      = @(
                "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd",
                "C:\Program Files\Microsoft VS Code\bin\code.cmd",
                "C:\Program Files (x86)\Microsoft VS Code\bin\code.cmd"
            )
        },
        @{
            Name            = "Cursor"
            CLI             = "cursor"
            SettingsBase    = "$env:APPDATA\Cursor\User"
            CredentialScope = "cursor"
            ExtensionScope  = "RooVeterinaryInc.roo-cline"
            ExtraPaths      = @(
                "$env:LOCALAPPDATA\Programs\cursor\resources\app\bin\cursor",
                "$env:LOCALAPPDATA\Programs\Cursor\cursor.exe",
                "$env:LOCALAPPDATA\cursor\cursor.exe",
                "C:\Program Files\Cursor\resources\app\bin\cursor",
                "$env:USERPROFILE\AppData\Local\Programs\cursor\Cursor.exe"
            )
        },
        @{
            Name            = "Antigravity"
            CLI             = "antigravity"
            SettingsBase    = "$env:APPDATA\Antigravity\User"
            CredentialScope = "antigravity"
            ExtensionScope  = "RooVeterinaryInc.roo-cline"
            ExtraPaths      = @(
                "$env:LOCALAPPDATA\Programs\Antigravity\bin\antigravity.cmd",
                "$env:LOCALAPPDATA\Programs\Antigravity\antigravity.exe",
                "C:\Program Files\Antigravity\bin\antigravity.cmd",
                "C:\Program Files\Antigravity\antigravity.exe"
            )
        }
    )

    foreach ($ide in $candidates) {
        $cliPath = Get-Command $ide.CLI -ErrorAction SilentlyContinue
        if ($cliPath) {
            $ide["CLIPath"] = $cliPath.Source
            $ides += $ide
            continue
        }

        $found = $false
        foreach ($p in $ide.ExtraPaths) {
            if (Test-Path $p) {
                $ide["CLIPath"] = $p
                $ides += $ide
                $found = $true
                break
            }
        }

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

# ---- Generate a UUID ----------------------------------------
function New-Guid {
    return [System.Guid]::NewGuid().ToString()
}

# ---- Build the profiles JSON payload ------------------------
# IMPORTANT: Windows Credential Manager has a 2560-byte Unicode limit.
# With 2 Anthropic API keys (~108 chars each) + vertex fields, the payload
# must stay lean. Omitting the migrations block saves ~186 bytes and keeps
# us safely under the limit (verified: ~2314 bytes). Roo Code sets migrations itself.
function New-ProfilesPayload {
    param([string]$anthropicKey)

    # Stable deterministic IDs - same on every run (idempotent)
    $id1 = "a1b2c3d4-e5f6-7890-abcd-ef1234567801"
    $id2 = "a1b2c3d4-e5f6-7890-abcd-ef1234567802"
    $id3 = "a1b2c3d4-e5f6-7890-abcd-ef1234567803"
    $id4 = "a1b2c3d4-e5f6-7890-abcd-ef1234567804"

    $payload = [ordered]@{
        currentApiConfigName = "Claude Sonnet"
        apiConfigs           = [ordered]@{
            "Gemini-2.5-pro"   = [ordered]@{
                id              = $id1
                apiProvider     = "vertex"
                apiModelId      = "gemini-2.5-pro"
                vertexProjectId = $GCP_PROJECT_ID
                vertexRegion    = $GCP_REGION
            }
            "Gemini-2.5-flash" = [ordered]@{
                id              = $id2
                apiProvider     = "vertex"
                apiModelId      = "gemini-2.5-flash"
                vertexProjectId = $GCP_PROJECT_ID
                vertexRegion    = $GCP_REGION
            }
            "Claude Sonnet"    = [ordered]@{
                id          = $id3
                apiProvider = "anthropic"
                apiModelId  = "claude-sonnet-4-6"
                apiKey      = $anthropicKey
            }
            "Claude Opus"      = [ordered]@{
                id          = $id4
                apiProvider = "anthropic"
                apiModelId  = "claude-opus-4-6"
                apiKey      = $anthropicKey
            }
        }
        modeApiConfigs = [ordered]@{
            code         = $id3
            architect    = $id1
            ask          = $id3
            debug        = $id3
            orchestrator = $id1
        }
        # migrations block intentionally omitted to stay under 2560-byte Windows
        # Credential Manager limit. Roo Code initialises migrations on first launch.
    }

    $json = $payload | ConvertTo-Json -Depth 10 -Compress

    # Safety check - warn if approaching limit
    $byteCount = [System.Text.Encoding]::Unicode.GetByteCount($json)
    if ($byteCount -gt 2560) {
        Write-Fail "Payload too large for Windows Credential Manager: $byteCount bytes (limit 2560)."
        Write-Warn "This usually means the Anthropic API key is unusually long."
        return $null
    }
    Write-Step "Payload size: $byteCount / 2560 bytes"

    return $json
}

# ---- Write profiles to Windows Credential Manager ----------
function Set-RooProfiles {
    param(
        [hashtable]$ide,
        [string]$anthropicKey
    )

    # Determine credential target based on IDE
    $credTarget = switch ($ide.Name) {
        "VS Code"     { "vscode.rooveterinaryinc.roo-cline/roo_cline_config_api_config" }
        "Cursor"      { "cursor.rooveterinaryinc.roo-cline/roo_cline_config_api_config" }
        "Antigravity" { "antigravity.rooveterinaryinc.roo-cline/roo_cline_config_api_config" }
        default       { "vscode.rooveterinaryinc.roo-cline/roo_cline_config_api_config" }
    }

    Write-Step "$($ide.Name) - Writing profiles to Windows Credential Manager ..."
    Write-Step "  Target: $credTarget"

    $json = New-ProfilesPayload -anthropicKey $anthropicKey

    if (-not $json) {
        Write-Fail "$($ide.Name) - Payload generation failed (too large or error)."
        return $false
    }

    $ok = [CredMan]::Write($credTarget, "roo_cline_config_api_config", $json)

    if ($ok) {
        Write-OK "$($ide.Name) - Profiles written to credential store successfully."
        return $true
    }
    else {
        $errCode = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
        Write-Fail "$($ide.Name) - Failed to write credential (Win32 error: $errCode)."
        return $false
    }
}

# ============================================================
#  MAIN EXECUTION
# ============================================================
Write-Header

# Load CredMan type
if (-not (Initialize-CredMan)) {
    Write-Fail "Cannot proceed without CredMan support."
    if (-not $Silent) { Read-Host "  Press ENTER to exit" }
    exit 1
}

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
    if (-not $Silent) { Read-Host "  Press ENTER to exit" }
    exit 1
}

# Step 1: Detect IDEs
Write-Section "Step 1 of 4 - Detecting Installed IDEs"
$ides = Get-InstalledIDEs

if ($ides.Count -eq 0) {
    Write-Fail "No supported IDE found on this machine."
    Write-Host ""
    Write-Host "  Supported: VS Code, Cursor, Antigravity" -ForegroundColor DarkGray
    Write-Host "  Install at least one IDE and re-run this script." -ForegroundColor DarkGray
    Write-Host ""
    if (-not $Silent) { Read-Host "  Press ENTER to exit" }
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

# Step 3: Show profiles being created
Write-Section "Step 3 of 4 - Building Configuration Profiles"

Write-OK "Profile 1 -> Gemini-2.5-pro    (GCP Vertex AI | Project: $GCP_PROJECT_ID | Region: $GCP_REGION)"
Write-OK "Profile 2 -> Gemini-2.5-flash  (GCP Vertex AI | Project: $GCP_PROJECT_ID | Region: $GCP_REGION)"
Write-OK "Profile 3 -> Claude Sonnet     (Anthropic | Model: claude-sonnet-4-6)"
Write-OK "Profile 4 -> Claude Opus       (Anthropic | Model: claude-opus-4-6)"

# Step 4: Write profiles to each IDE via Windows Credential Manager
Write-Section "Step 4 of 4 - Writing Profiles to IDE Credential Store"

$profileResults = @{}
foreach ($ide in $ides) {
    $ok = Set-RooProfiles -ide $ide -anthropicKey $ANTHROPIC_API_KEY
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
    if (-not $extOk -or -not $profOk) { $allGood = $false }
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
Write-Host "  NOTE: For Gemini profiles, authenticate with Google Cloud:" -ForegroundColor DarkYellow
Write-Host "        gcloud auth application-default login" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Profiles created:" -ForegroundColor DarkGray
Write-Host "    - Gemini-2.5-pro   (Vertex AI)" -ForegroundColor DarkGray
Write-Host "    - Gemini-2.5-flash (Vertex AI)" -ForegroundColor DarkGray
Write-Host "    - Claude Sonnet    (Anthropic - Ready to use!)" -ForegroundColor DarkGray
Write-Host "    - Claude Opus      (Anthropic - Ready to use!)" -ForegroundColor DarkGray
Write-Host ""

# ---- Auto-restart detected IDEs ----------------------------
Write-Section "Restarting IDEs"

$ideProcessMap = @{
    "VS Code"     = @("Code")
    "Cursor"      = @("Cursor")
    "Antigravity" = @("Antigravity", "antigravity")
}

$restartedAny = $false
foreach ($ide in $ides) {
    $procNames = $ideProcessMap[$ide.Name]
    if (-not $procNames) { continue }

    $running = $false
    foreach ($pn in $procNames) {
        if (Get-Process -Name $pn -ErrorAction SilentlyContinue) {
            $running = $true
            Write-Step "Closing $($ide.Name) ..."
            try {
                Get-Process -Name $pn -ErrorAction SilentlyContinue | Stop-Process -Force
                Start-Sleep -Seconds 2
                Write-OK "$($ide.Name) closed."
            }
            catch {
                Write-Warn "Could not close $($ide.Name): $($_.Exception.Message)"
            }
            break
        }
    }

    if ($running) {
        $cli = if ($ide.CLIPath) { $ide.CLIPath } else { $ide.CLI }
        if ($cli) {
            Write-Step "Restarting $($ide.Name) ..."
            try {
                Start-Process $cli
                Write-OK "$($ide.Name) restarted."
                $restartedAny = $true
            }
            catch {
                Write-Warn "Could not restart $($ide.Name): $($_.Exception.Message)"
                Write-Warn "Please restart $($ide.Name) manually."
            }
        }
        else {
            Write-Warn "$($ide.Name) was closed. Please reopen it manually."
        }
    }
    else {
        Write-OK "$($ide.Name) is not running - no restart needed."
    }
}

Write-Host ""
Write-Host "  -----------------------------------------------" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  NEXT STEPS:" -ForegroundColor Cyan
if ($restartedAny) {
    Write-Host "  1. Your IDE(s) have been restarted automatically" -ForegroundColor Green
}
else {
    Write-Host "  1. Restart VS Code (required for credential changes to take effect)" -ForegroundColor White
}
Write-Host "  2. Open Roo Code from the sidebar" -ForegroundColor White
Write-Host "  3. Click the profile dropdown at the top of Roo Code to switch profiles" -ForegroundColor White
Write-Host ""

if (-not $Silent) {
    Read-Host "  Press ENTER to close this window"
}
