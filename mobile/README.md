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

## 3) API base URL

Current API URL is in `lib/state/app_state.dart`:

- `http://127.0.0.1:8000` (for emulator on same machine)

If testing on a real phone, change it to your computer LAN IP, e.g.:

- `http://192.168.1.10:8000`

## 4) App structure (current)

- **Local (Flask) home**: `HomeScreen` — families, daily Q&A, photos (upload, comments, likes), birthday reminders, voice notes, etc.
- **Cloud (Supabase)**: `SupabaseFamilyScreen` / detail — invite codes, care panel, cloud album, companion room, medical card sync, cloud birthdays, etc.
- **Dual session**: when signed in to both backends, `DualSessionShell` uses a bottom nav (local home + cloud families). The app registers your Supabase user id on the Flask profile (`PATCH /users/me`) so the Python backend can fan out FCM to other members after local photos or birthday reminders when push env is configured.
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
