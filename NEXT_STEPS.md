# Family App - Next Steps

Updated: 2026-03-28

## Current status

- **Repo**: [Kay-Jin/Family-APP](https://github.com/Kay-Jin/Family-APP) — `main` is pushed and intended to match local when clean.
- **CI**: GitHub Actions ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)) runs on push/PR to `main`/`master`: Flutter analyze + tests (`mobile/`), pytest (`backend/`). Optional Supabase schema job runs only if repo secret `SUPABASE_DB_URL` is set — see [`docs/CI.md`](docs/CI.md).
- **Backend and mobile**: scaffolds and core flows in place (families, daily Q&A, photos, birthdays, care modules, WeChat bridge + Supabase cloud paths as implemented in code).
- **Voice upload**: persistence across app restart (SharedPreferences + stable file path); auto retry and manual retry UI.
- **Tests**: Backend care smoke tests; Flutter unit/widget tests; `scripts/run_tests.ps1` for Flutter analyze + test.
- **Supabase**: `supabase/schema.sql` and migrations (e.g. [`supabase/migrations/20260328_answer_images_and_storage.sql`](supabase/migrations/20260328_answer_images_and_storage.sql)) — apply in **Supabase Dashboard → SQL Editor** when the live project lags the repo. (Read-only MCP cannot apply DDL.) As of 2026-03-28, a schema check against the linked project reported 5 failures (`image_path` + `family_answer_images` bucket/policies) **until** that migration is run. Regression query: [`supabase/tests/schema_checks.sql`](supabase/tests/schema_checks.sql); local helper: `scripts/run_supabase_schema_checks.ps1` (needs `psql` + `SUPABASE_DB_URL`).
- **Flutter platforms**: `linux/`, `macos/`, `web/`, `windows/` under `mobile/` are in repo for desktop/web builds.

## Completed recently (no longer “next”)

- Pending voice upload retry persisted across restarts.
- Care endpoint integration smoke tests added.
- GitHub Actions CI added; commits pushed to `main`.
- `.cursor/mcp.json` **removed from git tracking** (still ignore-listed); keep tokens only on your machine.

## Last known blockers / risks

- Android builds may still hit **Gradle/plugin download** issues on poor networks (mirrors, cache, or documented workarounds help).
- **Cloud DB drift**: if production Supabase was never migrated for answer images + Storage, mobile cloud features may fail until migration is applied.

## Recommended order (maintenance)

1. Confirm **GitHub Actions** are green on the latest `main` (fix any red Flutter/Python jobs).
2. Align **Supabase** with repo schema/migrations; optionally set **`SUPABASE_DB_URL`** on GitHub for CI schema checks.
3. **Tokens**: if a GitHub PAT was ever pasted in chat, rotate it on GitHub and update local MCP config only (never commit).

## Product direction (pick one next focus)

**Default suggestion:** after CI is green and the Supabase migration above is applied, start with **Release prep** (store listing, privacy URL, prod config), unless a specific feature is blocking users.

| Track | Examples |
|-------|----------|
| **Release prep** | Store listings, privacy policy URL, prod env checks, crash/analytics |
| **New features** | Deeper care / cloud family / WeChat flows — specify the user scenario |
| **Engineering** | Gradle/network stability, docs for offline or mirror setup |

## Quick start commands

### Backend

```powershell
cd C:\Users\Administrator\Desktop\family-app\backend
.\.venv\Scripts\Activate.ps1
python app.py
```

### Mobile

```powershell
cd C:\Users\Administrator\Desktop\family-app\mobile
flutter pub get
flutter run
```

## Git notes

- Remote: `git@github.com:Kay-Jin/Family-APP.git` (HTTPS URL also works).
- **Do not commit** `.cursor/mcp.json` (contains secrets); it is listed in `.gitignore`.
- Device bugreports under `mobile/bugreport*.zip` are ignored by git.

## Message to resume quickly

Use when reopening Cursor:

`Continue family-app from NEXT_STEPS.md. Check GitHub Actions on main, Supabase schema vs supabase/schema.sql, then continue the product track chosen in NEXT_STEPS (release / features / engineering).`
