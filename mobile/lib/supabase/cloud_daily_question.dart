class CloudDailyQuestion {
  CloudDailyQuestion({
    required this.id,
    required this.familyId,
    required this.questionDate,
    required this.questionText,
  });

  final String id;
  final String familyId;
  final String questionDate;
  final String questionText;

  factory CloudDailyQuestion.fromJson(Map<String, dynamic> json) {
    return CloudDailyQuestion(
      id: json['id'].toString(),
      familyId: json['family_id'].toString(),
      questionDate: (json['question_date'] ?? '').toString(),
      questionText: (json['question_text'] ?? '') as String,
    );
  }
}
