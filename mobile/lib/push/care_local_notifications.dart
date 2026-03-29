import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

typedef CareCloudTabHandler = void Function();

/// Daily gentle reminders for the care hub. Separate notification id + Android channel from [FamilyBriefLocalNotifications].
class CareLocalNotifications {
  static CareCloudTabHandler? _dualSessionCloudHandler;

  static const _id = 88902;
  static const _notificationPayload = 'care_daily_local_v1';
  static FlutterLocalNotificationsPlugin? _plugin;

  static const _prefsEnabled = 'care_daily_reminder_enabled_v1';
  static const _prefsHour = 'care_daily_reminder_hour_v1';
  static const _prefsMinute = 'care_daily_reminder_minute_v1';
  static const _prefsTitle = 'care_daily_reminder_title_v1';
  static const _prefsBody = 'care_daily_reminder_body_v1';

  static void attachNavigator(GlobalKey<NavigatorState> _) {}

  static Future<void> ensureInitialized() async {
    if (kIsWeb) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;
    tzdata.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
    _plugin = FlutterLocalNotificationsPlugin();
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin!.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        if (details.payload == _notificationPayload) {
          notifyOpenCloudTab();
        }
      },
    );
    if (Platform.isAndroid) {
      await _plugin!
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  static tz.TZDateTime _nextDailyInstance(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  static Future<void> rescheduleIfEnabled() async {
    if (kIsWeb || _plugin == null) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;
    final p = await SharedPreferences.getInstance();
    if (!(p.getBool(_prefsEnabled) ?? false)) {
      await _plugin!.cancel(_id);
      return;
    }
    final hour = p.getInt(_prefsHour) ?? 10;
    final minute = p.getInt(_prefsMinute) ?? 0;
    final title = p.getString(_prefsTitle) ?? 'Family care';
    final body = p.getString(_prefsBody) ?? 'A gentle reminder to connect.';
    await _plugin!.cancel(_id);
    final next = _nextDailyInstance(hour, minute);
    const androidChannel = AndroidNotificationDetails(
      'care_daily_reminder_v1',
      'Daily care reminders',
      channelDescription: 'Gentle daily reminder; separate from family check-in reminders',
      importance: Importance.defaultImportance,
    );
    const details = NotificationDetails(
      android: androidChannel,
      iOS: DarwinNotificationDetails(),
    );
    await _plugin!.zonedSchedule(
      _id,
      title,
      body,
      next,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: _notificationPayload,
    );
  }

  static void handleLaunchNotificationIfAny() {
    if (kIsWeb || _plugin == null) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;
    _plugin!.getNotificationAppLaunchDetails().then((details) {
      final n = details?.notificationResponse;
      if (details?.didNotificationLaunchApp == true && n?.payload == _notificationPayload) {
        notifyOpenCloudTab();
      }
    });
  }

  static void registerDualSessionCloudTabHandler(CareCloudTabHandler? handler) {
    _dualSessionCloudHandler = handler;
  }

  static void notifyOpenCloudTab() {
    _dualSessionCloudHandler?.call();
  }

  static Future<bool> isEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_prefsEnabled) ?? false;
  }

  static Future<TimeOfDay> getReminderTime() async {
    final p = await SharedPreferences.getInstance();
    final h = p.getInt(_prefsHour) ?? 10;
    final m = p.getInt(_prefsMinute) ?? 0;
    return TimeOfDay(hour: h, minute: m);
  }

  static Future<void> setReminderTime({required int hour, required int minute}) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_prefsHour, hour);
    await p.setInt(_prefsMinute, minute);
    await rescheduleIfEnabled();
  }

  static Future<bool> setEnabled({
    required bool enabled,
    required String title,
    required String body,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_prefsEnabled, enabled);
    await p.setString(_prefsTitle, title);
    await p.setString(_prefsBody, body);
    if (kIsWeb || _plugin == null) return true;
    if (!Platform.isAndroid && !Platform.isIOS) return true;
    var granted = true;
    if (enabled && Platform.isAndroid) {
      granted = await _plugin!
              .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission() ??
          true;
    }
    await rescheduleIfEnabled();
    return granted;
  }
}
