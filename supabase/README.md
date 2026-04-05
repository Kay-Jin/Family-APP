# Supabase (SQL + Edge Functions)

SQL migrations live in `migrations/`. Apply them in the Supabase SQL editor or via `supabase db push` when using the CLI.

## Edge Function: `send-fcm-push`

Sends **FCM HTTP v1** notifications to rows in `public.device_push_tokens` for the given Supabase `auth.users` ids.

### Security

- Deploy with **JWT verification off** for this function; authentication is a shared secret header (not the anon key).
- **Never** expose `PUSH_DISPATCH_SECRET` or `FIREBASE_SERVICE_ACCOUNT_JSON` to the mobile app. Call this function only from a trusted server, job, or internal automation.

### Secrets (Dashboard → Edge Functions → Secrets, or CLI)

| Secret | Description |
|--------|-------------|
| `PUSH_DISPATCH_SECRET` | Long random string; caller sends `Authorization: Bearer <same value>`. |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | Full JSON of a Firebase service account with **Firebase Cloud Messaging API** enabled (Google Cloud → IAM → service account key). |
| `SUPABASE_URL` | Usually injected by Supabase; set if missing. |
| `SUPABASE_SERVICE_ROLE_KEY` | Service role key (read tokens for any user). Injected on hosted Supabase when linked. |

### Deploy

```bash
cd supabase
supabase functions deploy send-fcm-push --no-verify-jwt
```

### Request

`POST` with header `Authorization: Bearer <PUSH_DISPATCH_SECRET>` and JSON body:

```json
{
  "user_ids": ["uuid-of-auth-user", "..."],
  "title": "Hello",
  "body": "Short message",
  "data": { "route": "cloud_family", "family_id": "optional-string" }
}
```

Optional `data` values must be **strings** (FCM requirement). The function returns `{ sent, failed, total_tokens, results }` with per-token HTTP status from FCM.

### Example (curl)

```bash
curl -sS -X POST "https://YOUR_PROJECT.supabase.co/functions/v1/send-fcm-push" \
  -H "Authorization: Bearer $PUSH_DISPATCH_SECRET" \
  -H "Content-Type: application/json" \
  -d '{"user_ids":["YOUR_USER_UUID"],"title":"Test","body":"From Edge"}'
```

### Flask (SQLite) integration

The repo backend can call this function after local-family events when `PUSH_DISPATCH_SECRET` + `SUPABASE_URL` are set in the Flask `.env`. Linked users are those with `users.supabase_user_id` set (`PATCH /users/me` from the app). See `../backend/README.md`.

---

## Edge Function: `wechat-supabase-auth`

Exchanges a **WeChat mobile OAuth `code`** for **Supabase `access_token` + `refresh_token`** (same JSON contract as Flask `POST /auth/wechat-supabase`). The Flutter app invokes this function **before** falling back to Flask, so family phones do not need your home PC’s LAN IP for WeChat login.

### Deploy

```bash
cd supabase
supabase functions deploy wechat-supabase-auth --no-verify-jwt
```

If your Cursor workspace is linked to Supabase (MCP), this function may already be deployed to your project — open **Dashboard → Edge Functions** to confirm. You must still add the **Secrets** below or invocations will return 500 until `SUPABASE_ANON_KEY` (and WeChat keys when you use WeChat) are set.

`config.toml` sets `verify_jwt = false` because users are not signed in yet; security relies on WeChat’s one-time `code` exchange.

### Secrets

| Secret | Description |
|--------|-------------|
| `WECHAT_APP_ID` | WeChat Open Platform mobile app AppID |
| `WECHAT_APP_SECRET` | App secret |
| `SUPABASE_ANON_KEY` | Project anon / publishable key (for password grant after user upsert) |
| `WECHAT_DERIVE_SECRET` | Optional; **must match** Flask `WECHAT_DERIVE_SECRET` or `JWT_SECRET` if you use both Edge and Flask for the same users |
| *(auto)* `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` | Injected on hosted Supabase |

### Request

`POST` with `Authorization: Bearer <anon_key>` and `apikey: <anon_key>` (the Supabase client does this automatically). Body:

```json
{ "code": "<wechat_oauth_code_or_demo_wechat>" }
```

### Response

```json
{ "access_token": "...", "refresh_token": "..." }
```

## Database advisor (periodic review)

Supabase **Database Linter** / advisor may report:

- **`families` RLS**: policies named like `public families write` / `update` / `delete` that use `WITH CHECK (true)` or `USING (true)` weaken row-level security. Tighten these when your product flow no longer needs wide-open mutations (see [permissive RLS](https://supabase.com/docs/guides/database/database-linter?lint=0024_permissive_rls_policy)).
- **Auth**: enable **leaked password protection** (HaveIBeenPwned) under Auth settings for stronger password hygiene.

Remote projects may contain migrations not yet mirrored as files under `migrations/` (e.g. applied from the Dashboard). Use `supabase db pull` (CLI) or MCP `list_migrations` to compare with this repo.
