import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Weekly gentle family-brief nudge. Separate prefs/channel from [CareLocalNotifications] call nudges.
class FamilyBriefLocalNotifications {
  static const _id = 88901;
  static FlutterLocalNotificationsPlugin? _plugin;

  static const prefsEnabled = 'family_brief_weekly_reminder_v1_enabled';
  static const _prefsHour = 'family_brief_weekly_reminder_v1_hour';
  static const _prefsMinute = 'family_brief_weekly_reminder_v1_minute';
  static const _prefsWeekday = 'family_brief_weekly_reminder_v1_weekday';
  static const _prefsTitle = 'family_brief_weekly_reminder_v1_title';
  static const _prefsBody = 'family_brief_weekly_reminder_v1_body';

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
    await _plugin!.initialize(initSettings);
    if (Platform.isAndroid) {
      await _plugin!
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  static tz.TZDateTime _nextInstanceOfWeekday(int weekday, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    while (scheduled.weekday != weekday || !scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  static Future<void> rescheduleIfEnabled() async {
    if (kIsWeb || _plugin == null) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;
    final p = await SharedPreferences.getInstance();
    if (!(p.getBool(prefsEnabled) ?? false)) {
      await _plugin!.cancel(_id);
      return;
    }
    final hour = p.getInt(_prefsHour) ?? 10;
    final minute = p.getInt(_prefsMinute) ?? 0;
    final weekday = p.getInt(_prefsWeekday) ?? DateTime.sunday;
    final title = p.getString(_prefsTitle) ?? 'Family check-in';
    final body = p.getString(_prefsBody) ?? 'A short note to family is enough.';
    await _plugin!.cancel(_id);
    final next = _nextInstanceOfWeekday(weekday, hour, minute);
    const androidChannel = AndroidNotificationDetails(
      'family_brief_weekly_v1',
      'Family check-in reminders',
      channelDescription: 'Gentle weekly reminder; separate from call reminders',
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
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  static Future<bool> isEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(prefsEnabled) ?? false;
  }

  static Future<TimeOfDay> getReminderTime() async {
    final p = await SharedPreferences.getInstance();
    return TimeOfDay(
      hour: p.getInt(_prefsHour) ?? 10,
      minute: p.getInt(_prefsMinute) ?? 0,
    );
  }

  static Future<int> getWeekday() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_prefsWeekday) ?? DateTime.sunday;
  }

  static Future<void> setEnabled({
    required bool enabled,
    required String title,
    required String body,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(prefsEnabled, enabled);
    await p.setString(_prefsTitle, title);
    await p.setString(_prefsBody, body);
    await rescheduleIfEnabled();
  }

  static Future<void> setSchedule({
    required int weekday,
    required int hour,
    required int minute,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_prefsWeekday, weekday);
    await p.setInt(_prefsHour, hour);
    await p.setInt(_prefsMinute, minute);
    await rescheduleIfEnabled();
  }
}
