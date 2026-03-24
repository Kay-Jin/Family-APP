class BirthdayReminder {
  BirthdayReminder({
    required this.id,
    required this.familyId,
    required this.userId,
    required this.birthday,
    required this.notifyDaysBefore,
    required this.enabled,
  });

  final int id;
  final int familyId;
  final int userId;
  final String birthday;
  final int notifyDaysBefore;
  final bool enabled;

  factory BirthdayReminder.fromJson(Map<String, dynamic> json) {
    return BirthdayReminder(
      id: json['id'] as int,
      familyId: json['family_id'] as int,
      userId: json['user_id'] as int,
      birthday: json['birthday'] as String,
      notifyDaysBefore: json['notify_days_before'] as int,
      enabled: (json['enabled'] as int) == 1,
    );
  }
}
