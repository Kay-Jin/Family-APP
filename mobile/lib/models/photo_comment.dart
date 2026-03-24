class PhotoComment {
  PhotoComment({
    required this.id,
    required this.photoId,
    required this.userId,
    required this.userDisplayName,
    required this.content,
    required this.createdAt,
  });

  final int id;
  final int photoId;
  final int userId;
  final String userDisplayName;
  final String content;
  final String createdAt;

  factory PhotoComment.fromJson(Map<String, dynamic> json) {
    return PhotoComment(
      id: json['id'] as int,
      photoId: json['photo_id'] as int,
      userId: json['user_id'] as int,
      userDisplayName: (json['user_display_name'] ?? 'Unknown') as String,
      content: json['content'] as String,
      createdAt: json['created_at'] as String,
    );
  }
}
