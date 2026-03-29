class CloudAlbumPhoto {
  CloudAlbumPhoto({
    required this.id,
    required this.familyId,
    required this.userId,
    required this.caption,
    required this.imagePath,
    required this.uploaderDisplayName,
    required this.createdAt,
  });

  final String id;
  final String familyId;
  final String userId;
  final String caption;
  /// Storage object path in bucket `family_album_images`.
  final String imagePath;
  final String uploaderDisplayName;
  final String createdAt;

  factory CloudAlbumPhoto.fromJson(Map<String, dynamic> json) {
    return CloudAlbumPhoto(
      id: json['id'].toString(),
      familyId: json['family_id'].toString(),
      userId: json['user_id'].toString(),
      caption: (json['caption'] ?? '') as String,
      imagePath: (json['image_path'] ?? '') as String,
      uploaderDisplayName: (json['uploader_display_name'] ?? 'Member') as String,
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }
}
