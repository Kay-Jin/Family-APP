class CloudFamilyVoiceMessage {
  CloudFamilyVoiceMessage({
    required this.id,
    required this.familyId,
    required this.userId,
    this.authorDisplayName,
    required this.title,
    required this.storagePath,
    this.durationSeconds,
    required this.createdAt,
  });

  final String id;
  final String familyId;
  final String userId;
  final String? authorDisplayName;
  final String title;
  final String storagePath;
  final int? durationSeconds;
  final DateTime createdAt;

  factory CloudFamilyVoiceMessage.fromJson(Map<String, dynamic> json) {
    return CloudFamilyVoiceMessage(
      id: json['id'] as String,
      familyId: json['family_id'] as String,
      userId: json['user_id'] as String,
      authorDisplayName: json['author_display_name'] as String?,
      title: json['title'] as String,
      storagePath: json['storage_path'] as String,
      durationSeconds: json['duration_seconds'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
