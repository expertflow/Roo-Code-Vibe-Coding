<#
.SYNOPSIS
  Non-interactive path: build VM .env from secrets, optionally verify DB port, deploy to GCE via migrate-directus-to-vm.ps1.

.DESCRIPTION
  Prerequisites:
  - gcloud usable for SSH/SCP: either existing `gcloud auth login`, or GCP_DEPLOYER_KEY_FILE in directus-migration.secrets.env (preflight activates it).
  - directus-migration.secrets.env filled (copy from .example).
  - directus-vm-migrate.env filled (copy from directus-vm-migrate.env.example).

  Optional -VerifyDbPort: requires Cloud SQL Auth Proxy on 127.0.0.1:5432 (.\start-cloud-sql-proxy.ps1 -Background).
  Deploying code to the VM does not require a local DB tunnel unless you use that switch or owner SQL scripts.
#>
param(
  [string]$SecretsPath = (Join-Path $PSScriptRoot "directus-migration.secrets.env"),
  [string]$MigrateEnvPath = (Join-Path $PSScriptRoot "directus-vm-migrate.env"),
  [string]$RuntimeEnvOut = (Join-Path $PSScriptRoot "directus-vm-runtime.env"),
  [switch]$SkipBuildVmEnv,
  # Set when Cloud SQL Proxy is already on 127.0.0.1:5432 and you want a preflight TCP check.
  [switch]$VerifyDbPort
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command gcloud -ErrorAction SilentlyContinue)) {
  throw "gcloud not found in PATH."
}

& (Join-Path $PSScriptRoot "preflight-gcp-migrate-from-secrets.ps1") -SecretsPath $SecretsPath -MigrateEnvPath $MigrateEnvPath

if (-not $SkipBuildVmEnv) {
  & (Join-Path $PSScriptRoot "build-directus-vm-env.ps1") -SecretsPath $SecretsPath -OutputPath $RuntimeEnvOut
}

if (-not (Test-Path -LiteralPath $RuntimeEnvOut)) {
  throw "VM runtime env missing: $RuntimeEnvOut. Run without -SkipBuildVmEnv or run build-directus-vm-env.ps1."
}

if ($VerifyDbPort) {
  $tcp = Test-NetConnection -ComputerName 127.0.0.1 -Port 5432 -WarningAction SilentlyContinue
  if (-not $tcp.TcpTestSucceeded) {
    throw "Nothing listening on 127.0.0.1:5432. Start Cloud SQL Auth Proxy first: .\start-cloud-sql-proxy.ps1 -Background"
  }
}

$migrateScript = Join-Path $PSScriptRoot "migrate-directus-to-vm.ps1"
$migrateArgs = @{
  EnvFile   = $MigrateEnvPath
  VmEnvFile = $RuntimeEnvOut
}

Write-Host "Running migrate-directus-to-vm.ps1 with VM env: $RuntimeEnvOut"
& $migrateScript @migrateArgs
if ($LASTEXITCODE -ne 0) { throw "Migration script failed." }

Write-Host "Done. On the VM, Cloud SQL must be reachable from Docker (host proxy or private IP); see directus-gcp-runtime-context.md."
