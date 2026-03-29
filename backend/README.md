# Family App Backend (V1.0 Scaffold)

This is a starter backend for your family app, focused on V1.0 features:

- WeChat login (`POST /auth/wechat-login` exchanges the mobile SDK `code` with WeChat when `WECHAT_APP_ID` / `WECHAT_APP_SECRET` are set; `demo_wechat` still works for local demos; pytest uses synthetic unions without credentials)
- Family creation and join
- Daily question and answers
- Photo feed, comments, likes
- Birthday reminders
- JWT auth and family-level permission checks

## 1) Setup

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

## 2) Run

```powershell
python app.py
```

Open:

- Health: <http://127.0.0.1:8000/health>

## Auth usage

1. Call `POST /auth/wechat-login` first and copy `token` (JWT, HS256).
2. Add header for other business APIs:

```text
Authorization: Bearer <token>
```

Set **`JWT_SECRET`** in production (see `.env.example`). Default `dev-secret-change-me` is only for local use.

### Push (local family → FCM via Supabase)

Members who use **both** the Flask session and Supabase should call **`PATCH /users/me`** with `{"supabase_user_id":"<auth.users id>"}` (the Flutter app does this automatically when both sessions exist). When **`PUSH_DISPATCH_SECRET`** and **`SUPABASE_URL`** (or **`SUPABASE_FUNCTIONS_URL`**) are set, the server notifies other linked members after **new photos** and **new birthday reminders** by calling the Edge Function `send-fcm-push`.

## 3) API quick path (suggested order)

1. `POST /auth/wechat-login` -> get `token`
2. (Optional, dual cloud users) `PATCH /users/me` with `{"supabase_user_id":"<uuid>"}` so Flask can target FCM tokens — the Flutter app sends this when both sessions exist.
3. `POST /families` -> get `family_id` and `invite_code`
4. `POST /families/join` -> another member joins
5. `POST /daily-questions` and `POST /daily-answers`
6. `POST /photos`, `POST /photos/{photo_id}/comments`, `POST /photos/{photo_id}/likes`
7. `POST /birthday-reminders`
8. `GET /families/{family_id}/daily-questions`
9. `GET /families/{family_id}/photos`

## 4) Production TODOs

- ~~WeChat code exchange~~: implemented for `/auth/wechat-login` and `/auth/wechat-supabase` when env credentials are set.
- ~~JWT on business routes~~: use `Authorization: Bearer` + `JWT_SECRET`; rotate the secret per environment.
- Add migration tool (Alembic or Flyway style migration scripts)
- Move from SQLite to MySQL
- **Supabase push**: store tokens in `public.device_push_tokens` and call the repo Edge Function `send-fcm-push` (see `../supabase/README.md`) or your own worker—do not send FCM from this Flask app unless you also load Firebase admin credentials here.
- Add CI/CD and broaden automated tests
