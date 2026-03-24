class Photo {
  Photo({
    required this.id,
    required this.familyId,
    required this.uploaderUserId,
    required this.imageUrl,
    required this.caption,
    required this.likeCount,
    required this.commentCount,
    required this.hasLiked,
  });

  final int id;
  final int familyId;
  final int uploaderUserId;
  final String imageUrl;
  final String caption;
  final int likeCount;
  final int commentCount;
  final bool hasLiked;

  factory Photo.fromJson(Map<String, dynamic> json) {
    return Photo(
      id: json['id'] as int,
      familyId: json['family_id'] as int,
      uploaderUserId: json['uploader_user_id'] as int,
      imageUrl: json['image_url'] as String,
      caption: (json['caption'] ?? '') as String,
      likeCount: (json['like_count'] ?? 0) as int,
      commentCount: (json['comment_count'] ?? 0) as int,
      hasLiked: ((json['has_liked'] ?? 0) as int) == 1,
    );
  }
}
