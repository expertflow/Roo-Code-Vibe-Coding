<#
.SYNOPSIS
  Run a SQL file as the owner/DBA role through Cloud SQL Proxy on localhost (non-interactive).

.DESCRIPTION
  Uses BS4_DEV_USER / BS4_DEV_PASSWORD from directus-migration.secrets.env — not for Directus runtime.
  Requires psql on PATH and proxy listening on 127.0.0.1:5432.
#>
param(
  [Parameter(Mandatory = $true)]
  [string]$SqlFile,
  [string]$SecretsPath = (Join-Path $PSScriptRoot "directus-migration.secrets.env"),
  [string]$HostAddr = "127.0.0.1",
  [int]$Port = 5432,
  [string]$Database = "bidstruct4"
)

$ErrorActionPreference = "Stop"
if (-not (Test-Path -LiteralPath $SqlFile)) { throw "SQL file not found: $SqlFile" }
if (-not (Get-Command psql -ErrorAction SilentlyContinue)) {
  throw "psql not found on PATH. Install PostgreSQL client tools or use Cloud Shell."
}

function Read-DotEnvFile {
  param([string]$Path)
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

$s = Read-DotEnvFile -Path $SecretsPath
$user = if ($s["BS4_DEV_USER"]) { $s["BS4_DEV_USER"] } else { "bs4_dev" }
$pass = $s["BS4_DEV_PASSWORD"]
if ([string]::IsNullOrWhiteSpace($pass)) {
  throw "BS4_DEV_PASSWORD missing in $SecretsPath (owner SQL only; never use for Directus)."
}

$env:PGPASSWORD = $pass
& psql -h $HostAddr -p $Port -U $user -d $Database -v ON_ERROR_STOP=1 -f $SqlFile
if ($LASTEXITCODE -ne 0) { throw "psql failed with exit $LASTEXITCODE" }
