import 'package:family_mobile/screens/supabase_family_screen.dart';
import 'package:flutter/foundation.dart' show debugPrint, defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Daily gentle reminder on device (local). Independent of FCM until you send pushes from a backend.
class CareLocalNotifications {
  CareLocalNotifications._();

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static const _channelId = 'family_care_daily';
  static const _notifId = 94001;
  static const prefEnabled = 'care_daily_local_reminder_v1';
  static const prefTitle = 'care_notif_title_stored_v1';
  static const prefBody = 'care_notif_body_stored_v1';

  /// Payload on scheduled notifications; tap opens [SupabaseFamilyScreen] when signed in.
  static const payloadOpenCloudFamilies = 'open_cloud_families';

  static GlobalKey<NavigatorState>? _navigatorKey;

  static void attachNavigator(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  static void _openCloudFamiliesIfSignedIn() {
    final nav = _navigatorKey?.currentState;
    if (nav == null) return;
    if (Supabase.instance.client.auth.currentSession == null) return;
    nav.push(MaterialPageRoute<void>(builder: (_) => const SupabaseFamilyScreen()));
  }

  static void onNotificationTapped(NotificationResponse response) {
    if (response.payload != payloadOpenCloudFamilies) return;
    _openCloudFamiliesIfSignedIn();
  }

  /// After first frame (e.g. cold start from notification). Retries briefly while auth restores.
  static Future<void> handleLaunchNotificationIfAny() async {
    if (kIsWeb || !_initialized) return;
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      final r = details?.notificationResponse;
      if (r?.payload != payloadOpenCloudFamilies) return;
      for (var i = 0; i < 8; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        if (Supabase.instance.client.auth.currentSession != null) {
          _openCloudFamiliesIfSignedIn();
          return;
        }
      }
    } catch (e, st) {
      debugPrint('CareLocalNotifications.handleLaunchNotificationIfAny: $e\n$st');
    }
  }

  static Future<void> ensureInitialized() async {
    if (kIsWeb) return;
    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.local);
    } catch (e, st) {
      debugPrint('CareLocalNotifications timezone init: $e\n$st');
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: onNotificationTapped,
    );

    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        'Family care',
        description: 'Gentle daily reminder to connect with family.',
        importance: Importance.defaultImportance,
      ),
    );
    _initialized = true;
  }

  static Future<bool> isEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(prefEnabled) ?? false;
  }

  static Future<void> setEnabled({
    required bool enabled,
    required String title,
    required String body,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(prefEnabled, enabled);
    if (!enabled) {
      await _plugin.cancel(_notifId);
      return;
    }
    await p.setString(prefTitle, title);
    await p.setString(prefBody, body);

    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      await ios?.requestPermissions(alert: true, badge: true, sound: true);
    }

    await _scheduleDaily(title: title, body: body);
  }

  /// Call on startup after [ensureInitialized] so scheduled alarms survive restarts.
  static Future<void> rescheduleIfEnabled() async {
    if (kIsWeb) return;
    final p = await SharedPreferences.getInstance();
    if (p.getBool(prefEnabled) != true) return;
    final title = p.getString(prefTitle);
    final body = p.getString(prefBody);
    if (title == null || body == null || title.isEmpty || body.isEmpty) return;
    await _scheduleDaily(title: title, body: body);
  }

  static Future<void> _scheduleDaily({required String title, required String body}) async {
    if (kIsWeb) return;
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 10, 0);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      _notifId,
      title,
      body,
      scheduled,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Family care',
          channelDescription: body,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payloadOpenCloudFamilies,
    );
  }
}
