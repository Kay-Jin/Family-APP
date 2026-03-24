# Family App - Next Steps

Updated: 2026-03-24

## Current status

- Backend and mobile scaffolds are in place.
- Core family features are implemented:
  - WeChat mock login
  - Family create/join
  - Daily question + answer
  - Photo upload/list/comment/like/edit/delete
  - Birthday reminders CRUD
- Care feature set implemented:
  - Family status card
  - Voice mailbox (record/upload/list/play, rename/delete)
  - Smart care reminders (rule-based)
  - Emergency contact card
- Voice upload resilience:
  - Auto retry (3 attempts, exponential backoff)
  - Manual retry card in UI when upload fails
  - Permission copy shown in UI ("only sender can rename/delete")

## Last known blockers

- Android build can still be affected by unstable external network to Gradle/plugin artifacts.
- SSH push to GitHub is configured and working over port 443.

## Recommended first task next session

1. Persist failed voice upload task across app restart:
   - Save pending voice upload payload to SharedPreferences
   - Restore it in AppState.bootstrap()
   - Keep Retry action usable after app relaunch
2. Add basic integration smoke tests for new care endpoints.
3. Commit and push.

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

- Repo: `https://github.com/Kay-Jin/Family-APP`
- Current local work includes uncommitted changes after latest feature additions.
- Use SSH remote (`git@github.com:Kay-Jin/Family-APP.git`) for stable push.

## Message to resume quickly

Use this when reopening Cursor:

`Continue family-app from NEXT_STEPS.md. First implement persistence for pending voice upload retry across app restart, then run smoke checks and commit.`
