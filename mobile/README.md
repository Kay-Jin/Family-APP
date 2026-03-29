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
- **Still rough / prod**: mock WeChat code path for some flows; real WeChat SDK + Firebase (`flutterfire configure`) for production push — see §7.

## 5) iPhone（全家使用）

- **构建**：在 **Mac** 上安装 Xcode 与 Flutter，打开 `mobile/ios/Runner.xcworkspace`，用 **Apple ID** 完成签名（免费账号可装到自己的手机；分发家人建议 **TestFlight** 或企业/商店流程）。
- **局域网后端**：iPhone 与运行 Flask 的电脑必须在 **同一 Wi‑Fi**。电脑端启动后端并监听 `0.0.0.0`（见 `../backend/README.md`）。在登录页展开 **本地 Flask 后端**，填写电脑的局域网地址，例如 `http://192.168.1.10:8000`。**真机不要填 `127.0.0.1`**（那是手机自己，不是你的电脑）。
- **首次安装**：设置 → 通用 → VPN 与设备管理 → **信任开发者**（若系统提示）。
- **推送**：真 FCM/APNs 需在 Firebase 控制台配置 iOS 应用，将 **`GoogleService-Info.plist`** 放入 `ios/Runner/`，并在 Xcode 中为 Runner 打开 **Push Notifications** 能力（Release 归档时 `aps-environment` 应为 **production**）。占位配置仅能编译，不能收到远端推送。
- **显示名**：主屏幕名称在 `ios/Runner/Info.plist` 的 `CFBundleDisplayName`（当前为「家人」）。正式发布前请将 **Bundle Identifier** 从 `com.example.*` 改为你自己的反向域名（Xcode → Runner → Signing & Capabilities）。

## 6) If Android build times out on network

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

## 7) Push notifications (FCM) and local care reminders

- **Local daily reminder**: Cloud families screen → toggle “Daily gentle reminder” and set **Reminder time** (device-local schedule, not server push; default 10:00). If the OS denies notification permission when you turn it on, a snackbar suggests opening system settings. Tapping the notification opens the cloud families flow when you are signed in with Supabase (including after cold start, with a short auth wait). In **dual mode** (local home + cloud tabs), the tap switches to the **Cloud** tab instead of stacking another cloud screen.
- **FCM token → Supabase** `device_push_tokens`: run `dart pub global activate flutterfire_cli` then `flutterfire configure` in `mobile/` to replace `lib/firebase_options.dart` and add real `android/app/google-services.json` (and iOS `GoogleService-Info.plist` when building for iOS). Placeholder files let the project compile; real tokens require a Firebase project. Server-side sends can use the Edge Function `send-fcm-push` in `../supabase/functions/` (see `../supabase/README.md`).
