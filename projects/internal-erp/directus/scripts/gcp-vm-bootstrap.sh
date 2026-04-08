#!/usr/bin/env bash
# Back-compat alias: same as gcp-vm-ensure-docker.sh (idempotent Docker install).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${HERE}/gcp-vm-ensure-docker.sh"
