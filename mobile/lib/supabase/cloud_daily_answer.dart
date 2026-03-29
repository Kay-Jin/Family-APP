class CloudDailyAnswer {
  CloudDailyAnswer({
    required this.id,
    required this.questionId,
    required this.userId,
    required this.userDisplayName,
    required this.answerText,
    this.imagePath,
    required this.createdAt,
    this.answerEncryptionVersion = 0,
    this.answerCipherPayload,
    this.answerImageEncryptionVersion = 0,
    this.answerTextLocked = false,
    this.answerImageLocked = false,
  });

  final String id;
  final String questionId;
  final String userId;
  final String userDisplayName;
  final String answerText;
  /// Object path in private bucket `family_answer_images` (use signed URL in UI).
  final String? imagePath;
  final String createdAt;
  final int answerEncryptionVersion;
  final String? answerCipherPayload;
  final int answerImageEncryptionVersion;
  final bool answerTextLocked;
  final bool answerImageLocked;

  factory CloudDailyAnswer.fromJson(Map<String, dynamic> json) {
    final img = json['image_path'];
    return CloudDailyAnswer(
      id: json['id'].toString(),
      questionId: json['question_id'].toString(),
      userId: json['user_id'].toString(),
      userDisplayName: (json['author_display_name'] ?? json['user_display_name'] ?? 'Member') as String,
      answerText: (json['answer_text'] ?? '') as String,
      imagePath: img == null || (img is String && img.isEmpty) ? null : img as String,
      createdAt: (json['created_at'] ?? '').toString(),
      answerEncryptionVersion: (json['answer_encryption_version'] as num?)?.toInt() ?? 0,
      answerCipherPayload: json['answer_cipher_payload'] as String?,
      answerImageEncryptionVersion: (json['answer_image_encryption_version'] as num?)?.toInt() ?? 0,
    );
  }
}
