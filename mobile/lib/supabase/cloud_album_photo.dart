class CloudAlbumPhoto {
  CloudAlbumPhoto({
    required this.id,
    required this.familyId,
    required this.userId,
    required this.caption,
    required this.imagePath,
    required this.uploaderDisplayName,
    required this.createdAt,
    this.likeCount = 0,
    this.commentCount = 0,
  });

  final String id;
  final String familyId;
  final String userId;
  final String caption;
  /// Object path in private bucket `family_album_images` (load via signed URL, not public URL).
  final String imagePath;
  final String uploaderDisplayName;
  final String createdAt;
  final int likeCount;
  final int commentCount;

  static int _parseCount(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  factory CloudAlbumPhoto.fromJson(Map<String, dynamic> json) {
    return CloudAlbumPhoto(
      id: json['id'].toString(),
      familyId: json['family_id'].toString(),
      userId: json['user_id'].toString(),
      caption: (json['caption'] ?? '') as String,
      imagePath: (json['image_path'] ?? '') as String,
      uploaderDisplayName: (json['uploader_display_name'] ?? 'Member') as String,
      createdAt: (json['created_at'] ?? '').toString(),
      likeCount: _parseCount(json['like_count']),
      commentCount: _parseCount(json['comment_count']),
    );
  }
}
