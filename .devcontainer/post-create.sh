#!/bin/bash
# ============================================================
#  Dev Container Post-Create Setup Script
#  Runs automatically after the container is created.
# ============================================================

set -e

echo ""
echo "  ============================================="
echo "   Roo Code Vibe Coding Stack - Post-Create"
echo "  ============================================="
echo ""

# ---- Install global npm tools ------------------------------
echo "  [1/5] Installing global npm tools..."
npm install -g @angular/cli@latest
npm install -g eslint
npm install -g prettier
npm install -g typescript
echo "  [OK] npm tools installed."

# ---- Install Playwright browsers ---------------------------
echo ""
echo "  [2/5] Installing Playwright browsers..."
npx playwright install --with-deps chromium
echo "  [OK] Playwright ready."

# ---- Install Python tools ----------------------------------
echo ""
echo "  [3/5] Installing Python tools..."
pip install --quiet streamlit
echo "  [OK] Python tools installed."

# ---- Set up GCP project ------------------------------------
echo ""
echo "  [4/5] Configuring GCP project..."
gcloud config set project expertflowerp 2>/dev/null || true
gcloud config set compute/region us-central1 2>/dev/null || true
echo "  [OK] GCP project set to: expertflowerp / us-central1"

# ---- Bootstrap MCP secrets from Vault ----------------------
echo ""
echo "  [5/5] Bootstrapping MCP secrets from HashiCorp Vault..."
if [ -f ".roo/bootstrap-mcp.ps1" ]; then
    pwsh -NonInteractive -ExecutionPolicy Bypass -File ".roo/bootstrap-mcp.ps1" -Silent 2>/dev/null || \
    echo "  [!!] Vault bootstrap skipped (Vault may not be reachable yet)."
else
    echo "  [!!] bootstrap-mcp.ps1 not found, skipping."
fi

# ---- Create docs structure if missing ----------------------
mkdir -p docs/bmad
mkdir -p docs/specs
mkdir -p features

echo ""
echo "  ============================================="
echo "   Setup complete!"
echo ""
echo "   NEXT STEPS:"
echo "   1. Run: gcloud auth application-default login"
echo "      (for Gemini/Vertex AI profiles)"
echo ""
echo "   2. Open Roo Code from the sidebar"
echo "   3. Select your AI profile (Claude Sonnet recommended)"
echo "  ============================================="
echo ""
