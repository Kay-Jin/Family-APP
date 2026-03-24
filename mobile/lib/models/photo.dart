class Photo {
  Photo({
    required this.id,
    required this.familyId,
    required this.uploaderUserId,
    required this.imageUrl,
    required this.caption,
  });

  final int id;
  final int familyId;
  final int uploaderUserId;
  final String imageUrl;
  final String caption;

  factory Photo.fromJson(Map<String, dynamic> json) {
    return Photo(
      id: json['id'] as int,
      familyId: json['family_id'] as int,
      uploaderUserId: json['uploader_user_id'] as int,
      imageUrl: json['image_url'] as String,
      caption: (json['caption'] ?? '') as String,
    );
  }
}
