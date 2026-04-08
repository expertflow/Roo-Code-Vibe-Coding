-- Repair: Directus expects "directus_migrations" in the same schema as other directus_* tables.
-- Your inventory showed all system tables under BS4Prod09Feb2026 but directus_migrations was missing.
-- Run as a role with CREATE on schema "BS4Prod09Feb2026" (often break-glass DBA if sterile_dev cannot CREATE).

CREATE TABLE IF NOT EXISTS "BS4Prod09Feb2026"."directus_migrations" (
  "version" character varying(255) NOT NULL,
  "name" character varying(255) NOT NULL,
  "timestamp" timestamptz NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT directus_migrations_pkey PRIMARY KEY ("version")
);
