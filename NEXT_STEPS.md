# Family App - Next Steps

Updated: 2026-03-28

## Current status

- **Repo**: [Kay-Jin/Family-APP](https://github.com/Kay-Jin/Family-APP) — `main` is pushed and intended to match local when clean.
- **CI**: GitHub Actions ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)) — latest run on `main` is **green** (Flutter + Python). Optional Supabase schema job runs only if repo secret `SUPABASE_DB_URL` is set — see [`docs/CI.md`](docs/CI.md).
- **Backend and mobile**: scaffolds and core flows in place (families, daily Q&A, photos, birthdays, care modules, WeChat bridge + Supabase cloud paths as implemented in code).
- **Voice upload**: persistence across app restart (SharedPreferences + stable file path); auto retry and manual retry UI.
- **Tests**: Backend care smoke tests; Flutter unit/widget tests; `scripts/run_tests.ps1` for Flutter analyze + test.
- **Supabase (linked project, read-only MCP check)**: `daily_answers.image_path` and Storage bucket `family_answer_images` are **still missing** until you run the migration below. Cursor Supabase MCP cannot apply DDL in read-only mode. After you run it, confirm with [`supabase/tests/schema_checks.sql`](supabase/tests/schema_checks.sql) or `scripts/run_supabase_schema_checks.ps1` (`failed_count` should be `0`). Migration file: [`supabase/migrations/20260328_answer_images_and_storage.sql`](supabase/migrations/20260328_answer_images_and_storage.sql).
- **Flutter platforms**: `linux/`, `macos/`, `web/`, `windows/` under `mobile/` are in repo for desktop/web builds.

## Do this next (you, in order)

1. **Supabase Dashboard** → **SQL Editor** → paste the full contents of [`supabase/migrations/20260328_answer_images_and_storage.sql`](supabase/migrations/20260328_answer_images_and_storage.sql) → **Run**.
2. Optional: add GitHub Actions secret **`SUPABASE_DB_URL`** so CI runs schema checks on every push (see [`docs/CI.md`](docs/CI.md)).
3. Follow **Release prep checklist** below (or pick **New features** / **Engineering** instead).

## Release prep checklist (minimal)

- [ ] **Stores**: Google Play / App Store developer accounts, app name, screenshots, short description, content rating questionnaire.
- [ ] **Legal / policy**: Public **privacy policy URL** (required by stores); link it from store listing and optionally in-app settings / About.
- [ ] **Production config**: Supabase production project URLs/keys in release builds only; WeChat / backend URLs point to production, not dev.
- [ ] **Signing**: Android upload key / iOS distribution cert and provisioning profiles configured in CI or local release pipeline.
- [ ] **Stability**: Crash reporting or Play/App vitals; smoke-test login, cloud family, daily Q&A, and image upload after migration.

## Completed recently (no longer “next”)

- Pending voice upload retry persisted across restarts.
- Care endpoint integration smoke tests added.
- GitHub Actions CI added; pytest import/multipart fixes; `main` CI green.
- `.cursor/mcp.json` **removed from git tracking** (still ignore-listed); keep tokens only on your machine.

## Last known blockers / risks

- Android builds may still hit **Gradle/plugin download** issues on poor networks (mirrors, cache, or documented workarounds help).
- **Cloud DB drift**: until the migration in step 1 is applied, cloud **answer images** flows can fail against the linked Supabase project.

## Product direction (pick one next focus)

**Default suggestion:** run the Supabase migration (step 1), then execute **Release prep** above.

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

`Continue family-app from NEXT_STEPS.md. If Supabase migration is applied, verify schema_checks; otherwise remind me to run SQL Editor. Then continue release prep or chosen product track.`
