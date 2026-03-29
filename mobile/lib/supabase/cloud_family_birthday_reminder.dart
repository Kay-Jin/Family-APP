class CloudFamilyBirthdayReminder {
  CloudFamilyBirthdayReminder({
    required this.id,
    required this.familyId,
    required this.createdBy,
    required this.personName,
    required this.month,
    required this.day,
    required this.notifyDaysBefore,
    required this.createdAt,
  });

  final String id;
  final String familyId;
  final String createdBy;
  final String personName;
  final int month;
  final int day;
  final int notifyDaysBefore;
  final DateTime createdAt;

  factory CloudFamilyBirthdayReminder.fromJson(Map<String, dynamic> json) {
    return CloudFamilyBirthdayReminder(
      id: json['id'] as String,
      familyId: json['family_id'] as String,
      createdBy: json['created_by'] as String,
      personName: json['person_name'] as String,
      month: json['month'] as int,
      day: json['day'] as int,
      notifyDaysBefore: json['notify_days_before'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
