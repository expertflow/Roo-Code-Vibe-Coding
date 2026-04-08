# 🤖 Roo Code Universal Installer

A one-click installer that sets up **Roo Code** extension across all your IDEs and pre-configures **4 AI model profiles** automatically.

---

## 📦 What's Included

| File | Purpose |
|------|---------|
| `Install-RooCode.bat` | **Double-click this** to run the installer |
| `Install-RooCode.ps1` | PowerShell installer script (called by the .bat) |

---

## 🖥️ Supported IDEs

The installer automatically detects and installs into:

| IDE | Status |
|-----|--------|
| **VS Code** | ✅ Supported |
| **VS Code Insiders** | ✅ Supported |
| **Cursor** | ✅ Supported |
| **Windsurf** (Codeium) | ✅ Supported |
| **VSCodium** | ✅ Supported |

---

## 🚀 How to Use

### Step 1 — Run the Installer
Double-click **`Install-RooCode.bat`**

> If Windows shows a security warning, click **"More info"** → **"Run anyway"**

### Step 2 — Wait for Completion
The installer will:
1. Detect all installed IDEs on your machine
2. Install the Roo Code extension in each IDE
3. Create 4 pre-configured AI model profiles
4. Inject API keys automatically

### Step 3 — Restart Your IDE
After the installer finishes, **restart your IDE(s)** and open Roo Code from the sidebar.

---

## 🧠 Pre-configured AI Profiles

The installer creates these 4 profiles automatically:

### 1. Gemini-2.5-pro
- **Provider:** GCP Vertex AI
- **Project:** expertflowerp
- **Region:** us-central1
- **Model:** gemini-2.5-pro

### 2. Gemini-2.5-flash
- **Provider:** GCP Vertex AI
- **Project:** expertflowerp
- **Region:** us-central1
- **Model:** gemini-2.5-flash

### 3. Claude Sonnet
- **Provider:** Anthropic
- **Model:** claude-sonnet-4-5
- **API Key:** Pre-configured ✅

### 4. Claude Opus
- **Provider:** Anthropic
- **Model:** claude-opus-4-5
- **API Key:** Pre-configured ✅

---

## ⚠️ Important Notes

### For Gemini Profiles (Vertex AI)
You need to authenticate with Google Cloud once:
```bash
gcloud auth application-default login
```
Install the [Google Cloud CLI](https://cloud.google.com/sdk/docs/install) if you haven't already.

### For Claude Profiles (Anthropic)
The API key is pre-configured — no extra steps needed!

---

## 🔧 Troubleshooting

**"Execution Policy" error?**
Run PowerShell as Administrator and execute:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**IDE not detected?**
Make sure your IDE's CLI tool is in your system PATH. For Cursor, reinstall it and check "Add to PATH" during setup.

**Extension not showing in Roo Code?**
Restart the IDE completely (not just reload window) after installation.

---

## 📁 Settings Location

Profiles are written to each IDE's global storage:

| IDE | Settings Path |
|-----|--------------|
| VS Code | `%APPDATA%\Code\User\globalStorage\RooVeterinaryInc.roo-cline\` |
| Cursor | `%APPDATA%\Cursor\User\globalStorage\RooVeterinaryInc.roo-cline\` |
| Windsurf | `%APPDATA%\Windsurf\User\globalStorage\RooVeterinaryInc.roo-cline\` |
| VSCodium | `%APPDATA%\VSCodium\User\globalStorage\RooVeterinaryInc.roo-cline\` |
