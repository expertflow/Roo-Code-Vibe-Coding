<#
.SYNOPSIS
  Apply ERP-staff Directus policy permissions on the GCP VM via psql in Docker (non-interactive).

.DESCRIPTION
  Reads GCP VM settings from directus-vm-migrate.env and DB credentials from directus-migration.secrets.env.
  Uploads a generated SQL file, runs it against 127.0.0.1:5432 on the VM (Cloud SQL Auth Proxy on host).

.PARAMETER AccessMode
  Read = read-only on all ERP schema tables + app_access on the policy.
  Full = read + create + update + delete on all ERP schema tables (use only if you mean it).

.PARAMETER PolicyId
  UUID of the Directus policy (e.g. "ERP staff read/ write").

.PARAMETER ErpSchema
  ERP Postgres schema name (must match DB_SEARCH_PATH__0).
#>
param(
  [ValidateSet("Read", "Full")]
  [string]$AccessMode = "Read",
  [string]$PolicyId = "5d3e8662-4298-4b9a-94e7-3edbeb2ba061",
  [string]$ErpSchema = "BS4Prod09Feb2026",
  [string]$MigrateEnvPath = (Join-Path $PSScriptRoot "..\directus-vm-migrate.env"),
  [string]$SecretsPath = (Join-Path $PSScriptRoot "..\directus-migration.secrets.env"),
  [string]$Database = ""
)

$ErrorActionPreference = "Stop"

function Read-DotEnvFile {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { throw "Env file not found: $Path" }
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

function Escape-BashSingleQuoted {
  param([string]$Value)
  $Value.Replace("'", "'\''")
}

if (-not (Get-Command gcloud -ErrorAction SilentlyContinue)) {
  throw "gcloud not found in PATH."
}

$m = Read-DotEnvFile -Path $MigrateEnvPath
$s = Read-DotEnvFile -Path $SecretsPath

$project = $m["GCP_PROJECT"]
$zone = $m["GCP_ZONE"]
$vm = $m["GCP_VM_NAME"]
$sshUser = $m["GCP_SSH_USER"]
$useSudo = ($m["VM_USE_SUDO_FOR_DEPLOY"] -eq "true")

if ([string]::IsNullOrWhiteSpace($project)) { throw "GCP_PROJECT missing in $MigrateEnvPath" }
if ([string]::IsNullOrWhiteSpace($zone)) { throw "GCP_ZONE missing in $MigrateEnvPath" }
if ([string]::IsNullOrWhiteSpace($vm)) { throw "GCP_VM_NAME missing in $MigrateEnvPath" }

$dbUser = if ($s["BS4_DEV_USER"]) { $s["BS4_DEV_USER"] } else { "bs4_dev" }
$dbPass = $s["BS4_DEV_PASSWORD"]
if ([string]::IsNullOrWhiteSpace($dbPass)) {
  throw "BS4_DEV_PASSWORD missing in $SecretsPath"
}

$dbName = if (-not [string]::IsNullOrWhiteSpace($Database)) {
  $Database
} elseif ($s["DB_DATABASE"]) {
  $s["DB_DATABASE"]
} else {
  "bidstruct4"
}

$policyEsc = $PolicyId.Replace("'", "''")
$schemaEsc = $ErpSchema.Replace("'", "''")

$sql = @"
BEGIN;

UPDATE directus.directus_policies
SET app_access = true
WHERE id = '$policyEsc'::uuid;

DELETE FROM directus.directus_permissions
WHERE policy = '$policyEsc'::uuid;

INSERT INTO directus.directus_permissions (
  collection,
  action,
  permissions,
  validation,
  presets,
  fields,
  policy
)
SELECT
  table_name,
  'read',
  NULL::json,
  NULL::json,
  NULL::json,
  NULL::text,
  '$policyEsc'::uuid
FROM information_schema.tables
WHERE table_schema = '$schemaEsc'
  AND table_type = 'BASE TABLE';

"@

if ($AccessMode -eq "Full") {
  $sql += @"

INSERT INTO directus.directus_permissions (
  collection,
  action,
  permissions,
  validation,
  presets,
  fields,
  policy
)
SELECT
  table_name,
  a.action,
  NULL::json,
  NULL::json,
  NULL::json,
  NULL::text,
  '$policyEsc'::uuid
FROM information_schema.tables
CROSS JOIN (
  VALUES ('create'), ('update'), ('delete')
) AS a (action)
WHERE table_schema = '$schemaEsc'
  AND table_type = 'BASE TABLE';

"@
}

$sql += "COMMIT;`n"

$tmpSql = Join-Path $env:TEMP ("erp-staff-policy-{0}.sql" -f [Guid]::NewGuid().ToString("N"))
try {
  Set-Content -LiteralPath $tmpSql -Value $sql -Encoding utf8
}
catch {
  throw "Failed to write temp SQL: $_"
}

$remotePath = "/tmp/erp-staff-policy.sql"
$dockerSudo = if ($useSudo) { "sudo " } else { "" }
$passBash = Escape-BashSingleQuoted -Value $dbPass

$scpArgs = @(
  "compute", "scp", $tmpSql, "${vm}:${remotePath}",
  "--zone", $zone, "--project", $project, "--strict-host-key-checking=no"
)
if (-not [string]::IsNullOrWhiteSpace($sshUser)) {
  $scpArgs += "--ssh-flag=-l$sshUser"
}

$remoteCmd = @"
${dockerSudo}docker run --rm --network host -v ${remotePath}:/q.sql -e PGPASSWORD='${passBash}' postgres:16-alpine psql -h 127.0.0.1 -p 5432 -U ${dbUser} -d ${dbName} -v ON_ERROR_STOP=1 -f /q.sql
"@

$sshArgs = @(
  "compute", "ssh", $vm,
  "--zone", $zone, "--project", $project,
  "--strict-host-key-checking=no"
)
if (-not [string]::IsNullOrWhiteSpace($sshUser)) {
  $sshArgs += "--ssh-flag=-l$sshUser"
}
$sshArgs += "--command"
$sshArgs += $remoteCmd

Write-Host "Uploading SQL to ${vm}:${remotePath} ..."
& gcloud @scpArgs
if ($LASTEXITCODE -ne 0) { throw "gcloud compute scp failed" }

Write-Host "Applying policy (AccessMode=$AccessMode) ..."
& gcloud @sshArgs
if ($LASTEXITCODE -ne 0) { throw "gcloud compute ssh / psql failed" }

Write-Host "Done."
Remove-Item -LiteralPath $tmpSql -Force -ErrorAction SilentlyContinue
