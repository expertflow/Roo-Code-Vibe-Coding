/**
 * Story 1-10 — PostgreSQL RLS session context for authenticated API data access.
 *
 * PRD NFR13 / Architecture ADR-13 (PM: no Directus Admin bypass):
 * - Any authenticated user: SET LOCAL ROLE <RLS_SESSION_ROLE> (default directus_rls_subject);
 *   PostgreSQL has NO role named "public" — do not use SET ROLE public.
 * - Then app.user_email = normalized directus_users.email — RLS + UserToRole, not owner bypass.
 * - Unauthenticated / no accountability.user: skip (owner-access path for internal
 *   knex use that does not carry a user id — migrations, bootstrap, static token without user).
 *
 * Schema/metadata work in Directus may use code paths outside items.* hooks; DDL still
 * uses the service account. Developers who need broad ERP rows must have matching
 * UserToRole (e.g. Finance) for their email — same as other users.
 *
 * Env:
 *   RLS_USER_CONTEXT_ENABLED — "false" disables the hook (break-glass / local debug)
 *   RLS_SESSION_ROLE — PostgreSQL role name for SET LOCAL ROLE (default: directus_rls_subject).
 *     Create it with docs/sql/create-rls-session-role.sql (GRANT to DB_USER + table privileges).
 */

const FILTER_HOOKS = ['items.query', 'items.read', 'items.create', 'items.update', 'items.delete'];
const ACTION_HOOKS = ['items.read', 'items.create', 'items.update', 'items.delete'];

function enabled() {
  const v = process.env.RLS_USER_CONTEXT_ENABLED;
  if (v === undefined || v === '') return true;
  return String(v).toLowerCase() !== 'false' && v !== '0';
}

/** Safe PostgreSQL identifier for SET LOCAL ROLE (no quoting / injection). */
function sessionRoleName() {
  const role = (process.env.RLS_SESSION_ROLE || 'directus_rls_subject').trim();
  if (!/^[a-zA-Z_][a-zA-Z0-9_]*$/.test(role)) {
    throw new Error(
      `[rls-user-context] Invalid RLS_SESSION_ROLE "${role}" — use only letters, digits, underscore`,
    );
  }
  return role;
}

async function applyRlsSession(context) {
  if (!enabled()) return;

  const { accountability, database, logger } = context;
  if (!accountability) return;
  if (!accountability.user) return;

  const userId = accountability.user;

  try {
    const res = await database.raw('SELECT "email" FROM "directus_users" WHERE "id" = ? LIMIT 1', [userId]);
    const row = res.rows?.[0];
    const rawEmail = row?.email;
    if (!rawEmail || typeof rawEmail !== 'string') {
      logger?.warn?.({ userId }, '[rls-user-context] No email on directus_users; skipping session RLS');
      return;
    }

    const email = rawEmail.trim().toLowerCase();
    if (!email) return;

    const rlsRole = sessionRoleName();
    // On Directus item reads, `SET LOCAL` can collapse back to the public/
    // sterile baseline before the actual row query runs. Use request-connection
    // session state and explicitly reset it after the item action.
    await database.raw(`SET ROLE ${rlsRole}`);
    await database.raw(`SELECT set_config('app.user_email', ?, false)`, [email]);
  } catch (err) {
    logger?.error?.(err, '[rls-user-context] Failed to apply RLS session context');
    throw err;
  }
}

async function finalizeRlsSession(context, success) {
  if (!enabled()) return;

  const accountability = context?.accountability;
  const database = context?.database;
  if (!accountability?.user || !database) return;

  try {
    await database.raw('RESET ROLE');
    await database.raw('RESET app.user_email');
  } catch (err) {
    context?.logger?.warn?.(err, `[rls-user-context] Failed to reset session context after ${success ? 'success' : 'error'}`);
  }
}

export default ({ filter, action }) => {
  const wrap =
    () =>
    async (payload, _meta, context) => {
      await applyRlsSession(context);
      return payload;
    };

  for (const name of FILTER_HOOKS) {
    filter(name, wrap());
  }

  for (const name of ACTION_HOOKS) {
    action(name, async (_meta, context) => {
      await finalizeRlsSession(context, true);
    });
  }

  filter('request.error', async (payload, _meta, context) => {
    await finalizeRlsSession(context, false);
    return payload;
  });

  filter('database.error', async (payload, _meta, context) => {
    await finalizeRlsSession(context, false);
    return payload;
  });
};
