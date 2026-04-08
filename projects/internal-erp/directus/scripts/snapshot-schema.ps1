# Story 1.7 — export Directus schema next to docker-compose.yml (Windows PowerShell).
# Prereq: cd projects/internal-erp/directus; docker compose up -d
$ErrorActionPreference = "Stop"
$directusRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $directusRoot

$outName = if ($args[0]) { $args[0] } else { "schema.json" }
$tmp = "/tmp/directus-schema-snapshot-$PID.json"

docker compose exec -T directus npx directus schema snapshot $tmp
docker compose cp "directus:${tmp}" "./$outName"
docker compose exec -T directus rm -f $tmp

Write-Host "Wrote $(Join-Path $directusRoot $outName) - review and commit."
