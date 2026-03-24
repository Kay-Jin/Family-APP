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

## 4) Next steps

- Replace mock code login with real WeChat SDK login
- Add pages for:
  - photo upload
  - comments/likes
  - birthday reminder create/list
- Add routing and app shell

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
