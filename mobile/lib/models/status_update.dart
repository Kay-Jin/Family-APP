class StatusUpdate {
  StatusUpdate({
    required this.id,
    required this.familyId,
    required this.userId,
    required this.userDisplayName,
    required this.statusCode,
    required this.note,
    required this.createdAt,
  });

  final int id;
  final int familyId;
  final int userId;
  final String userDisplayName;
  final String statusCode;
  final String note;
  final String createdAt;

  factory StatusUpdate.fromJson(Map<String, dynamic> json) {
    return StatusUpdate(
      id: json['id'] as int,
      familyId: json['family_id'] as int,
      userId: json['user_id'] as int,
      userDisplayName: (json['user_display_name'] ?? 'Unknown') as String,
      statusCode: json['status_code'] as String,
      note: (json['note'] ?? '') as String,
      createdAt: json['created_at'] as String,
    );
  }
}
