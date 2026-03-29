class CloudAlbumComment {
  CloudAlbumComment({
    required this.id,
    required this.photoId,
    required this.userId,
    required this.body,
    required this.authorDisplayName,
    required this.createdAt,
  });

  final String id;
  final String photoId;
  final String userId;
  final String body;
  final String authorDisplayName;
  final String createdAt;

  factory CloudAlbumComment.fromJson(Map<String, dynamic> json) {
    return CloudAlbumComment(
      id: json['id'].toString(),
      photoId: json['photo_id'].toString(),
      userId: json['user_id'].toString(),
      body: (json['body'] ?? '') as String,
      authorDisplayName: (json['author_display_name'] ?? 'Member') as String,
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }
}
