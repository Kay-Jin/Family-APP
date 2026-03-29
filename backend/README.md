# Family App Backend (V1.0 Scaffold)

This is a starter backend for your family app, focused on V1.0 features:

- WeChat login (mock flow placeholder)
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

1. Call `POST /auth/wechat-login` first and copy `token`
2. Add header for other business APIs:

```text
Authorization: Bearer <token>
```

## 3) API quick path (suggested order)

1. `POST /auth/wechat-login` -> get `token`
2. `POST /families` -> get `family_id` and `invite_code`
3. `POST /families/join` -> another member joins
4. `POST /daily-questions` and `POST /daily-answers`
5. `POST /photos`, `POST /photos/{photo_id}/comments`, `POST /photos/{photo_id}/likes`
6. `POST /birthday-reminders`
7. `GET /families/{family_id}/daily-questions`
8. `GET /families/{family_id}/photos`

## 4) Production TODOs

- Replace mock WeChat login with real code exchange and token verification
- Add auth middleware (JWT)
- Add migration tool (Alembic or Flyway style migration scripts)
- Move from SQLite to MySQL
- Integrate push service (JPush or cloud push). For **Supabase-signed-in** clients, prefer storing tokens in `public.device_push_tokens` (see repo `supabase/migrations/20260403_device_push_tokens.sql`) and sending from Edge Functions or your push worker—not this Flask SQLite API.
- Add CI/CD and tests
