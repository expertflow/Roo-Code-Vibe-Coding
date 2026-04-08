#Requires -Version 5.1
<#
.SYNOPSIS
  Run docs/sql/fix-rls-invoice-transaction-finance-dml.sql as break-glass bs4_dev.

.DESCRIPTION
  Reads BS4_DEV_PASSWORD from $env:BS4_DEV_PASSWORD or from .env next to docker-compose.yml:
    projects/internal-erp/directus/.env

  Quoted values are supported (required if the password contains # or spaces):
    BS4_DEV_PASSWORD="p#a#ss"
    BS4_DEV_PASSWORD='p#a#ss'

.PARAMETER VerifyEnvOnly
  Only check that the password can be read; print length, not the secret. Exit 0/1.

.PARAMETER NoDocker
  Fail if psql is missing (do not try Docker). Default: use postgres image when psql absent.

.NOTES
  Prereqs: Cloud SQL Auth Proxy on 127.0.0.1:5432.
  Runs psql from PATH, or — if psql is missing — `docker run postgres:16-alpine` (requires Docker Desktop;
  container reaches the proxy via host.docker.internal).
#>
param(
  [switch]$VerifyEnvOnly,
  [switch]$NoDocker
)

$ErrorActionPreference = 'Stop'

$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$root = Split-Path -Parent $scriptDir
$sql = Join-Path $root 'docs\sql\fix-rls-invoice-transaction-finance-dml.sql'
$dotEnv = Join-Path $root '.env'

if (-not $VerifyEnvOnly) {
  if (-not (Test-Path $sql)) { throw "Missing SQL file: $sql" }
}

function Read-DotEnvFileRaw {
  param([string]$EnvFilePath)
  if (-not (Test-Path -LiteralPath $EnvFilePath)) { return $null }
  $bytes = [System.IO.File]::ReadAllBytes($EnvFilePath)
  if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
    return [System.Text.Encoding]::Unicode.GetString($bytes)
  }
  if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    return [System.Text.UTF8Encoding]::new($false).GetString($bytes, 3, $bytes.Length - 3)
  }
  return [System.Text.UTF8Encoding]::new($false).GetString($bytes)
}

<#
  Parse value for KEY=value allowing:
  - Double-quoted (handles # inside); optional \" inside
  - Single-quoted (handles # inside)
  - Unquoted: trim; strip trailing inline comment only for " # " (space-hash-space) or end " #..."
#>
function Parse-DotEnvValue {
  param([string]$AfterEquals)
  $s = $AfterEquals.TrimStart()
  if ($s.Length -eq 0) { return '' }

  if ($s[0] -eq [char]'"') {
    $sb = [System.Text.StringBuilder]::new()
    for ($i = 1; $i -lt $s.Length; $i++) {
      $c = $s[$i]
      if ($c -eq [char]'"') { break }
      if ($c -eq [char]'\' -and $i + 1 -lt $s.Length) {
        $n = $s[$i + 1]
        if ($n -eq [char]'"' -or $n -eq [char]'\') { [void]$sb.Append($n); $i++; continue }
      }
      [void]$sb.Append($c)
    }
    return $sb.ToString()
  }

  if ($s[0] -eq [char]"'") {
    $end = $s.IndexOf("'", 1)
    if ($end -lt 0) { return $s.Substring(1) }
    return $s.Substring(1, $end - 1)
  }

  $unquoted = $s.TrimEnd()
  $hashSpace = $unquoted.IndexOf(' #')
  if ($hashSpace -ge 0) { $unquoted = $unquoted.Substring(0, $hashSpace).TrimEnd() }
  return $unquoted
}

function Get-Bs4PasswordFromEnvFile {
  param([string]$EnvFilePath)
  $text = Read-DotEnvFileRaw $EnvFilePath
  if (-not $text) { return $null }

  foreach ($line in $text -split "`r?`n") {
    $t = $line.Trim()
    if ($t -match '^\s*#' -or $t -eq '') { continue }
    if ($t -notmatch '^(?:export\s+)?BS4_DEV_PASSWORD\s*=') { continue }
    $idx = $t.IndexOf('=')
    if ($idx -lt 0) { continue }
    $after = $t.Substring($idx + 1)
    $v = Parse-DotEnvValue $after
    if ($v) { return $v }
  }
  return $null
}

$pass = $env:BS4_DEV_PASSWORD
if (-not $pass) {
  $pass = Get-Bs4PasswordFromEnvFile $dotEnv
}

if ($VerifyEnvOnly) {
  Write-Host "Expected .env path: $dotEnv"
  Write-Host "File exists: $(Test-Path -LiteralPath $dotEnv)"
  if ($pass) {
    Write-Host "BS4_DEV_PASSWORD: readable (length $($pass.Length))"
    exit 0
  }
  Write-Host 'BS4_DEV_PASSWORD: NOT readable (check name, quotes, and file location).'
  exit 1
}

if (-not $pass) {
  $exists = Test-Path -LiteralPath $dotEnv
  throw @"
Missing bs4_dev password.

Tried:
  - environment variable BS4_DEV_PASSWORD
  - file: $dotEnv (exists: $exists)

Required location: same folder as docker-compose.yml:
  projects/internal-erp/directus/.env

Use quotes if the password contains # or spaces:
  BS4_DEV_PASSWORD=`"your#secret`"

Or one session:
  `$env:BS4_DEV_PASSWORD = 'your-password'
"@
}

$env:PGPASSWORD = $pass
$env:PGUSER = 'bs4_dev'
if (-not $env:PGDATABASE) { $env:PGDATABASE = 'bidstruct4' }
if (-not $env:PGHOST) { $env:PGHOST = '127.0.0.1' }
if (-not $env:PGPORT) { $env:PGPORT = '5432' }

$psql = Get-Command psql -ErrorAction SilentlyContinue
$docker = Get-Command docker -ErrorAction SilentlyContinue
$exit = 0

if ($psql) {
  Write-Host "Running $sql as ${env:PGUSER}@${env:PGHOST}:${env:PGPORT}/${env:PGDATABASE} (native psql)"
  & psql -v ON_ERROR_STOP=1 -f $sql
  $exit = $LASTEXITCODE
}
elseif ($docker -and -not $NoDocker) {
  $sqlDir = Split-Path -Parent $sql
  $sqlLeaf = Split-Path -Leaf $sql
  $mountPath = (Resolve-Path -LiteralPath $sqlDir).Path
  Write-Host "psql not on PATH; using Docker postgres:16-alpine → host.docker.internal:5432 / $($env:PGDATABASE)"
  Write-Host "Mounted SQL dir: $mountPath"
  & docker run --rm `
    -e "PGPASSWORD=$pass" `
    -e PGUSER=bs4_dev `
    -e "PGDATABASE=$($env:PGDATABASE)" `
    -e PGPORT=5432 `
    -e PGHOST=host.docker.internal `
    -v "${mountPath}:/sql:ro" `
    postgres:16-alpine `
    psql -v ON_ERROR_STOP=1 -f "/sql/$sqlLeaf"
  $exit = $LASTEXITCODE
}
else {
  Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
  throw @'
psql not found on PATH and Docker is not available (or you passed -NoDocker).

Options:
  • Install PostgreSQL client tools and add psql to PATH, or
  • Install Docker Desktop and retry (script will use postgres:16-alpine), or
  • Run the SQL manually in DBeaver / Cloud SQL Studio as bs4_dev:
      docs/sql/fix-rls-invoice-transaction-finance-dml.sql
'@
}

Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
if ($exit -ne 0) { exit $exit }
Write-Host 'Done.'
