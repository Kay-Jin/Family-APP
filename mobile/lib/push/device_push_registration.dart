import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Persists FCM/APNs token for the signed-in Supabase user.
/// Call from `firebase_messaging` after obtaining a token (dependency not added yet).
class DevicePushRegistration {
  DevicePushRegistration._();

  static String _normalizePlatform(String platform) {
    final p = platform.toLowerCase().trim();
    if (p == 'android' || p == 'ios' || p == 'web') return p;
    return 'unknown';
  }

  /// Replaces any existing row for this user + platform.
  static Future<void> saveToken({
    required String token,
    required String platform,
    SupabaseClient? client,
  }) async {
    final c = client ?? Supabase.instance.client;
    final user = c.auth.currentUser;
    if (user == null) return;
    final plat = _normalizePlatform(platform);
    if (token.isEmpty) return;
    try {
      await c.from('device_push_tokens').delete().eq('user_id', user.id).eq('platform', plat);
      await c.from('device_push_tokens').insert({
        'user_id': user.id,
        'token': token,
        'platform': plat,
      });
    } catch (e, st) {
      debugPrint('DevicePushRegistration.saveToken failed: $e\n$st');
    }
  }
}
