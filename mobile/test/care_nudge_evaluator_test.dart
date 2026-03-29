import 'package:family_mobile/care/care_nudge_evaluator.dart';
import 'package:family_mobile/supabase/cloud_family_birthday_reminder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mood keyword detection', () {
    expect(CareNudgeEvaluator.textContainsMoodKeyword('今天情绪低落'), true);
    expect(CareNudgeEvaluator.textContainsMoodKeyword('hello'), false);
  });

  test('stale activity nudge when quiet for several days', () {
    final now = DateTime.utc(2026, 3, 29, 12);
    final last = now.subtract(const Duration(days: 4));
    final n = CareNudgeEvaluator.evaluate(
      now: now,
      lastStatusAt: last,
      lastAnswerAt: null,
    );
    expect(n.where((x) => x.kind == CareNudgeKind.staleActivity).length, 1);
    expect(n.first.params['days'], isNotNull);
  });

  test('no stale nudge when recently active', () {
    final now = DateTime.utc(2026, 3, 29, 12);
    final last = now.subtract(const Duration(days: 1));
    final n = CareNudgeEvaluator.evaluate(
      now: now,
      lastStatusAt: null,
      lastAnswerAt: last,
      staleAfterDays: 3,
    );
    expect(n.where((x) => x.kind == CareNudgeKind.staleActivity).isEmpty, true);
  });

  test('birthday within notify window', () {
    final now = DateTime.utc(2026, 3, 29);
    final reminder = CloudFamilyBirthdayReminder(
      id: 'a',
      familyId: 'f',
      createdBy: 'u',
      personName: 'Mom',
      month: 4,
      day: 1,
      notifyDaysBefore: 3,
      createdAt: now,
    );
    final upcoming = CareNudgeEvaluator.upcomingBirthdays(now: now, reminders: [reminder]);
    expect(upcoming.length, 1);
    expect(upcoming.first.daysUntilNext, 3);
  });

  test('evaluator includes birthday nudge', () {
    final now = DateTime.utc(2026, 3, 29);
    final reminder = CloudFamilyBirthdayReminder(
      id: 'a',
      familyId: 'f',
      createdBy: 'u',
      personName: 'Dad',
      month: 3,
      day: 30,
      notifyDaysBefore: 7,
      createdAt: now,
    );
    final n = CareNudgeEvaluator.evaluate(
      now: now,
      lastStatusAt: now,
      lastAnswerAt: now,
      birthdays: [reminder],
    );
    expect(n.where((x) => x.kind == CareNudgeKind.birthdaySoon).length, 1);
  });

  test('mood keyword nudge', () {
    final now = DateTime.utc(2026, 3, 29);
    final n = CareNudgeEvaluator.evaluate(
      now: now,
      lastStatusAt: now,
      lastAnswerAt: now,
      moodKeywordInRecentContent: true,
    );
    expect(n.where((x) => x.kind == CareNudgeKind.moodKeyword).length, 1);
  });

  test('nextOccurrenceOfMonthDay rolls to next year', () {
    final now = DateTime.utc(2026, 6, 15);
    final next = CareNudgeEvaluator.nextOccurrenceOfMonthDay(now, 3, 10);
    expect(next.year, 2027);
    expect(next.month, 3);
    expect(next.day, 10);
  });
}
