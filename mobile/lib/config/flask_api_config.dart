import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Resolves the Flask REST base URL for local / LAN / production.
///
/// Priority:
/// 1. `--dart-define=FLASK_BASE_URL=https://api.example.com` (compile-time)
/// 2. Value saved in SharedPreferences (login screen → Local Flask API)
/// 3. Android emulator default `http://10.0.2.2:8000`, else `http://127.0.0.1:8000`
class FlaskApiConfig {
  FlaskApiConfig._();

  static const _prefsKey = 'flask_base_url_v1';
  static String? _prefsOverride;

  /// Call from `main()` after [WidgetsFlutterBinding.ensureInitialized].
  static Future<void> loadFromPrefs() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_prefsKey);
    _prefsOverride = (s != null && s.trim().isNotEmpty) ? s.trim() : null;
  }

  /// Normalized base URL (no trailing slash).
  static String resolve() {
    const env = String.fromEnvironment('FLASK_BASE_URL', defaultValue: '');
    final e = env.trim();
    if (e.isNotEmpty) {
      return normalize(e);
    }
    final o = _prefsOverride;
    if (o != null && o.isNotEmpty) {
      return normalize(o);
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }

  static String normalize(String url) {
    var u = url.trim();
    if (u.isEmpty) {
      return 'http://127.0.0.1:8000';
    }
    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      u = 'http://$u';
    }
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  /// Persists user-chosen URL and updates in-memory override so [resolve] returns it immediately.
  static Future<void> persistOverride(String url) async {
    final n = normalize(url);
    final p = await SharedPreferences.getInstance();
    await p.setString(_prefsKey, n);
    _prefsOverride = n;
  }

  /// Removes saved override; next [resolve] uses env or platform defaults.
  static Future<void> clearOverride() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_prefsKey);
    _prefsOverride = null;
  }
}
