class DailyAnswer {
  DailyAnswer({
    required this.id,
    required this.questionId,
    required this.userId,
    required this.userDisplayName,
    required this.answerText,
    required this.createdAt,
  });

  final int id;
  final int questionId;
  final int userId;
  final String userDisplayName;
  final String answerText;
  final String createdAt;

  factory DailyAnswer.fromJson(Map<String, dynamic> json) {
    return DailyAnswer(
      id: json['id'] as int,
      questionId: json['question_id'] as int,
      userId: json['user_id'] as int,
      userDisplayName: (json['user_display_name'] ?? 'Unknown') as String,
      answerText: json['answer_text'] as String,
      createdAt: json['created_at'] as String,
    );
  }
}
