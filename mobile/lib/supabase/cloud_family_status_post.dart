class CloudFamilyStatusPost {
  CloudFamilyStatusPost({
    required this.id,
    required this.familyId,
    required this.userId,
    this.authorDisplayName,
    required this.statusCode,
    this.note,
    required this.createdAt,
  });

  final String id;
  final String familyId;
  final String userId;
  final String? authorDisplayName;
  final String statusCode;
  final String? note;
  final DateTime createdAt;

  factory CloudFamilyStatusPost.fromJson(Map<String, dynamic> json) {
    return CloudFamilyStatusPost(
      id: json['id'] as String,
      familyId: json['family_id'] as String,
      userId: json['user_id'] as String,
      authorDisplayName: json['author_display_name'] as String?,
      statusCode: json['status_code'] as String,
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
