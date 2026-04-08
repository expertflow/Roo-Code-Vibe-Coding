# Roo Code Universal Installer v2.0

A one-click installer that sets up **Roo Code** extension across all your IDEs and pre-configures **4 AI model profiles** automatically.

API secrets are fetched securely from **HashiCorp Vault** at runtime — no credentials are stored in the script.

---

## Package Files

| File | Purpose |
|------|---------|
| `Install-RooCode.bat` | **Double-click this** to run the installer |
| `Install-RooCode.ps1` | PowerShell installer script (called by the .bat) |

---

## Supported IDEs

The installer automatically detects and installs into:

| IDE | Status |
|-----|--------|
| **VS Code** | Supported |
| **VS Code Insiders** | Supported |
| **Cursor** | Supported |
| **Windsurf** (Codeium) | Supported |
| **VSCodium** | Supported |

---

## Prerequisites

### 1. Store the Anthropic API Key in Vault

Before running the installer, the Anthropic API key must be stored in HashiCorp Vault.

**Using the Vault CLI:**
```bash
vault login hvs.CAESIC0nSYZlc92KbjE36r_Vncz-MznLpY0eMplhN_V6FrVaGh4KHGh2cy5jU3Q2djJMWjc2bWJPYkZhN3ZSN1JBcUc

vault kv put secret/roocode anthropic_api_key=YOUR_ANTHROPIC_KEY_HERE
```

**Using the Vault UI:**
1. Open: `https://45.88.223.83:31313/ui/vault/secrets`
2. Navigate to `secret/` engine
3. Create a new secret at path `roocode`
4. Add a key: `anthropic_api_key` with your Anthropic API key as the value

---

## How to Use

### Step 1 - Run the Installer
Double-click **`Install-RooCode.bat`**

> If Windows shows a security warning, click **"More info"** then **"Run anyway"**

### Step 2 - Wait for Completion
The installer will:
1. Connect to HashiCorp Vault and fetch the Anthropic API key securely
2. Detect all installed IDEs on your machine
3. Install the Roo Code extension in each IDE
4. Create 4 pre-configured AI model profiles
5. Write settings to each IDE automatically

### Step 3 - Restart Your IDE
After the installer finishes, **restart your IDE(s)** and open Roo Code from the sidebar.

---

## Pre-configured AI Profiles

| # | Profile Name | Provider | Model |
|---|-------------|----------|-------|
| 1 | Gemini-2.5-pro | GCP Vertex AI (expertflowerp / us-central1) | gemini-2.5-pro |
| 2 | Gemini-2.5-flash | GCP Vertex AI (expertflowerp / us-central1) | gemini-2.5-flash |
| 3 | Claude Sonnet | Anthropic (key from Vault) | claude-sonnet-4-6 |
| 4 | Claude Opus | Anthropic (key from Vault) | claude-opus-4-6 |

---

## Security Architecture

```
Install-RooCode.ps1
       |
       | HTTPS request with Vault token
       v
HashiCorp Vault (https://45.88.223.83:31313)
       |
       | Returns: anthropic_api_key (in memory only)
       v
IDE Settings (written to local globalStorage)
```

- The Anthropic API key is **never stored** in the script file
- The key is fetched over HTTPS from Vault at runtime
- The key lives in memory only during the install session
- After install, the key is written into the IDE's local settings (same as if you typed it manually in the UI)

---

## Vault Configuration Reference

| Setting | Value |
|---------|-------|
| Vault URL | `https://45.88.223.83:31313` |
| Vault Token | `hvs.CAESIC...` (in script) |
| Secret Path | `secret/data/roocode` |
| Secret Field | `anthropic_api_key` |

---

## Important Notes

### For Gemini Profiles (Vertex AI)
You need to authenticate with Google Cloud once per machine:
```bash
gcloud auth application-default login
```
Install the [Google Cloud CLI](https://cloud.google.com/sdk/docs/install) if not already installed.

### For Claude Profiles (Anthropic)
The API key is fetched from Vault automatically — no extra steps needed!

---

## Troubleshooting

**"Execution Policy" error?**
Run PowerShell as Administrator and execute:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**"Could not retrieve the Anthropic API key from Vault"?**
- Verify Vault is running and reachable at `https://45.88.223.83:31313`
- Verify the secret exists: `vault kv get secret/roocode`
- Verify the field name is exactly `anthropic_api_key`

**IDE not detected?**
Make sure your IDE's CLI tool is in your system PATH. For Cursor, reinstall it and check "Add to PATH" during setup.

---

## Settings Location

Profiles are written to each IDE's global storage:

| IDE | Settings Path |
|-----|--------------|
| VS Code | `%APPDATA%\Code\User\globalStorage\RooVeterinaryInc.roo-cline\` |
| Cursor | `%APPDATA%\Cursor\User\globalStorage\RooVeterinaryInc.roo-cline\` |
| Windsurf | `%APPDATA%\Windsurf\User\globalStorage\RooVeterinaryInc.roo-cline\` |
| VSCodium | `%APPDATA%\VSCodium\User\globalStorage\RooVeterinaryInc.roo-cline\` |
