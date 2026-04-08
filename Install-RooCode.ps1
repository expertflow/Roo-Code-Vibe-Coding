# ============================================================
#  Roo Code - Universal Extension Installer & Profile Setup
#  Supports: VS Code, Cursor, Antigravity
#  Version : 4.0  (IDE Selection Menu + BMAD Integration)
# ============================================================

param(
    [switch]$Silent
)

$ErrorActionPreference = "Continue"

# ---- Vault Configuration -----------------------------------
$VAULT_ADDR         = "https://45.88.223.83:31313"
$VAULT_TOKEN        = "hvs.CAESIC0nSYZlc92KbjE36r_Vncz-MznLpY0eMplhN_V6FrVaGh4KHGh2cy5jU3Q2djJMWjc2bWJPYkZhN3ZSN1JBcUc"
$VAULT_SECRET_PATH  = "cubbyhole/internal-erp/db"
$VAULT_SECRET_FIELD = "ANTHROPIC_API_KEY"

# ---- Static Configuration ----------------------------------
$ROO_EXTENSION_ID = "RooVeterinaryInc.roo-cline"
$GCP_PROJECT_ID   = "expertflowerp"
$GCP_REGION       = "us-central1"

# ---- Script directory (where .roo/ and .clinerules live) ---
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path

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
        var blob    = Encoding.Unicode.GetBytes(secret);
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
    Write-Host "   ROO CODE - Universal Installer  v4.0" -ForegroundColor Cyan
    Write-Host "   VS Code | Cursor | Antigravity" -ForegroundColor Cyan
    Write-Host "   Secrets via HashiCorp Vault + BMAD" -ForegroundColor DarkCyan
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

# ---- IDE Selection Menu ------------------------------------
function Show-IDESelectionMenu {
    param([array]$detectedIDEs)

    Write-Host ""
    Write-Host "  =============================================" -ForegroundColor Cyan
    Write-Host "   SELECT WHICH IDEs TO INSTALL ROO CODE INTO" -ForegroundColor Cyan
    Write-Host "  =============================================" -ForegroundColor Cyan
    Write-Host ""

    if ($detectedIDEs.Count -eq 0) {
        Write-Fail "No supported IDEs detected on this machine."
        Write-Host "  Supported: VS Code, Cursor, Antigravity" -ForegroundColor DarkGray
        return @()
    }

    # Build menu options
    $menuOptions = @()
    $i = 1
    foreach ($ide in $detectedIDEs) {
        $status = if ($ide.CLIPath) { "detected" } else { "settings only" }
        Write-Host "  [$i] $($ide.Name.PadRight(16)) ($status)" -ForegroundColor White
        $menuOptions += $ide
        $i++
    }

    if ($detectedIDEs.Count -gt 1) {
        Write-Host "  [A] All IDEs listed above" -ForegroundColor Green
    }
    Write-Host "  [Q] Quit / Cancel" -ForegroundColor DarkGray
    Write-Host ""

    $selected = @()

    while ($true) {
        $choice = Read-Host "  Enter your choice (number, A for all, or Q to quit)"
        $choice = $choice.Trim().ToUpper()

        if ($choice -eq "Q") {
            Write-Host ""
            Write-Host "  Installation cancelled." -ForegroundColor DarkYellow
            return $null
        }

        if ($choice -eq "A") {
            $selected = $detectedIDEs
            Write-Host ""
            Write-OK "Selected: All IDEs"
            break
        }

        # Try numeric
        $num = 0
        if ([int]::TryParse($choice, [ref]$num)) {
            if ($num -ge 1 -and $num -le $menuOptions.Count) {
                $selected = @($menuOptions[$num - 1])
                Write-Host ""
                Write-OK "Selected: $($selected[0].Name)"
                break
            }
        }

        Write-Warn "Invalid choice '$choice'. Please enter a number (1-$($menuOptions.Count)), A, or Q."
    }

    return $selected
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

# ---- Build the profiles JSON payload ------------------------
function New-ProfilesPayload {
    param([string]$anthropicKey)

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
    }

    $json = $payload | ConvertTo-Json -Depth 10 -Compress

    $byteCount = [System.Text.Encoding]::Unicode.GetByteCount($json)
    if ($byteCount -gt 2560) {
        Write-Fail "Payload too large for Windows Credential Manager: $byteCount bytes (limit 2560)."
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
        Write-Fail "$($ide.Name) - Payload generation failed."
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

# ---- BMAD Integration: Copy .roo/ and .clinerules ----------
function Install-BMADIntegration {
    param([string]$workspacePath)

    Write-Section "BMAD Integration - Copying Roo Config Files"

    if (-not $workspacePath -or -not (Test-Path $workspacePath)) {
        Write-Warn "Workspace path not found: '$workspacePath'"
        Write-Warn "BMAD files will be installed to the current directory instead."
        $workspacePath = $SCRIPT_DIR
    }

    $bmadOk = $true

    # ---- Copy .roo/ folder (mcp.json, bootstrap-mcp.ps1) ----
    $srcRoo  = Join-Path $SCRIPT_DIR ".roo"
    $destRoo = Join-Path $workspacePath ".roo"

    if (Test-Path $srcRoo) {
        try {
            if (-not (Test-Path $destRoo)) {
                New-Item -ItemType Directory -Path $destRoo -Force | Out-Null
            }

            # Copy mcp.json
            $srcMcp  = Join-Path $srcRoo "mcp.json"
            $destMcp = Join-Path $destRoo "mcp.json"
            if (Test-Path $srcMcp) {
                Copy-Item -Path $srcMcp -Destination $destMcp -Force
                Write-OK "Copied .roo/mcp.json -> $destMcp"
            }

            # Copy bootstrap-mcp.ps1
            $srcBoot  = Join-Path $srcRoo "bootstrap-mcp.ps1"
            $destBoot = Join-Path $destRoo "bootstrap-mcp.ps1"
            if (Test-Path $srcBoot) {
                Copy-Item -Path $srcBoot -Destination $destBoot -Force
                Write-OK "Copied .roo/bootstrap-mcp.ps1 -> $destBoot"
            }
        }
        catch {
            Write-Fail "Failed to copy .roo/ folder: $($_.Exception.Message)"
            $bmadOk = $false
        }
    }
    else {
        Write-Warn ".roo/ folder not found at: $srcRoo"
        Write-Warn "Skipping MCP config copy."
        $bmadOk = $false
    }

    # ---- Copy .clinerules ------------------------------------
    $srcRules  = Join-Path $SCRIPT_DIR ".clinerules"
    $destRules = Join-Path $workspacePath ".clinerules"

    if (Test-Path $srcRules) {
        try {
            Copy-Item -Path $srcRules -Destination $destRules -Force
            Write-OK "Copied .clinerules -> $destRules"
        }
        catch {
            Write-Fail "Failed to copy .clinerules: $($_.Exception.Message)"
            $bmadOk = $false
        }
    }
    else {
        Write-Warn ".clinerules not found at: $srcRules"
    }

    # ---- Copy .gitignore -------------------------------------
    $srcGit  = Join-Path $SCRIPT_DIR ".gitignore"
    $destGit = Join-Path $workspacePath ".gitignore"

    if (Test-Path $srcGit) {
        try {
            if (-not (Test-Path $destGit)) {
                Copy-Item -Path $srcGit -Destination $destGit -Force
                Write-OK "Copied .gitignore -> $destGit"
            }
            else {
                Write-OK ".gitignore already exists at destination - skipping."
            }
        }
        catch {
            Write-Warn "Could not copy .gitignore: $($_.Exception.Message)"
        }
    }

    # ---- Create docs/bmad and docs/specs stubs ---------------
    $docsPath  = Join-Path $workspacePath "docs"
    $bmadPath  = Join-Path $docsPath "bmad"
    $specsPath = Join-Path $docsPath "specs"

    foreach ($dir in @($bmadPath, $specsPath)) {
        if (-not (Test-Path $dir)) {
            try {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
                Write-OK "Created directory: $dir"
            }
            catch {
                Write-Warn "Could not create $dir : $($_.Exception.Message)"
            }
        }
        else {
            Write-OK "Directory already exists: $dir"
        }
    }

    # ---- Create README stub in docs/bmad ---------------------
    $bmadReadme = Join-Path $bmadPath "README.md"
    if (-not (Test-Path $bmadReadme)) {
        $bmadContent = @"
# BMAD Method - Business Model Architecture Design

This folder contains BMAD documentation for the ExpertFlow ERP project.

## Structure
- `architecture/` - System architecture decisions
- `epics/`        - Feature epics and user stories
- `personas/`     - User personas
- `prd/`          - Product requirements documents

## Usage
Roo Code reads this folder via the BMAD MCP server.
The `.clinerules` file instructs all AI modes to read docs/bmad before writing feature code.

## Directus Collections
The ERP database (bs4.expertflow.com) contains:
Account, Accruals, Allocation, BankStatement, Contact, Currency,
Employee, Invoice, Journal, Leaves, LegalEntity, Project, Task,
TimeEntry, Transaction, tickets, and 60+ more collections.
"@
        try {
            $bmadContent | Set-Content $bmadReadme -Encoding UTF8
            Write-OK "Created docs/bmad/README.md"
        }
        catch {
            Write-Warn "Could not create docs/bmad/README.md"
        }
    }

    # ---- Create README stub in docs/specs --------------------
    $specsReadme = Join-Path $specsPath "README.md"
    if (-not (Test-Path $specsReadme)) {
        $specsContent = @"
# API Specifications

This folder contains API contracts and implementation specs.

## Usage
Roo Code reads this folder via the SpecKit MCP server.
Update specs here when changing API contracts or database schema.
"@
        try {
            $specsContent | Set-Content $specsReadme -Encoding UTF8
            Write-OK "Created docs/specs/README.md"
        }
        catch {
            Write-Warn "Could not create docs/specs/README.md"
        }
    }

    if ($bmadOk) {
        Write-OK "BMAD integration complete."
    }
    else {
        Write-Warn "BMAD integration completed with warnings."
    }

    return $bmadOk
}

# ---- Ask for workspace path ---------------------------------
function Get-WorkspacePath {
    Write-Host ""
    Write-Host "  =============================================" -ForegroundColor Cyan
    Write-Host "   BMAD WORKSPACE SETUP" -ForegroundColor Cyan
    Write-Host "  =============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  BMAD integration copies .roo/mcp.json, .clinerules," -ForegroundColor White
    Write-Host "  and creates docs/bmad and docs/specs folders." -ForegroundColor White
    Write-Host ""
    Write-Host "  Where is your project workspace?" -ForegroundColor White
    Write-Host "  [1] Current directory ($SCRIPT_DIR)" -ForegroundColor White
    Write-Host "  [2] Enter a custom path" -ForegroundColor White
    Write-Host "  [S] Skip BMAD setup" -ForegroundColor DarkGray
    Write-Host ""

    $choice = Read-Host "  Enter choice (1, 2, or S)"
    $choice = $choice.Trim().ToUpper()

    switch ($choice) {
        "1" { return $SCRIPT_DIR }
        "S" { return $null }
        "2" {
            $customPath = Read-Host "  Enter full path to your workspace"
            $customPath = $customPath.Trim().Trim('"')
            if (Test-Path $customPath) {
                return $customPath
            }
            else {
                Write-Warn "Path not found: $customPath"
                Write-Warn "Using current directory instead."
                return $SCRIPT_DIR
            }
        }
        default { return $SCRIPT_DIR }
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
Write-Section "Step 0 of 5 - Fetching Secrets from HashiCorp Vault"

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
Write-Section "Step 1 of 5 - Detecting Installed IDEs"
$allDetectedIDEs = Get-InstalledIDEs

if ($allDetectedIDEs.Count -eq 0) {
    Write-Fail "No supported IDE found on this machine."
    Write-Host ""
    Write-Host "  Supported: VS Code, Cursor, Antigravity" -ForegroundColor DarkGray
    Write-Host "  Install at least one IDE and re-run this script." -ForegroundColor DarkGray
    Write-Host ""
    if (-not $Silent) { Read-Host "  Press ENTER to exit" }
    exit 1
}

Write-Host ""
foreach ($ide in $allDetectedIDEs) {
    $cliDisplay = if ($ide.CLIPath) { $ide.CLIPath } else { "(CLI not in PATH - settings only)" }
    Write-OK "Found: $($ide.Name.PadRight(16)) -> $cliDisplay"
}

# Step 2: IDE Selection Menu
Write-Section "Step 2 of 5 - IDE Selection"

$selectedIDEs = $null
if ($Silent) {
    # In silent mode, install to all detected IDEs
    $selectedIDEs = $allDetectedIDEs
    Write-OK "Silent mode: installing to all detected IDEs."
}
else {
    $selectedIDEs = Show-IDESelectionMenu -detectedIDEs $allDetectedIDEs
}

if ($null -eq $selectedIDEs) {
    Write-Host ""
    Write-Host "  Installation cancelled by user." -ForegroundColor DarkYellow
    Read-Host "  Press ENTER to exit"
    exit 0
}

if ($selectedIDEs.Count -eq 0) {
    Write-Fail "No IDEs selected."
    if (-not $Silent) { Read-Host "  Press ENTER to exit" }
    exit 1
}

Write-Host ""
Write-Host "  Installing to:" -ForegroundColor Cyan
foreach ($ide in $selectedIDEs) {
    Write-Host "    - $($ide.Name)" -ForegroundColor White
}

# Step 3: Install Roo Code extension
Write-Section "Step 3 of 5 - Installing Roo Code Extension"

$installResults = @{}
foreach ($ide in $selectedIDEs) {
    $ok = Install-Extension -ide $ide -extensionId $ROO_EXTENSION_ID
    $installResults[$ide.Name] = $ok
}

# Step 4: Write profiles to each selected IDE
Write-Section "Step 4 of 5 - Building & Writing Configuration Profiles"

Write-OK "Profile 1 -> Gemini-2.5-pro    (GCP Vertex AI | Project: $GCP_PROJECT_ID | Region: $GCP_REGION)"
Write-OK "Profile 2 -> Gemini-2.5-flash  (GCP Vertex AI | Project: $GCP_PROJECT_ID | Region: $GCP_REGION)"
Write-OK "Profile 3 -> Claude Sonnet     (Anthropic | Model: claude-sonnet-4-6)"
Write-OK "Profile 4 -> Claude Opus       (Anthropic | Model: claude-opus-4-6)"
Write-Host ""

$profileResults = @{}
foreach ($ide in $selectedIDEs) {
    $ok = Set-RooProfiles -ide $ide -anthropicKey $ANTHROPIC_API_KEY
    $profileResults[$ide.Name] = $ok
}

# Step 5: BMAD Integration
Write-Section "Step 5 of 5 - BMAD Integration"

$workspacePath = $null
if ($Silent) {
    $workspacePath = $SCRIPT_DIR
    Write-OK "Silent mode: using script directory for BMAD files."
}
else {
    $workspacePath = Get-WorkspacePath
}

$bmadResult = $false
if ($null -ne $workspacePath) {
    $bmadResult = Install-BMADIntegration -workspacePath $workspacePath
}
else {
    Write-Warn "BMAD setup skipped by user."
}

# Final Summary
Write-Section "Installation Complete - Summary"

$allGood = $true
foreach ($ide in $selectedIDEs) {
    $extOk      = $installResults[$ide.Name]
    $profOk     = $profileResults[$ide.Name]
    $extStatus  = if ($extOk)  { "[OK] Extension" } else { "[!!] Extension (check manually)" }
    $profStatus = if ($profOk) { "[OK] Profiles"  } else { "[!!] Profiles (check manually)"  }
    if (-not $extOk -or -not $profOk) { $allGood = $false }
    Write-Host "  $($ide.Name.PadRight(24)) $extStatus  |  $profStatus" -ForegroundColor White
}

$bmadStatus = if ($bmadResult) { "[OK] BMAD files copied" } elseif ($null -eq $workspacePath) { "[--] BMAD skipped" } else { "[!!] BMAD partial" }
Write-Host "  $("BMAD Integration".PadRight(24)) $bmadStatus" -ForegroundColor White

Write-Host ""
Write-Host "  -----------------------------------------------" -ForegroundColor DarkGray

if ($allGood) {
    Write-Host "  SUCCESS! All selected IDEs configured." -ForegroundColor Green
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

if ($bmadResult) {
    Write-Host "  BMAD files installed:" -ForegroundColor DarkGray
    Write-Host "    - .roo/mcp.json        (8 MCP servers configured)" -ForegroundColor DarkGray
    Write-Host "    - .roo/bootstrap-mcp.ps1 (Vault secret resolver)" -ForegroundColor DarkGray
    Write-Host "    - .clinerules          (AI coding rules)" -ForegroundColor DarkGray
    Write-Host "    - docs/bmad/README.md  (BMAD documentation stub)" -ForegroundColor DarkGray
    Write-Host "    - docs/specs/README.md (API specs stub)" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Run .roo/bootstrap-mcp.ps1 to resolve Vault secrets" -ForegroundColor DarkYellow
    Write-Host "  into .roo/mcp.resolved.json for MCP server use." -ForegroundColor DarkYellow
    Write-Host ""
}

# ---- Auto-restart selected IDEs ----------------------------
Write-Section "Restarting IDEs"

$ideProcessMap = @{
    "VS Code"     = @("Code")
    "Cursor"      = @("Cursor")
    "Antigravity" = @("Antigravity", "antigravity")
}

$restartedAny = $false
foreach ($ide in $selectedIDEs) {
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
    Write-Host "  1. Restart your IDE (required for credential changes to take effect)" -ForegroundColor White
}
Write-Host "  2. Open Roo Code from the sidebar" -ForegroundColor White
Write-Host "  3. Click the profile dropdown at the top of Roo Code to switch profiles" -ForegroundColor White
if ($bmadResult) {
    Write-Host "  4. Run .roo/bootstrap-mcp.ps1 to activate MCP servers" -ForegroundColor White
}
Write-Host ""

if (-not $Silent) {
    Read-Host "  Press ENTER to close this window"
}
