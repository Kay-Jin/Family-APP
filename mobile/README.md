# Family Mobile (Flutter Scaffold)

This folder contains a Flutter client scaffold that works with the backend in `../backend`.

## Implemented flow

- **Cloud**: Email/password (and **家庭一键登录** for preset family accounts) → **Supabase** session; families, album, care features use Postgres + Storage on Supabase.
- **WeChat** (fluwx + Edge Function) is **paused in the UI**; the Edge Function `wechat-supabase-auth` can stay deployed for later. `AppState` still supports exchange via Edge/Flask if you re-enable buttons.
- **Local (optional)**: Flask + SQLite “home” features when you also sign in with the developer/mock path or dual session.

## 1) Install Flutter SDK

Follow official docs: <https://docs.flutter.dev/get-started/install/windows/mobile>

## 2) Run

```powershell
cd mobile
flutter pub get
flutter run
```

### Windows 电脑 + iPhone 手机，怎么配合？

- **在 Windows 上可以**：改 Flutter/Dart 代码、跑 **`flutter run` 到 Android 模拟器或安卓真机**、在本机跑 **Flask 后端**、用 **局域网 IP** 给手机上的 App 填接口地址（与「全家用 iPhone」不冲突——只是开发机是 Windows）。
- **装到 iPhone / 打 iOS 包**：苹果要求必须用 **macOS + Xcode** 编译和签名。Windows 上**不能**官方地完成 `flutter build ipa` 或把调试版装到 iPhone（没有 Xcode）。
- **常见做法**：（1）日常在 Windows 上用 Android 先把功能调通；（2）需要上 iPhone 时，用一台 **Mac**（自己的、借的、或 **云 Mac / CI**，例如带 macOS 的 GitHub Actions、Codemagic 等）拉代码执行 **`flutter build ios`** 或在 Xcode 里 **Run 到真机**。
- **后端**：Flask 继续在 Windows 上 `0.0.0.0` 监听即可；iPhone 与电脑同一 Wi‑Fi，App 里填 `http://你电脑的局域网IP:8000`（不要用 `127.0.0.1`）。

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

## 3.5) Production use (families, no LAN Flask)

1. Create or use a **Supabase** project; run SQL from `../supabase/migrations/` (or linked `db push`).
2. Edge Functions: deploy **`wechat-supabase-auth`** and **`send-fcm-push`** (see `../supabase/README.md`). If you use Cursor with the Supabase MCP linked to your project, deployment may already be done; still add **Secrets** in the dashboard (e.g. `SUPABASE_ANON_KEY` on the WeChat function when you turn WeChat back on).
3. **Family preset logins** (`lib/config/family_quick_login.dart`): Supabase Auth requires a real email shape. The app uses **`jinshanglong@member.family`** and **`peimeiling@member.family`** with the shared password from that file. In **Supabase → Authentication → Users → Add user**, create both addresses, set the password, and tick **email confirmed** (or disable “confirm email” for the project while testing).
4. Build the app with your project keys (never commit the service role key; only anon/publishable in the client):

```powershell
cd mobile
flutter build ipa `
  --dart-define=SUPABASE_URL=https://YOUR_REF.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=your_publishable_or_anon_key
```

5. **iOS**: Open `ios/Runner.xcworkspace` in Xcode, set **Signing** and **Bundle ID**, then **Product → Archive** for TestFlight/App Store when you have a paid Apple Developer Program membership.

6. **Android**: Upload the release `.aab` to Play Console with the same `dart-define` values (or CI secrets).

### 3.6) 不花钱买开发者账号，能不能像 App Store 一样装 iPhone？

**不能长期等价。** Apple 规定：把 App **稳定装到多台 iPhone、家人随便装、不过期**，需要 **Apple Developer Program（约 $99/年）** 走 TestFlight 或 App Store。

**免费 Apple ID + Xcode** 可以：

- 用 **Personal Team** 把工程 **Run 到你自己的 iPhone**；
- 证书大约 **每 7 天**会过期，需要再用 Mac 连上手机 **重新编译安装**；
- **无法**给家人一个永久 `.ipa` 包让他们像从商店下载一样一直用（除非每人自己用 Xcode 签，或你后续开通开发者账号）。

所以没有「完全免费又和商店一样」的官方方案；当前阶段建议在 **Mac + Xcode + 数据线** 给自己装调试版，等功能和账号就绪再上 TestFlight。

## 4) App structure (current)

- **Local (Flask) home**: `HomeScreen` — families, daily Q&A, photos (upload, comments, likes), birthday reminders, voice notes, etc.
- **Cloud (Supabase)**: `SupabaseFamilyScreen` / detail — invite codes, care panel, cloud album, companion room, medical card sync, cloud birthdays, etc.
- **Dual session**: when signed in to both backends, `DualSessionShell` uses a bottom nav (local home + cloud families). The app registers your Supabase user id on the Flask profile (`PATCH /users/me`) so the Python backend can fan out FCM to other members after local photos, likes, comments, daily answers, or birthday reminders when push env is configured.
- **Release builds**: WeChat entry is currently **hidden**; use email or **家庭一键登录**.
- **Push**: Firebase (`flutterfire configure`) + Edge Function `send-fcm-push` secrets — see §7.

## 5) iPhone（全家使用）

- **构建**：在 **Mac** 上安装 Xcode 与 Flutter，打开 `mobile/ios/Runner.xcworkspace`，用 **Apple ID** 完成签名（免费账号可装到自己的手机；分发家人建议 **TestFlight** 或企业/商店流程）。
- **云端（推荐）**：家人用 **邮箱** 或登录页的 **爸爸 / 妈妈** 一键登录时，数据在 **Supabase**。请在后台创建 `jinshanglong@member.family`、`peimeiling@member.family` 用户（见 §3.5）。微信入口已暂时关闭；边缘函数可预留给以后。
- **局域网 Flask（可选）**：若仍使用本地家庭后端，iPhone 与电脑须 **同一 Wi‑Fi**，在登录页展开 **本地 Flask 后端** 填写 `http://192.168.x.x:8000`；**不要填 `127.0.0.1`**。
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
