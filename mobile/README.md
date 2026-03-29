# Family Mobile (Flutter Scaffold)

This folder contains a Flutter client scaffold that works with the backend in `../backend`.

## Implemented flow

- Login (mock WeChat code)
- Create family / join family
- Refresh and display:
  - daily questions
  - photos

## 1) Install Flutter SDK

Follow official docs: <https://docs.flutter.dev/get-started/install/windows/mobile>

## 2) Run

```powershell
cd mobile
flutter pub get
flutter run
```

## 3) API base URL (Flask)

The app resolves the backend in this order:

1. **Build flag** `--dart-define=FLASK_BASE_URL=...` (highest priority; use for CI / fixed staging URLs).
2. **Saved in the app** — on the login screen, expand **「Local Flask API」 / 本地 Flask 后端**, enter your URL, tap **Save & apply**.
3. **Defaults** — Android emulator: `http://10.0.2.2:8000`; iOS simulator / desktop: `http://127.0.0.1:8000`.

**Real phone on the same Wi‑Fi as your PC**

1. Start the backend (`../backend`); it listens on **`0.0.0.0:8000`** so LAN devices can connect.
2. Find your PC’s IPv4 (e.g. `ipconfig` → `192.168.1.10`).
3. In the app login screen, set base URL to `http://192.168.1.10:8000` (no trailing slash) and save.
4. Allow the firewall for Python/port 8000 if Windows prompts.

**Example commands**

```powershell
cd mobile
# Optional: bake URL into release build
flutter run --dart-define=FLASK_BASE_URL=http://192.168.1.10:8000
```

```powershell
flutter build apk --dart-define=FLASK_BASE_URL=http://192.168.1.10:8000
```

## 4) App structure (current)

- **Local (Flask) home**: `HomeScreen` — families, daily Q&A, photos (upload, comments, likes), birthday reminders, voice notes, etc.
- **Cloud (Supabase)**: `SupabaseFamilyScreen` / detail — invite codes, care panel, cloud album, companion room, medical card sync, cloud birthdays, etc.
- **Dual session**: when signed in to both backends, `DualSessionShell` uses a bottom nav (local home + cloud families). The app registers your Supabase user id on the Flask profile (`PATCH /users/me`) so the Python backend can fan out FCM to other members after local photos, likes, comments, daily answers, or birthday reminders when push env is configured.
- **Still rough / prod**: mock WeChat code path for some flows; real WeChat SDK + Firebase (`flutterfire configure`) for production push — see §6.

## 5) If Android build times out on network

When your network can reach Gradle/Maven reliably, run cache warmup once:

```powershell
cd mobile
powershell -ExecutionPolicy Bypass -File .\tools\warmup_android_cache.ps1
```

Then switch back to normal network and run:

```powershell
flutter run -d emulator-5554
```

You can also double-click this file in Explorer:

- `mobile/tools/warmup_android_cache.bat`

## 6) Push notifications (FCM) and local care reminders

- **Local daily reminder**: Cloud families screen → toggle “Daily gentle reminder” and set **Reminder time** (device-local schedule, not server push; default 10:00). If the OS denies notification permission when you turn it on, a snackbar suggests opening system settings. Tapping the notification opens the cloud families flow when you are signed in with Supabase (including after cold start, with a short auth wait). In **dual mode** (local home + cloud tabs), the tap switches to the **Cloud** tab instead of stacking another cloud screen.
- **FCM token → Supabase** `device_push_tokens`: run `dart pub global activate flutterfire_cli` then `flutterfire configure` in `mobile/` to replace `lib/firebase_options.dart` and add real `android/app/google-services.json` (and iOS `GoogleService-Info.plist` when building for iOS). Placeholder files let the project compile; real tokens require a Firebase project. Server-side sends can use the Edge Function `send-fcm-push` in `../supabase/functions/` (see `../supabase/README.md`).
