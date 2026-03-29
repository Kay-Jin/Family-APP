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
