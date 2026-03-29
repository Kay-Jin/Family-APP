import 'dart:async';

import 'package:family_mobile/screens/home_screen.dart';
import 'package:family_mobile/l10n/app_strings.dart';
import 'package:family_mobile/push/care_local_notifications.dart';
import 'package:family_mobile/push/family_brief_local_notifications.dart';
import 'package:family_mobile/push/fcm_token_sync.dart';
import 'package:family_mobile/screens/login_screen.dart';
import 'package:family_mobile/screens/supabase_family_screen.dart';
import 'package:family_mobile/screens/dual_session_shell.dart';
import 'package:family_mobile/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:family_mobile/supabase/supabase_config.dart';
import 'package:family_mobile/wechat/wechat_auth_service.dart';
import 'package:flutter/foundation.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
  GlobalKey<NavigatorState>? appNavigatorKey;
  if (!kIsWeb) {
    final navKey = GlobalKey<NavigatorState>();
    appNavigatorKey = navKey;
    CareLocalNotifications.attachNavigator(navKey);
    await CareLocalNotifications.ensureInitialized();
    await CareLocalNotifications.rescheduleIfEnabled();
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      await FamilyBriefLocalNotifications.ensureInitialized();
      await FamilyBriefLocalNotifications.rescheduleIfEnabled();
    }
  }
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
    await WechatAuthService.instance.prepare();
    unawaited(FcmTokenSync.register());
  }
  runApp(FamilyApp(navigatorKey: appNavigatorKey));
}

class FamilyApp extends StatefulWidget {
  const FamilyApp({super.key, this.navigatorKey});

  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  State<FamilyApp> createState() => _FamilyAppState();
}

class _FamilyAppState extends State<FamilyApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      CareLocalNotifications.handleLaunchNotificationIfAny();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState()..bootstrap(),
      child: Consumer<AppState>(
        builder: (context, appState, _) => MaterialApp(
          navigatorKey: widget.navigatorKey,
          locale: appState.localeCode == null ? null : Locale(appState.localeCode!),
          onGenerateTitle: (context) => AppStrings.of(context).text('app_title'),
          supportedLocales: AppStrings.supportedLocales,
          localizationsDelegates: const [
            AppStrings.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFE6866A),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFFFF8F4),
          appBarTheme: const AppBarTheme(
            centerTitle: false,
            elevation: 0,
            backgroundColor: Color(0xFFFFF8F4),
            foregroundColor: Color(0xFF3E2F2A),
            titleTextStyle: TextStyle(
              color: Color(0xFF3E2F2A),
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          cardTheme: CardThemeData(
            color: Colors.white,
            elevation: 0.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFFFFF3EB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE6866A), width: 1.2),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
          home: Builder(
            builder: (context) {
              if (appState.isLoading) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              if (!appState.isLoggedIn) {
                return const LoginScreen();
              }
              if (appState.hasFlaskSession && appState.hasSupabaseSession) {
                return const DualSessionShell();
              }
              if (appState.hasSupabaseSession && !appState.hasFlaskSession) {
                return const SupabaseFamilyScreen();
              }
              return const HomeScreen();
            },
          ),
        ),
      ),
    );
  }
}
