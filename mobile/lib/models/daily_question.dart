class DailyQuestion {
  DailyQuestion({
    required this.id,
    required this.familyId,
    required this.questionDate,
    required this.questionText,
  });

  final int id;
  final int familyId;
  final String questionDate;
  final String questionText;

  factory DailyQuestion.fromJson(Map<String, dynamic> json) {
    return DailyQuestion(
      id: json['id'] as int,
      familyId: json['family_id'] as int,
      questionDate: json['question_date'] as String,
      questionText: json['question_text'] as String,
    );
  }
}
