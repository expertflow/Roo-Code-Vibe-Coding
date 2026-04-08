# Pinned to match docker-compose / Cloud Run reproducibility.
# Patches @directus/schema so mixed-case PostgreSQL schema names work with ::regnamespace.
FROM directus/directus:11.12.0

USER root
COPY docker/patch-directus-pg-regnamespace.cjs /tmp/patch-directus-pg-regnamespace.cjs
RUN node /tmp/patch-directus-pg-regnamespace.cjs && rm -f /tmp/patch-directus-pg-regnamespace.cjs

# Story 3-1 — Python bank-import CLI (UBS + registry); used by bank-statement-import endpoint.
# Official Directus image is Alpine-based (apk), not Debian (apt-get).
RUN apk add --no-cache python3
COPY bank-import /directus/bank-import
# Cloud Run / pushed images: compose bind-mounts ./extensions locally; production image must include them.
COPY extensions /directus/extensions

USER node
