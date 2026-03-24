class VoiceMessage {
  VoiceMessage({
    required this.id,
    required this.familyId,
    required this.senderUserId,
    required this.senderDisplayName,
    required this.title,
    required this.audioUrl,
    required this.durationSeconds,
    required this.createdAt,
  });

  final int id;
  final int familyId;
  final int senderUserId;
  final String senderDisplayName;
  final String title;
  final String audioUrl;
  final int durationSeconds;
  final String createdAt;

  factory VoiceMessage.fromJson(Map<String, dynamic> json) {
    return VoiceMessage(
      id: json['id'] as int,
      familyId: json['family_id'] as int,
      senderUserId: json['sender_user_id'] as int,
      senderDisplayName: (json['sender_display_name'] ?? 'Unknown') as String,
      title: json['title'] as String,
      audioUrl: json['audio_url'] as String,
      durationSeconds: (json['duration_seconds'] ?? 0) as int,
      createdAt: json['created_at'] as String,
    );
  }
}
