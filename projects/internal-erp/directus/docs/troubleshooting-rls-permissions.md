# Troubleshooting: "permission denied for table directus_activity" (and other `directus.*` tables)

## Symptom

When any Directus user saves a record (e.g. changes a relational field like `CorrespondantBank`), an error like the following appears:

```json
{
  "message": "insert into \"directus_activity\" (\"action\", \"collection\", ...) ... - permission denied for table directus_activity",
  "extensions": { "code": "INTERNAL_SERVER_ERROR" }
}
```

The same error can appear for `directus_presets`, `directus_revisions`, or any other table in the `directus` schema.

---

## Root Cause

The **`directus-extension-rls-user-context`** extension (`extensions/rls-user-context/index.js`) issues this statement on **every authenticated item mutation**:

```js
await database.raw(`SET ROLE directus_rls_subject`);
```

This switches the effective PostgreSQL role from `sterile_dev` (the Directus `DB_USER`) to `directus_rls_subject`. All subsequent queries in that connection — including Directus's internal writes to `directus_activity`, `directus_revisions`, and `directus_presets` — run under **`directus_rls_subject`**.

If `directus_rls_subject` has **no grants on the `directus` schema**, those internal writes fail with `permission denied`.

> **Why does it still work in test scripts?**  
> Direct-connection test scripts (e.g. `node tmp_test_insert.cjs`) bypass the hook entirely and run as `sterile_dev`,  which already has the grants. The `SET ROLE` only fires inside the Directus API hooks.

---

## Fix

Grant `directus_rls_subject` full access to the `directus` schema:

```sql
-- Run once as table owner (bs4_dev) or a superuser.
GRANT USAGE ON SCHEMA directus TO directus_rls_subject;
GRANT ALL ON ALL TABLES IN SCHEMA directus TO directus_rls_subject;
GRANT ALL ON ALL SEQUENCES IN SCHEMA directus TO directus_rls_subject;
```

This is captured in **`docs/sql/grant-rls-subject-erp-schema.sql`** and **`docs/sql/create-rls-session-role.sql`** — re-run either script on a new deployment.

> **After new Directus system tables are added** (e.g. after a Directus upgrade), re-run `GRANT ALL ON ALL TABLES IN SCHEMA directus TO directus_rls_subject;` to cover any newly created tables.

---

## Diagnosis Steps (if error recurs)

1. **Reproduce**: Try saving any item in Directus → note exact table name in the error.
2. **Check server logs** on the VM:
   ```bash
   sudo docker logs directus-directus-1 2>&1 | grep -E 'ERROR|permission|PATCH.*500'
   ```
3. **Check grants** (run as `bs4_dev`):
   ```sql
   SELECT grantee, table_name, privilege_type
   FROM information_schema.table_privileges
   WHERE grantee = 'directus_rls_subject'
     AND table_schema = 'directus'
     AND table_name = 'directus_activity';
   ```
   → If empty, the fix above has not been applied.
4. **Test INSERT directly** (run as `sterile_dev`):
   ```sql
   SET ROLE directus_rls_subject;
   INSERT INTO directus.directus_activity (action, collection, ip, item, origin, "timestamp", user_agent)
   VALUES ('update','Test','127.0.0.1','1','http://test', NOW(),'test');
   ```
   → If this fails, the grant is missing. If it succeeds, check for other causes.
5. **Break-glass**: Set `RLS_USER_CONTEXT_ENABLED=false` in `.env` on the VM and restart Directus — this completely disables the hook. Use only temporarily; RLS is bypassed.

---

## Related Files

| File | Purpose |
|------|---------|
| `extensions/rls-user-context/index.js` | The extension that does `SET ROLE` |
| `docs/sql/create-rls-session-role.sql` | Role creation + initial grants (run once) |
| `docs/sql/grant-rls-subject-erp-schema.sql` | Comprehensive grant script for existing deployments |
| `docs/story-1-10-rls-user-context.md` | Architecture design doc for Story 1-10 |
