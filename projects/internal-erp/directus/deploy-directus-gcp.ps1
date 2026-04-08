<#
.SYNOPSIS
  Build the repo Directus image, push to Artifact Registry, deploy to Cloud Run with Cloud SQL attached.

.DESCRIPTION
  Loads secrets and settings from deploy-directus-gcp.env (default path next to this script).
  Prerequisites: gcloud CLI (authenticated), docker, Artifact Registry repo created, runtime SA with roles/cloudsql.client.

.PARAMETER EnvFile
  Path to env file. Default: deploy-directus-gcp.env alongside this script.

.EXAMPLE
  cd projects\internal-erp\directus
  Copy-Item deploy-directus-gcp.env.example deploy-directus-gcp.env
  # edit deploy-directus-gcp.env
  .\deploy-directus-gcp.ps1
#>
[CmdletBinding()]
param(
  [string] $EnvFile = (Join-Path $PSScriptRoot 'deploy-directus-gcp.env')
)

$ErrorActionPreference = 'Stop'

function Import-EnvFile {
  param([string] $Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    throw "Env file not found: $Path`nCopy deploy-directus-gcp.env.example to deploy-directus-gcp.env and fill it in."
  }
  Get-Content -LiteralPath $Path | ForEach-Object {
    $line = $_.Trim()
    if ($line -eq '' -or $line.StartsWith('#')) { return }
    $eq = $line.IndexOf('=')
    if ($eq -lt 1) { return }
    $name = $line.Substring(0, $eq).Trim()
    $val = $line.Substring($eq + 1).Trim()
    if ($val.StartsWith('"') -and $val.EndsWith('"')) {
      $val = $val.Substring(1, $val.Length - 2) -replace '\\"', '"'
    }
    elseif ($val.StartsWith("'") -and $val.EndsWith("'")) {
      $val = $val.Substring(1, $val.Length - 2) -replace "''", "'"
    }
    Set-Item -Path "Env:$name" -Value $val
  }
}

function Require-Env {
  param([string[]] $Names)
  foreach ($n in $Names) {
    $v = [Environment]::GetEnvironmentVariable($n)
    if ([string]::IsNullOrWhiteSpace($v)) {
      throw "Missing required variable in env file: $n"
    }
  }
}

Import-EnvFile -Path $EnvFile

Require-Env @(
  'GCP_PROJECT',
  'GCP_REGION',
  'AR_REPOSITORY',
  'IMAGE_NAME',
  'IMAGE_TAG',
  'CLOUDSQL_INSTANCE',
  'CLOUD_RUN_SERVICE',
  'RUNTIME_SERVICE_ACCOUNT',
  'DIRECTUS_KEY',
  'DIRECTUS_SECRET',
  'DB_DATABASE',
  'DB_USER',
  'DB_PASSWORD'
)

$gcpProject = $env:GCP_PROJECT
$region = $env:GCP_REGION
$repo = $env:AR_REPOSITORY
$imageName = $env:IMAGE_NAME
$tag = $env:IMAGE_TAG
$instance = $env:CLOUDSQL_INSTANCE
$service = $env:CLOUD_RUN_SERVICE
$runtimeSa = $env:RUNTIME_SERVICE_ACCOUNT

$allowUnauth = if ($env:ALLOW_UNAUTHENTICATED -eq 'false') { $false } else { $true }
$memory = if ($env:CLOUD_RUN_MEMORY) { $env:CLOUD_RUN_MEMORY } else { '2Gi' }
$cpu = if ($env:CLOUD_RUN_CPU) { $env:CLOUD_RUN_CPU } else { '2' }
$timeout = if ($env:CLOUD_RUN_TIMEOUT) { $env:CLOUD_RUN_TIMEOUT } else { '300' }
$minInst = if ($env:CLOUD_RUN_MIN_INSTANCES) { $env:CLOUD_RUN_MIN_INSTANCES } else { '0' }
$maxInst = if ($env:CLOUD_RUN_MAX_INSTANCES) { $env:CLOUD_RUN_MAX_INSTANCES } else { '3' }
$platform = if ($env:DOCKER_BUILD_PLATFORM) { $env:DOCKER_BUILD_PLATFORM } else { 'linux/amd64' }

$registryHost = "${region}-docker.pkg.dev"
$imageUri = "${registryHost}/${gcpProject}/${repo}/${imageName}:${tag}"

# Cloud Run + Cloud SQL: Unix socket path (colons allowed in path string)
$dbHost = "/cloudsql/${instance}"

$search0 = $env:DB_SEARCH_PATH__0
if ([string]::IsNullOrWhiteSpace($search0)) { $search0 = 'BS4Prod09Feb2026' }
$search1 = $env:DB_SEARCH_PATH__1
if ([string]::IsNullOrWhiteSpace($search1)) { $search1 = 'public' }

Write-Host "==> gcloud config (project: $gcpProject, region: $region)"
& gcloud config set project $gcpProject
& gcloud config set run/region $region

Write-Host "==> Configure Docker auth for Artifact Registry"
& gcloud auth configure-docker "${registryHost}" --quiet

Write-Host "==> docker build ($platform) -> $imageUri"
$directusRoot = $PSScriptRoot
Push-Location $directusRoot
try {
  & docker build --platform $platform -t $imageUri -f Dockerfile .
} finally {
  Pop-Location
}

Write-Host "==> docker push $imageUri"
& docker push $imageUri

# gcloud --set-env-vars: use ^:^ delimiter so commas inside values (e.g. passwords) are safe
$envPairs = @(
  "KEY=$($env:DIRECTUS_KEY)",
  "SECRET=$($env:DIRECTUS_SECRET)",
  "DB_CLIENT=pg",
  "DB_HOST=$dbHost",
  "DB_PORT=5432",
  "DB_DATABASE=$($env:DB_DATABASE)",
  "DB_USER=$($env:DB_USER)",
  "DB_PASSWORD=$($env:DB_PASSWORD)",
  "DB_SEARCH_PATH__0=$search0",
  "DB_SEARCH_PATH__1=$search1"
)

if (-not [string]::IsNullOrWhiteSpace($env:EXTRA_ENV_VARS)) {
  foreach ($chunk in ($env:EXTRA_ENV_VARS -split ',')) {
    if ($chunk.Trim()) { $envPairs += $chunk.Trim() }
  }
}

$setEnv = ($envPairs | ForEach-Object { $_ }) -join '^'
$setEnvArg = "^:^$setEnv"

Write-Host "==> Cloud Run deploy: $service (Cloud SQL: $instance)"
if ($allowUnauth) {
  & gcloud run deploy $service `
    --image $imageUri `
    --platform managed `
    --region $region `
    --service-account $runtimeSa `
    --memory $memory `
    --cpu $cpu `
    --timeout "${timeout}s" `
    --min-instances $minInst `
    --max-instances $maxInst `
    --add-cloudsql-instances $instance `
    --set-env-vars $setEnvArg `
    --allow-unauthenticated
} else {
  & gcloud run deploy $service `
    --image $imageUri `
    --platform managed `
    --region $region `
    --service-account $runtimeSa `
    --memory $memory `
    --cpu $cpu `
    --timeout "${timeout}s" `
    --min-instances $minInst `
    --max-instances $maxInst `
    --add-cloudsql-instances $instance `
    --set-env-vars $setEnvArg `
    --no-allow-unauthenticated
}

$url = & gcloud run services describe $service --region $region --format 'value(status.url)'
if ([string]::IsNullOrWhiteSpace($url)) {
  throw 'Could not read Cloud Run service URL after deploy.'
}

Write-Host "==> Set PUBLIC_URL -> $url"
& gcloud run services update $service `
  --region $region `
  --update-env-vars "^:^PUBLIC_URL=$url"

Write-Host ""
Write-Host "Done. Directus URL: $url"
Write-Host "Open ${url}/admin — ensure OAuth redirect URIs and any AUTH_* env match this host if you use SSO."
