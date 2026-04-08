#!/bin/sh
# Emit SQL: CREATE TABLE (if not exists) + INSERT all core Directus migration versions from the
# same image you run in production. Pipe into psql as a privileged user, then run
# `docker compose run --rm directus node cli.js database migrate:latest` and `docker compose up -d`.
#
# Usage (from repo host, proxy on host:5432):
#   docker run --rm internal-erp-directus:11.12.0-regnamespace-patch sh -s < docs/sql/backfill-directus-migrations.sh | \
#     docker run --rm -i -e PGPASSWORD=... postgres:16-alpine psql -h host.docker.internal -p 5432 -U sterile_dev -d bidstruct4 -v ON_ERROR_STOP=1

set -e
SCHEMA="${1:-BS4Prod09Feb2026}"

MIGDIR="$(ls -d /directus/node_modules/.pnpm/@directus+api@*/node_modules/@directus/api/dist/database/migrations 2>/dev/null | head -1)"
if [ ! -d "$MIGDIR" ]; then
  echo "Could not find migrations dir inside image" >&2
  exit 1
fi

printf 'CREATE TABLE IF NOT EXISTS "%s"."directus_migrations" (\n' "$SCHEMA"
printf '  "version" character varying(255) NOT NULL,\n'
printf '  "name" character varying(255) NOT NULL,\n'
printf '  "timestamp" timestamptz NULL DEFAULT CURRENT_TIMESTAMP,\n'
printf '  CONSTRAINT directus_migrations_pkey PRIMARY KEY ("version")\n'
printf ');\n'

for f in "$MIGDIR"/*.js; do
  [ -f "$f" ] || continue
  b=$(basename "$f" .js)
  # Same filter as @directus/api migrations runner: only 20201028A-name style files (skip run.js, etc.)
  case "$b" in
    [0-9]*[A-Z]-*) ;;
    *) continue ;;
  esac
  ver=$(printf '%s\n' "$b" | cut -d- -f1)
  rest=$(printf '%s\n' "$b" | cut -d- -f2-)
  name=$(printf '%s\n' "$rest" | tr '-' ' ')
  # Escape single quotes in name for SQL
  esc=$(printf '%s\n' "$name" | sed "s/'/''/g")
  printf "INSERT INTO \"%s\".directus_migrations (version, name) VALUES ('%s', '%s') ON CONFLICT (version) DO NOTHING;\n" "$SCHEMA" "$ver" "$esc"
done
