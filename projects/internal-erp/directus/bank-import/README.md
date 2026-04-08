# Bank statement import (Story 3-1)

Python **3.10+** (stdlib only). Normalizes UBS e-banking CSV (accounts **7 / 8 / 9** in `registry.json`) to `BankStatement`-shaped rows.

## CLI (dry-run / staging)

`registry.json` maps Directus **Account** ids **7, 8, 9** (USD / EUR / CHF) to the UBS parser — use `--account` with the id you are importing for:

```bash
python cli.py --input path/to/export.csv --account 7 --dry-run --format json --output -
python cli.py --input path/to/export.csv --account 8 --dry-run --format csv -o -
python cli.py --input path/to/export.csv --account 9 --dry-run --format json --output -
```

## Tests

```bash
python tests/test_ubs_parser.py -v
```

## Data Studio module (in-app UX)

Extension: `extensions/bank-statement-import-ui/` (built output in `dist/` — run `npm install && npm run build` there after changing Vue sources).

1. Restart Directus so the extension loads (compose mounts `./extensions`).
2. **Enable the module:** **Settings → Project settings → Modules** (or **Appearance** / module bar, depending on version) and turn on **Bank import**.
3. Open **`/admin/bank-statement-import-ui`** (or choose **Bank import** in the left module bar).
4. Select **Account**, choose the **CSV** file, leave **Dry run** checked for a preview, then **Import to Directus** when ready.

The module calls the same **`POST /bank-statement-import/run`** endpoint with your session; no separate token.

## Directus endpoint

`POST /bank-statement-import/run` with JSON `{ "account": 7|8|9, "csv": "<file contents>", "dryRun": true|false }` and a **user** access token (same as REST API). Set `BANK_IMPORT_DIR` / `BANK_IMPORT_PYTHON` if not using Docker defaults (`/directus/bank-import`, `python3`).

### Local test (Docker Directus on this repo)

1. From `projects/internal-erp/directus`, rebuild and start so extensions + Python are loaded: `docker compose build --no-cache directus` then `docker compose up -d`.
2. Log in as a user that may create `BankStatement` rows, obtain a token: `POST /auth/login` (email + password) → `data.access_token`.
3. **Dry run** (no DB writes): `POST http://127.0.0.1:8055/bank-statement-import/run` with header `Authorization: Bearer <token>`, `Content-Type: application/json`, body `{"account":8,"dryRun":true,"csv":"…paste or embed full CSV text…"}`.
4. To **persist** rows, same request with `"dryRun": false`. Duplicate lines should return **400** from the dedup hook.

**PowerShell** (run from `projects/internal-erp/directus`; UTF-8 file → JSON body):

```powershell
$base = "http://127.0.0.1:8055"
$token = "<access_token>"
$csv = [System.IO.File]::ReadAllText("$(Resolve-Path .\bank-import\tests\fixtures\ubs_sample.csv)")
$body = @{ account = 9; dryRun = $true; csv = $csv } | ConvertTo-Json
Invoke-RestMethod -Uri "$base/bank-statement-import/run" -Method Post `
  -Headers @{ Authorization = "Bearer $token" } -ContentType "application/json; charset=utf-8" -Body $body
```

Run the same from the host against a **local** Directus process (not Docker) only if `python`/`python3` is on PATH and `BANK_IMPORT_DIR` points at this `bank-import` folder.
