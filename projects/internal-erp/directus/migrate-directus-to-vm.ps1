<#
.SYNOPSIS
  Pack projects/internal-erp/directus (with sensible excludes), upload to GCE VM, extract, optionally docker compose build/up.

.DESCRIPTION
  Prerequisites on the VM (manual or separate runbook): Docker + Compose plugin, Cloud SQL reachability
  (e.g. Auth Proxy on host :5432), and a valid .env at VM_DEPLOY_PATH (or set VM_ENV_FILE_TO_UPLOAD).

.PARAMETER EnvFile
  Path to env file (default: directus-vm-migrate.env next to this script).

.PARAMETER VmEnvFile
  If set, uploads this file as the VM's .env (overrides VM_ENV_FILE_TO_UPLOAD from the env file).
  Use with build-directus-vm-env.ps1 output for non-interactive deploys.
#>
param(
  [string]$EnvFile = (Join-Path $PSScriptRoot "directus-vm-migrate.env"),
  [string]$VmEnvFile
)

$ErrorActionPreference = "Stop"

function Read-DotEnv {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    throw "Env file not found: $Path. Copy directus-vm-migrate.env.example to directus-vm-migrate.env and fill in."
  }
  Get-Content -LiteralPath $Path | ForEach-Object {
    $line = $_.Trim()
    if ($line -eq "" -or $line.StartsWith("#")) { return }
    $i = $line.IndexOf("=")
    if ($i -lt 1) { return }
    $k = $line.Substring(0, $i).Trim()
    $v = $line.Substring($i + 1).Trim()
    if ($v.StartsWith('"') -and $v.EndsWith('"')) { $v = $v.Substring(1, $v.Length - 2) }
    Set-Item -Path "Env:\$k" -Value $v
  }
}

Read-DotEnv -Path $EnvFile

$required = @("GCP_PROJECT", "GCP_ZONE", "GCP_VM_NAME", "VM_DEPLOY_PATH")
foreach ($k in $required) {
  $val = [Environment]::GetEnvironmentVariable($k, "Process")
  if ([string]::IsNullOrWhiteSpace($val)) { throw "Missing required key in env file: $k" }
}

$GCP_PROJECT = [Environment]::GetEnvironmentVariable("GCP_PROJECT", "Process")
$GCP_ZONE = [Environment]::GetEnvironmentVariable("GCP_ZONE", "Process")
$GCP_VM_NAME = [Environment]::GetEnvironmentVariable("GCP_VM_NAME", "Process")
$VM_DEPLOY_PATH = [Environment]::GetEnvironmentVariable("VM_DEPLOY_PATH", "Process").TrimEnd("/")

$LOCAL_DIRECTUS_DIR = [Environment]::GetEnvironmentVariable("LOCAL_DIRECTUS_DIR", "Process")
if ([string]::IsNullOrWhiteSpace($LOCAL_DIRECTUS_DIR)) { $LOCAL_DIRECTUS_DIR = $PSScriptRoot }

$GCP_SSH_USER = [Environment]::GetEnvironmentVariable("GCP_SSH_USER", "Process")
$VM_USE_SUDO = ([Environment]::GetEnvironmentVariable("VM_USE_SUDO_FOR_DEPLOY", "Process") -eq "true")
$VM_ENV_FILE_TO_UPLOAD = if (-not [string]::IsNullOrWhiteSpace($VmEnvFile)) {
  $VmEnvFile
} else {
  [Environment]::GetEnvironmentVariable("VM_ENV_FILE_TO_UPLOAD", "Process")
}
$VM_COMPOSE_FILE = [Environment]::GetEnvironmentVariable("VM_COMPOSE_FILE", "Process")
if ([string]::IsNullOrWhiteSpace($VM_COMPOSE_FILE)) { $VM_COMPOSE_FILE = "docker-compose.yml" }
$SKIP_BUILD = ([Environment]::GetEnvironmentVariable("SKIP_BUILD", "Process") -eq "true")
$DRY_RUN = ([Environment]::GetEnvironmentVariable("DRY_RUN", "Process") -eq "true")

if (-not (Test-Path -LiteralPath (Join-Path $LOCAL_DIRECTUS_DIR "Dockerfile"))) {
  throw "LOCAL_DIRECTUS_DIR does not look like the Directus app root (no Dockerfile): $LOCAL_DIRECTUS_DIR"
}

if (-not (Get-Command gcloud -ErrorAction SilentlyContinue)) {
  throw "gcloud not found in PATH. Install Google Cloud SDK and authenticate."
}

$folderName = Split-Path -Leaf $LOCAL_DIRECTUS_DIR
$parent = Split-Path -Parent $LOCAL_DIRECTUS_DIR
$tgz = Join-Path $env:TEMP "directus-vm-migrate-$folderName.tgz"
if (Test-Path $tgz) { Remove-Item -Force $tgz }

Write-Host "Packing $LOCAL_DIRECTUS_DIR -> $tgz (excluding .git, uploads, .env, node_modules)..."
Push-Location $parent
try {
  $excludes = @(
    "--exclude=$folderName/.git",
    "--exclude=$folderName/uploads",
    "--exclude=$folderName/.env",
    "--exclude=$folderName/extensions/bank-statement-import-ui/node_modules",
    "--exclude=$folderName/directus-vm-migrate.env",
    "--exclude=$folderName/directus-migration.secrets.env",
    "--exclude=$folderName/directus-vm-runtime.env"
  )
  & tar -czf $tgz @excludes $folderName
  if ($LASTEXITCODE -ne 0) { throw "tar failed with exit $LASTEXITCODE" }
}
finally {
  Pop-Location
}

$remoteTgz = "directus-vm-migrate.tgz"

function Invoke-GcloudSsh {
  param([string]$RemoteCommand)
  $sshArgs = @("compute", "ssh", $GCP_VM_NAME, "--zone", $GCP_ZONE, "--project", $GCP_PROJECT,
    "--strict-host-key-checking=no")
  if (-not [string]::IsNullOrWhiteSpace($GCP_SSH_USER)) {
    $sshArgs += "--ssh-flag=-l$GCP_SSH_USER"
  }
  $sshArgs += "--command"
  $sshArgs += $RemoteCommand
  & gcloud @sshArgs
  if ($LASTEXITCODE -ne 0) { throw "gcloud compute ssh failed" }
}

Write-Host "Uploading archive..."
$scpArgs = @("compute", "scp", $tgz, "${GCP_VM_NAME}:${remoteTgz}", "--zone", $GCP_ZONE, "--project", $GCP_PROJECT, "--strict-host-key-checking=no")
& gcloud @scpArgs
if ($LASTEXITCODE -ne 0) { throw "gcloud compute scp failed" }

# Extract on VM (sudo optional). After strip-components=1, VM_DEPLOY_PATH contains Dockerfile, etc.
if ($VM_USE_SUDO) {
  $extractRemote = @"
set -e
sudo mkdir -p '$VM_DEPLOY_PATH'
sudo tar -xzf $remoteTgz -C '$VM_DEPLOY_PATH' --strip-components=1
sudo chown -R `$(id -un):`$(id -gn) '$VM_DEPLOY_PATH'
rm -f $remoteTgz
"@
}
else {
  $extractRemote = @"
set -e
mkdir -p '$VM_DEPLOY_PATH'
tar -xzf $remoteTgz -C '$VM_DEPLOY_PATH' --strip-components=1
rm -f $remoteTgz
"@
}

Write-Host "Extracting on VM -> $VM_DEPLOY_PATH ..."
Invoke-GcloudSsh -RemoteCommand $extractRemote

if (-not [string]::IsNullOrWhiteSpace($VmEnvFile) -and -not (Test-Path -LiteralPath $VmEnvFile)) {
  throw "VmEnvFile path not found: $VmEnvFile"
}

if (-not [string]::IsNullOrWhiteSpace($VM_ENV_FILE_TO_UPLOAD)) {
  if (-not (Test-Path -LiteralPath $VM_ENV_FILE_TO_UPLOAD)) {
    throw "VM_ENV_FILE_TO_UPLOAD path not found: $VM_ENV_FILE_TO_UPLOAD"
  }
  Write-Host "Uploading .env..."
  $scpEnvArgs = @("compute", "scp", $VM_ENV_FILE_TO_UPLOAD, "${GCP_VM_NAME}:${VM_DEPLOY_PATH}/.env", "--zone", $GCP_ZONE, "--project", $GCP_PROJECT, "--strict-host-key-checking=no")
  & gcloud @scpEnvArgs
  if ($LASTEXITCODE -ne 0) { throw "gcloud scp .env failed" }
}

if ($DRY_RUN) {
  Write-Host "DRY_RUN=true: skipping docker compose. Ensure .env exists on VM before manual up."
  exit 0
}

$dockerCmd = if ($VM_USE_SUDO) { "sudo docker" } else { "docker" }
$dockerRemote = "set -e && cd '$VM_DEPLOY_PATH' && "
if (-not $SKIP_BUILD) {
  $dockerRemote += "$dockerCmd compose -f '$VM_COMPOSE_FILE' build && "
}
$dockerRemote += "$dockerCmd compose -f '$VM_COMPOSE_FILE' up -d"

Write-Host "Running docker compose on VM..."
Invoke-GcloudSsh -RemoteCommand $dockerRemote

Write-Host "Done. Verify health and PUBLIC_URL as documented in directus-gcp-runtime-context.md."
