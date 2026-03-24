class CareReminder {
  CareReminder({
    required this.type,
    required this.title,
    required this.message,
    required this.severity,
  });

  final String type;
  final String title;
  final String message;
  final String severity;

  factory CareReminder.fromJson(Map<String, dynamic> json) {
    return CareReminder(
      type: json['type'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      severity: (json['severity'] ?? 'low') as String,
    );
  }
}
