class ActivityItem {
  ActivityItem({
    required this.activityType,
    required this.activityId,
    required this.actorName,
    required this.content,
    required this.createdAt,
    this.briefId,
  });

  final String activityType;
  final int activityId;
  final String actorName;
  final String content;
  final String createdAt;
  /// Set for [family_brief] and [family_brief_reply] timeline rows.
  final int? briefId;

  factory ActivityItem.fromJson(Map<String, dynamic> json) {
    final rawBrief = json['brief_id'];
    return ActivityItem(
      activityType: json['activity_type'] as String,
      activityId: json['activity_id'] as int,
      actorName: (json['actor_name'] ?? 'Unknown') as String,
      content: (json['content'] ?? '') as String,
      createdAt: json['created_at'] as String,
      briefId: rawBrief is int ? rawBrief : int.tryParse('$rawBrief'),
    );
  }
}
