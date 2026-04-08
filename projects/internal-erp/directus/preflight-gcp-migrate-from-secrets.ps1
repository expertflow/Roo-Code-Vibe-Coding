<#
.SYNOPSIS
  Optional non-interactive gcloud auth from directus-migration.secrets.env before deploy.

.DESCRIPTION
  If GCP_DEPLOYER_KEY_FILE is set to a service account JSON path, runs:
    gcloud auth activate-service-account --key-file=... --project=... (from directus-vm-migrate.env)
  If unset or empty, does nothing (uses whatever account gcloud auth list already has).

  The deploy SA must be allowed to use compute ssh/scp for directus-erp (e.g. OS Login + compute access).
#>
param(
  [string]$SecretsPath = (Join-Path $PSScriptRoot "directus-migration.secrets.env"),
  [string]$MigrateEnvPath = (Join-Path $PSScriptRoot "directus-vm-migrate.env")
)

$ErrorActionPreference = "Stop"

function Read-DotEnvMap {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { throw "File not found: $Path" }
  $map = @{}
  Get-Content -LiteralPath $Path | ForEach-Object {
    $line = $_.Trim()
    if ($line -eq "" -or $line.StartsWith("#")) { return }
    $i = $line.IndexOf("=")
    if ($i -lt 1) { return }
    $k = $line.Substring(0, $i).Trim()
    $v = $line.Substring($i + 1).Trim()
    if ($v.StartsWith('"') -and $v.EndsWith('"') -and $v.Length -ge 2) { $v = $v.Substring(1, $v.Length - 2) }
    $map[$k] = $v
  }
  $map
}

if (-not (Get-Command gcloud -ErrorAction SilentlyContinue)) {
  throw "gcloud not found in PATH."
}

$s = Read-DotEnvMap -Path $SecretsPath
$m = Read-DotEnvMap -Path $MigrateEnvPath
$proj = $m["GCP_PROJECT"]
if ([string]::IsNullOrWhiteSpace($proj)) {
  throw "GCP_PROJECT missing in $MigrateEnvPath"
}

$keyFile = $s["GCP_DEPLOYER_KEY_FILE"]
if ([string]::IsNullOrWhiteSpace($keyFile)) {
  Write-Host "Preflight: GCP_DEPLOYER_KEY_FILE not set - using existing gcloud active account."
  return
}

if (-not (Test-Path -LiteralPath $keyFile)) {
  throw "GCP_DEPLOYER_KEY_FILE path not found: $keyFile"
}

Write-Host "Preflight: gcloud auth activate-service-account (project=$proj)..."
& gcloud auth activate-service-account "--key-file=$keyFile" "--project=$proj"
if ($LASTEXITCODE -ne 0) { throw "gcloud auth activate-service-account failed with exit $LASTEXITCODE" }
$env:CLOUDSDK_CORE_PROJECT = $proj
