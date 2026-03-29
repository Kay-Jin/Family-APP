import 'package:family_mobile/supabase/cloud_family_birthday_reminder.dart';

/// Lightweight mood / distress phrases (Chinese-first product).
const List<String> careMoodKeywordHints = [
  '情绪低落',
  '难受',
  '想哭',
  '好累',
  '睡不着',
  '不想活了',
];

enum CareNudgeKind { staleActivity, birthdaySoon, moodKeyword, presenceQuiet }

class CareNudge {
  const CareNudge({
    required this.kind,
    required this.messageKey,
    this.params = const {},
  });

  final CareNudgeKind kind;
  final String messageKey;
  final Map<String, String> params;
}

class BirthdayNudgeCandidate {
  BirthdayNudgeCandidate({
    required this.reminder,
    required this.daysUntilNext,
  });

  final CloudFamilyBirthdayReminder reminder;
  final int daysUntilNext;
}

class CareNudgeEvaluator {
  CareNudgeEvaluator._();

  static DateTime? latestOf(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }

  /// Returns true if [text] contains any known mood keyword.
  static bool textContainsMoodKeyword(String text) {
    final t = text.trim();
    if (t.isEmpty) return false;
    for (final k in careMoodKeywordHints) {
      if (t.contains(k)) return true;
    }
    return false;
  }

  /// Next occurrence of month/day in the same calendar year as [now], or next year if passed.
  static DateTime nextOccurrenceOfMonthDay(DateTime now, int month, int day) {
    var candidate = DateTime(now.year, month, day);
    final today = DateTime(now.year, now.month, now.day);
    if (candidate.isBefore(today)) {
      candidate = DateTime(now.year + 1, month, day);
    }
    return candidate;
  }

  static int daysBetweenCalendarDates(DateTime fromDay, DateTime toDay) {
    final a = DateTime(fromDay.year, fromDay.month, fromDay.day);
    final b = DateTime(toDay.year, toDay.month, toDay.day);
    return b.difference(a).inDays;
  }

  static List<BirthdayNudgeCandidate> upcomingBirthdays({
    required DateTime now,
    required List<CloudFamilyBirthdayReminder> reminders,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final out = <BirthdayNudgeCandidate>[];
    for (final r in reminders) {
      final next = nextOccurrenceOfMonthDay(now, r.month, r.day);
      final days = daysBetweenCalendarDates(today, next);
      if (days >= 0 && days <= r.notifyDaysBefore) {
        out.add(BirthdayNudgeCandidate(reminder: r, daysUntilNext: days));
      }
    }
    return out;
  }

  /// Non-pushy hints for the Care tab (not scheduled notifications).
  static List<CareNudge> evaluate({
    required DateTime now,
    DateTime? lastStatusAt,
    DateTime? lastAnswerAt,
    List<CloudFamilyBirthdayReminder> birthdays = const [],
    bool moodKeywordInRecentContent = false,
    bool gentleRadarEnabled = false,
    String? currentUserId,
    Map<String, DateTime> otherMembersCarePresence = const {},
    int staleAfterDays = 3,
    Duration presenceQuietAfter = const Duration(hours: 48),
  }) {
    final nudges = <CareNudge>[];
    final lastActivity = latestOf(lastStatusAt, lastAnswerAt);
    if (lastActivity != null) {
      final daysIdle = now.difference(lastActivity).inDays;
      if (daysIdle >= staleAfterDays) {
        nudges.add(CareNudge(
          kind: CareNudgeKind.staleActivity,
          messageKey: 'care_nudge_stale_family',
          params: {'days': '$daysIdle'},
        ));
      }
    } else {
      nudges.add(const CareNudge(
        kind: CareNudgeKind.staleActivity,
        messageKey: 'care_nudge_no_activity_yet',
      ));
    }

    final upcoming = upcomingBirthdays(now: now, reminders: birthdays);
    for (final u in upcoming) {
      nudges.add(CareNudge(
        kind: CareNudgeKind.birthdaySoon,
        messageKey: 'care_nudge_birthday',
        params: {
          'name': u.reminder.personName,
          'days': '${u.daysUntilNext}',
        },
      ));
    }

    if (moodKeywordInRecentContent) {
      nudges.add(const CareNudge(
        kind: CareNudgeKind.moodKeyword,
        messageKey: 'care_nudge_mood',
      ));
    }

    if (gentleRadarEnabled && currentUserId != null) {
      for (final e in otherMembersCarePresence.entries) {
        if (e.key == currentUserId) continue;
        if (now.difference(e.value) > presenceQuietAfter) {
          nudges.add(CareNudge(
            kind: CareNudgeKind.presenceQuiet,
            messageKey: 'care_nudge_presence_quiet',
            params: {'hours': '${presenceQuietAfter.inHours}'},
          ));
          break;
        }
      }
    }

    return nudges;
  }
}
