import 'package:family_mobile/firebase_options.dart';
import 'package:family_mobile/push/device_push_registration.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Registers FCM token with Supabase `device_push_tokens` (Android / iOS only).
/// Uses placeholder [DefaultFirebaseOptions] until you run `flutterfire configure`.
class FcmTokenSync {
  FcmTokenSync._();

  static Future<void> register() async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } catch (e, st) {
      debugPrint('Firebase init skipped (add real google-services / Firebase project): $e\n$st');
      return;
    }
    try {
      final fm = FirebaseMessaging.instance;
      await fm.requestPermission();
      final token = await fm.getToken();
      final plat = defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
      if (token != null && token.isNotEmpty) {
        await DevicePushRegistration.saveToken(token: token, platform: plat);
      }
      FirebaseMessaging.instance.onTokenRefresh.listen((t) {
        DevicePushRegistration.saveToken(token: t, platform: plat);
      });
    } catch (e, st) {
      debugPrint('FCM token registration skipped: $e\n$st');
    }
  }
}
