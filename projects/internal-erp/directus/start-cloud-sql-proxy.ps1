<#
.SYNOPSIS
  Start Cloud SQL Auth Proxy using instance name and optional credentials from directus-migration.secrets.env.

.DESCRIPTION
  Non-interactive when GOOGLE_APPLICATION_CREDENTIALS is set in the secrets file or already in the environment.
  Default listen: 127.0.0.1:5432. Use -Background to spawn a separate window on Windows.
#>
param(
  [string]$SecretsPath = (Join-Path $PSScriptRoot "directus-migration.secrets.env"),
  [string]$ListenAddress = "127.0.0.1",
  [int]$Port = 5432,
  [switch]$Background
)

$ErrorActionPreference = "Stop"

function Read-DotEnvFile {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { throw "Secrets file not found: $Path" }
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

$secrets = Read-DotEnvFile -Path $SecretsPath
$instance = $secrets["CLOUDSQL_INSTANCE"]
if ([string]::IsNullOrWhiteSpace($instance)) {
  throw "CLOUDSQL_INSTANCE missing in $SecretsPath"
}

$jsonPath = $secrets["GOOGLE_APPLICATION_CREDENTIALS"]
if (-not [string]::IsNullOrWhiteSpace($jsonPath)) {
  if (-not (Test-Path -LiteralPath $jsonPath)) {
    throw "GOOGLE_APPLICATION_CREDENTIALS file not found: $jsonPath"
  }
  $env:GOOGLE_APPLICATION_CREDENTIALS = $jsonPath
}

$exe = $secrets["CLOUD_SQL_PROXY_EXE"]
if ([string]::IsNullOrWhiteSpace($exe)) {
  $exe = Get-Command cloud-sql-proxy -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
}
if ([string]::IsNullOrWhiteSpace($exe)) {
  $exe = Get-Command cloud_sql_proxy -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
}
if ([string]::IsNullOrWhiteSpace($exe)) {
  throw "Cloud SQL Proxy not found. Install gcloud component or set CLOUD_SQL_PROXY_EXE in secrets file. See https://cloud.google.com/sql/docs/postgres/sql-proxy"
}

# Cloud SQL Auth Proxy v2: defaults to 127.0.0.1:5432 for the first instance; optional ?address=&port= on the instance string.
$argForProxy = if ($ListenAddress -eq "127.0.0.1" -and $Port -eq 5432) {
  $instance
} else {
  "${instance}?address=${ListenAddress}&port=${Port}"
}

Write-Host "Starting: $exe $argForProxy"
if ($Background) {
  Start-Process -FilePath $exe -ArgumentList $argForProxy -WindowStyle Normal
  Write-Host "Proxy started in a new window. Wait until it shows 'ready for new connections' then continue."
} else {
  & $exe $argForProxy
}
