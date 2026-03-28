class CloudDailyAnswer {
  CloudDailyAnswer({
    required this.id,
    required this.questionId,
    required this.userId,
    required this.userDisplayName,
    required this.answerText,
    required this.createdAt,
  });

  final String id;
  final String questionId;
  final String userId;
  final String userDisplayName;
  final String answerText;
  final String createdAt;

  factory CloudDailyAnswer.fromJson(Map<String, dynamic> json) {
    return CloudDailyAnswer(
      id: json['id'].toString(),
      questionId: json['question_id'].toString(),
      userId: json['user_id'].toString(),
      userDisplayName: (json['author_display_name'] ?? json['user_display_name'] ?? 'Member') as String,
      answerText: (json['answer_text'] ?? '') as String,
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }
}
