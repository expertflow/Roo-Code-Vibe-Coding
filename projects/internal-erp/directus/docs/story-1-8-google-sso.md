# Story 1.8 — Google Workspace OIDC + `@expertflow.com` JIT

Normative contract: **`_bmad-output/planning-artifacts/identity-provider.md`**.

Directus v11 uses **OpenID Connect** to Google. This guide wires **local dev** first; production uses the same variables with **Secret Manager** for the client secret.

---

## 1. Google Cloud Console

1. **APIs & Services → Credentials → Create credentials → OAuth client ID**
2. Application type: **Web application**
3. **Authorized JavaScript origins** (add both if developers use either URL):
   - `http://127.0.0.1:8055`
   - `http://localhost:8055`
4. **Authorized redirect URIs** (must match how `PUBLIC_URL` is set):
   - `http://127.0.0.1:8055/auth/login/google/callback`
   - `http://localhost:8055/auth/login/google/callback`
5. Copy **Client ID** and **Client secret**

**Restrict who can sign in (recommended for production):**

- Set OAuth consent screen **User type** to **Internal** (Workspace users only), **or**
- Keep the app **Testing** with an explicit **test users** list until review.

Directus **`ALLOW_PUBLIC_REGISTRATION`** only creates a Directus user after Google has authenticated the account; it does not replace Google-side restrictions.

---

## 2. `PUBLIC_URL` must match the browser

If you open the Admin UI at **`http://127.0.0.1:8055`**, set:

```env
PUBLIC_URL=http://127.0.0.1:8055
```

Mismatch causes **redirect_uri_mismatch** from Google.

---

## 3. Minimal Directus role for JIT users

JIT users need a **`AUTH_GOOGLE_DEFAULT_ROLE_ID`** (UUID).

1. Sign in as admin → **Settings → Access Control → Roles → Create role**
2. Name e.g. **`SSO JIT (minimal)`** — **no** collection permissions (or only what you accept pre–Epic 2)
3. Save → copy the role **ID** (UUID)

List via SQL if needed:

```sql
SELECT id, name FROM directus_roles ORDER BY name;
```

---

## 4. Environment variables (add to `.env`)

See **`.env.example`** (Story 1.8 block). Minimal set:

| Variable | Purpose |
|----------|---------|
| `AUTH_PROVIDERS` | `google` |
| `AUTH_GOOGLE_DRIVER` | `openid` |
| `AUTH_GOOGLE_CLIENT_ID` | From Google Console |
| `AUTH_GOOGLE_CLIENT_SECRET` | From Google Console |
| `AUTH_GOOGLE_ISSUER_URL` | `https://accounts.google.com` |
| `AUTH_GOOGLE_IDENTIFIER_KEY` | `email` — aligns with **`UserToRole.User`** / RLS **`app.user_email`** |
| `AUTH_GOOGLE_SCOPE` | `openid profile email` |
| `AUTH_GOOGLE_ALLOW_PUBLIC_REGISTRATION` | `true` — **first** `@expertflow.com` login creates `directus_users` |
| `AUTH_GOOGLE_REQUIRE_VERIFIED_EMAIL` | `true` |
| `AUTH_GOOGLE_DEFAULT_ROLE_ID` | UUID from §3 |
| `AUTH_GOOGLE_LABEL` | e.g. `Google` |
| `AUTH_GOOGLE_SYNC_USER_INFO` | `true` recommended so name/email stay in sync |

**Optional — suggest Workspace domain in the Google account picker:**

Use login URL query (not only env), e.g. open:

`/auth/login/google?hd=expertflow.com`

Bookmark that for operators. (Google still returns an `hd` claim you can rely on in audits; locking non-Workspace users is primarily **OAuth consent / Internal app** + org policy.)

**Keep local admin login during rollout:**

- Leave **`AUTH_DISABLE_DEFAULT=false`** (default) so **`ADMIN_EMAIL` / password** still works for break-glass.
- Production may later set **`AUTH_DISABLE_DEFAULT=true`** per runbook (not required for first SSO smoke test).

---

## 5. Apply `.env` changes (important)

**`docker compose restart` does not reload `env_file`.** New or changed variables (including all `AUTH_*`) are only injected when the container is **(re)created**.

After editing `.env`:

```bash
docker compose up -d --force-recreate
```

(or `docker compose down` then `docker compose up -d`)

**Verify inside the container** (should list `AUTH_PROVIDERS`, `AUTH_GOOGLE_DRIVER`, etc.):

```bash
docker compose exec directus printenv | findstr AUTH
```

On Linux/macOS: `docker compose exec directus printenv | grep AUTH`

---

## 6. Smoke test

### 6a. Migrated bootstrap user (done when applicable)

User already in **`directus_users`** as **`default`**: run **§ Migrating an existing user to Google** SQL, then **Log In with Google**.

### 6b. JIT — first-time `@expertflow.com` user (**TODO / incomplete**)

_Use a mailbox that has **never** appeared in **`directus_users`**._

1. Incognito → **Log In with Google**
2. Confirm **new** **`directus_users`** row, **`provider = google`**, **`AUTH_GOOGLE_DEFAULT_ROLE_ID`**
3. Open an ERP collection → **Story 1-10** sets **`app.user_email`** (RLS + **`UserToRole`** as applicable)

_(Scheduled next working session — keep Story **1-8** `in-progress` in **`sprint-status.yaml`** until this passes.)_

---

## 7. Seeding `UserToRole` when RLS blocks the Admin UI

With **1-10** enabled, **Directus Administrator** still hits PostgreSQL RLS on **`items.*`**. Inserts may fail with *new row violates row-level security policy*.

**Seed or fix mappings** using **`psql`** (or Cloud SQL) as break-glass **`bs4_dev`** (not Directus **`DB_USER`** / **`sterile_dev`**) **outside** the Directus `SET LOCAL ROLE` path — e.g. one-shot SQL against `"BS4Prod09Feb2026"."UserToRole"` (adjust schema). See **`docs/sql/seed-user-to-role.example.sql`**.

---

## Troubleshooting

| Symptom | Likely cause |
|--------|----------------|
| `Route /auth/login/google doesn't exist` / **404** on `/auth/login/google` | **`AUTH_*` not in the container** — often **only `restart`** after editing `.env`. Use **`docker compose up -d --force-recreate`**, then **`docker compose exec directus printenv`** and confirm **`AUTH_PROVIDERS`** / **`AUTH_GOOGLE_ISSUER_URL`** exist. |
| No Google button on login | Same as above, or incomplete OpenID env (needs **`AUTH_GOOGLE_ISSUER_URL`**, etc.). |
| `redirect_uri_mismatch` | **`PUBLIC_URL`** in `.env` must match the browser URL **and** Google’s **Authorized redirect URIs**. |
| Login URL **`?reason=INVALID_PROVIDER`** / *User belongs to a different auth provider* | The email already exists on a **`default` (local)** user from bootstrap, but Google SSO expects **`provider = 'google'`** and a matching **`external_identifier`**. See **§ Migrating an existing user to Google** below. |

### Migrating an existing user to Google (bootstrap admin)

If **`ADMIN_EMAIL`** was used to create the first user, that row is usually **`provider = 'default'`**. Google OpenID with **`AUTH_GOOGLE_IDENTIFIER_KEY=email`** matches users by **`external_identifier`** (and email).

**Option A — SQL (reliable)** — run against `bidstruct4` as a DB user that can update `directus_users` (e.g. `bs4_dev`):

```sql
UPDATE directus_users
SET
  provider = 'google',
  external_identifier = LOWER(TRIM(email))
WHERE LOWER(TRIM(email)) = LOWER(TRIM('andreas.stuber@expertflow.com'));
```

Adjust the email literal if needed. Then sign in with **Log In with Google** using that Workspace account.

**Option B — Keep local login for admin** — do not change the row; use **email + password** for that operator and use Google only for **new** JIT users (different emails).

**Option C — New admin via Google** — create a second user through Google JIT, grant **Administrator** in Directus, then retire or fix the old account (cleaner long-term for SSO-only policy).

---

## References

- `_bmad-output/planning-artifacts/identity-provider.md`
- `_bmad-output/implementation-artifacts/1-8-external-oidc-identity-provider.md`
- [Directus Auth & SSO](https://directus.io/docs/configuration/auth-sso)
