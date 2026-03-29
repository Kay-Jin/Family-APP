class FamilyBriefReply {
  FamilyBriefReply({
    required this.id,
    required this.briefId,
    required this.authorUserId,
    required this.authorDisplayName,
    required this.replyKind,
    this.quickText,
    this.audioUrl,
    required this.durationSeconds,
    required this.createdAt,
  });

  final int id;
  final int briefId;
  final int authorUserId;
  final String authorDisplayName;
  final String replyKind;
  final String? quickText;
  final String? audioUrl;
  final int durationSeconds;
  final String createdAt;

  factory FamilyBriefReply.fromJson(Map<String, dynamic> json) {
    return FamilyBriefReply(
      id: json['id'] as int,
      briefId: json['brief_id'] as int,
      authorUserId: json['author_user_id'] as int,
      authorDisplayName: (json['author_display_name'] ?? '') as String,
      replyKind: (json['reply_kind'] ?? 'quick') as String,
      quickText: json['quick_text'] as String?,
      audioUrl: json['audio_url'] as String?,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] as String,
    );
  }
}

class FamilyBrief {
  FamilyBrief({
    required this.id,
    required this.familyId,
    required this.authorUserId,
    required this.authorDisplayName,
    required this.childStatusText,
    this.contactNote,
    required this.questionText,
    required this.createdAt,
    required this.replyStatus,
    this.repliedAt,
    this.reply,
    this.parentsOnly = false,
  });

  final int id;
  final int familyId;
  final int authorUserId;
  final String authorDisplayName;
  final String childStatusText;
  final String? contactNote;
  final String questionText;
  final String createdAt;
  final String replyStatus;
  final String? repliedAt;
  final FamilyBriefReply? reply;
  final bool parentsOnly;

  bool get isPending => replyStatus == 'pending';

  factory FamilyBrief.fromJson(Map<String, dynamic> json) {
    final replyRaw = json['reply'];
    final po = json['parents_only'];
    return FamilyBrief(
      id: json['id'] as int,
      familyId: json['family_id'] as int,
      authorUserId: json['author_user_id'] as int,
      authorDisplayName: (json['author_display_name'] ?? '') as String,
      childStatusText: (json['child_status_text'] ?? '') as String,
      contactNote: json['contact_note'] as String?,
      questionText: (json['question_text'] ?? '') as String,
      createdAt: json['created_at'] as String,
      replyStatus: (json['reply_status'] ?? 'pending') as String,
      repliedAt: json['replied_at'] as String?,
      reply: replyRaw is Map<String, dynamic> ? FamilyBriefReply.fromJson(replyRaw) : null,
      parentsOnly: po == true || po == 1,
    );
  }
}
