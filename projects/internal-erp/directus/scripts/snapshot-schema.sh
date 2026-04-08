#!/usr/bin/env sh
# Story 1.7 — export Directus schema next to docker-compose.yml.
# Prereq: from projects/internal-erp/directus, stack is up: docker compose up -d
set -e
cd "$(dirname "$0")/.."
OUT_NAME="${1:-schema.json}"
TMP="/tmp/directus-schema-snapshot-$$.json"
docker compose exec -T directus npx directus schema snapshot "$TMP"
docker compose cp "directus:$TMP" "./$OUT_NAME"
docker compose exec -T directus rm -f "$TMP"
echo "Wrote $(pwd)/$OUT_NAME — review and commit."
