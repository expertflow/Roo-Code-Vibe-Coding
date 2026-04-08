#!/usr/bin/env bash
# =============================================================================
# vault-fetch-secrets.sh
# Fetches secrets from HashiCorp Vault and writes:
#   - projects/internal-erp/directus/.env
#
# Supports two Vault layouts:
#   SHARED mode  (after admin runs vault-admin-setup.sh):
#     bs4/postgresql  -> DB credentials
#     bs4/directus    -> Directus credentials
#     bs4/ai-tools    -> Anthropic API key
#
#   LEGACY mode  (original single-path cubbyhole):
#     cubbyhole/internal-erp/db  -> all secrets flat
#
# Usage:
#   export VAULT_TOKEN="hvs.xxx"
#   chmod +x vault-fetch-secrets.sh
#   ./vault-fetch-secrets.sh
# =============================================================================

set -euo pipefail

VAULT_ADDR="https://45.88.223.83:31313"
VAULT_PATH_PG="bs4/postgresql"
VAULT_PATH_DIRECTUS="bs4/directus"
VAULT_PATH_AI="bs4/ai-tools"
VAULT_PATH_LEGACY="cubbyhole/internal-erp/db"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_OUT="$SCRIPT_DIR/.env"

echo ""
echo "========================================"
echo " Vault Secret Fetch -- internal-erp"
echo "========================================"
echo ""

# ── Token ─────────────────────────────────────────────────────────────────────
if [ -z "${VAULT_TOKEN:-}" ]; then
    read -rsp "Enter VAULT_TOKEN: " VAULT_TOKEN
    echo ""
fi

if [ -z "$VAULT_TOKEN" ] || [ ${#VAULT_TOKEN} -lt 10 ]; then
    echo "ERROR: No Vault token provided." >&2
    exit 1
fi

# ── Helper: GET a KV v1 path, return the raw JSON ─────────────────────────────
vault_get() {
    curl -sk -H "X-Vault-Token: $VAULT_TOKEN" "$VAULT_ADDR/v1/$1"
}

# Check if a vault response has errors
has_error() {
    echo "$1" | grep -q '"errors"'
}

# Extract a field from vault response .data using python3 or grep fallback
extract_field() {
    local json="$1"
    local key="$2"
    # Try python3 first (most reliable)
    if command -v python3 &>/dev/null; then
        python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d['data']['$key'])" <<< "$json" 2>/dev/null
    else
        # Fallback: grep-based extraction (works for simple values)
        echo "$json" | grep -o "\"$key\":\"[^\"]*\"" | cut -d'"' -f4
    fi
}

require_field() {
    local val="$1"
    local key="$2"
    local path="$3"
    if [ -z "$val" ]; then
        echo "ERROR: Required field '$key' missing in Vault at $path" >&2
        exit 1
    fi
    echo "$val"
}

# ── Auto-detect layout ────────────────────────────────────────────────────────
echo "Detecting Vault secret layout..."
PG_JSON=$(vault_get "$VAULT_PATH_PG")
DIRECTUS_JSON=$(vault_get "$VAULT_PATH_DIRECTUS")
AI_JSON=$(vault_get "$VAULT_PATH_AI")

if ! has_error "$PG_JSON" && ! has_error "$DIRECTUS_JSON" && ! has_error "$AI_JSON"; then
    # ── SHARED MODE ───────────────────────────────────────────────────────────
    echo "  Mode: SHARED (bs4/ KV engine)"
    echo "  bs4/postgresql  -> DB credentials"
    echo "  bs4/directus    -> Directus credentials"
    echo "  bs4/ai-tools    -> Anthropic API key"

    DB_PASSWORD=$(require_field "$(extract_field "$PG_JSON" "sterile_dev_password")"       "sterile_dev_password" "$VAULT_PATH_PG")
    BS4_DEV_PASSWORD=$(require_field "$(extract_field "$PG_JSON" "bs4_dev_password")"      "bs4_dev_password"     "$VAULT_PATH_PG")
    ADMIN_PASSWORD=$(require_field "$(extract_field "$DIRECTUS_JSON" "admin_password")"    "admin_password"       "$VAULT_PATH_DIRECTUS")
    ADMIN_EMAIL=$(require_field "$(extract_field "$DIRECTUS_JSON" "admin_email")"          "admin_email"          "$VAULT_PATH_DIRECTUS")
    DIRECTUS_KEY=$(require_field "$(extract_field "$DIRECTUS_JSON" "key")"                 "key"                  "$VAULT_PATH_DIRECTUS")
    DIRECTUS_SECRET=$(require_field "$(extract_field "$DIRECTUS_JSON" "secret")"           "secret"               "$VAULT_PATH_DIRECTUS")
    DIRECTUS_TOKEN=$(require_field "$(extract_field "$DIRECTUS_JSON" "token")"             "token"                "$VAULT_PATH_DIRECTUS")
    ANTHROPIC_API_KEY=$(require_field "$(extract_field "$AI_JSON" "anthropic_api_key")"    "anthropic_api_key"    "$VAULT_PATH_AI")

else
    # ── LEGACY MODE ───────────────────────────────────────────────────────────
    echo "  Mode: LEGACY (cubbyhole/internal-erp/db)"
    echo "  (Run vault-admin-setup.sh to upgrade to shared mode)"

    LEGACY_JSON=$(vault_get "$VAULT_PATH_LEGACY")
    if has_error "$LEGACY_JSON"; then
        echo "ERROR: Cannot read from Vault. Tried bs4/* and $VAULT_PATH_LEGACY." >&2
        echo "  Check your token and network access to $VAULT_ADDR" >&2
        exit 1
    fi

    DB_PASSWORD=$(require_field "$(extract_field "$LEGACY_JSON" "DB_PASSWORD")"            "DB_PASSWORD"       "$VAULT_PATH_LEGACY")
    BS4_DEV_PASSWORD=$(require_field "$(extract_field "$LEGACY_JSON" "BS4_DEV_PASSWORD")"  "BS4_DEV_PASSWORD"  "$VAULT_PATH_LEGACY")
    ADMIN_PASSWORD=$(require_field "$(extract_field "$LEGACY_JSON" "ADMIN_PASSWORD")"      "ADMIN_PASSWORD"    "$VAULT_PATH_LEGACY")
    ADMIN_EMAIL=$(require_field "$(extract_field "$LEGACY_JSON" "ADMIN_EMAIL")"            "ADMIN_EMAIL"       "$VAULT_PATH_LEGACY")
    DIRECTUS_KEY=$(require_field "$(extract_field "$LEGACY_JSON" "DIRECTUS_KEY")"          "DIRECTUS_KEY"      "$VAULT_PATH_LEGACY")
    DIRECTUS_SECRET=$(require_field "$(extract_field "$LEGACY_JSON" "DIRECTUS_SECRET")"    "DIRECTUS_SECRET"   "$VAULT_PATH_LEGACY")
    DIRECTUS_TOKEN=$(require_field "$(extract_field "$LEGACY_JSON" "DIRECTUS_TOKEN")"      "DIRECTUS_TOKEN"    "$VAULT_PATH_LEGACY")
    ANTHROPIC_API_KEY=$(require_field "$(extract_field "$LEGACY_JSON" "ANTHROPIC_API_KEY")" "ANTHROPIC_API_KEY" "$VAULT_PATH_LEGACY")
fi

echo "  All 8 secrets retrieved."

# ── Write .env ────────────────────────────────────────────────────────────────
echo ""
echo "Writing .env to: $ENV_OUT"

cat > "$ENV_OUT" << EOF
# AUTO-GENERATED by vault-fetch-secrets.sh -- DO NOT EDIT MANUALLY
# Source: $VAULT_ADDR
# Regenerate: ./vault-fetch-secrets.sh

# --- Directus secrets ---
KEY=$DIRECTUS_KEY
SECRET=$DIRECTUS_SECRET

# --- Public URL (local) ---
PUBLIC_URL=http://localhost:8055

# --- PostgreSQL via Cloud SQL Auth Proxy on host ---
DB_CLIENT=pg
DB_HOST=host.docker.internal
DB_PORT=5432
DB_DATABASE=bidstruct4
DB_USER=sterile_dev
DB_PASSWORD=$DB_PASSWORD

# Break-glass / migrations user (bs4_dev)
BS4_DEV_PASSWORD=$BS4_DEV_PASSWORD

# --- First-time admin (Directus bootstrap) ---
ADMIN_EMAIL=$ADMIN_EMAIL
ADMIN_PASSWORD=$ADMIN_PASSWORD
EOF

chmod 600 "$ENV_OUT"
echo "  Written: $ENV_OUT (chmod 600)"

echo ""
echo "========================================"
echo " Done! Start Directus with:"
echo "   docker compose up"
echo "========================================"
echo ""
