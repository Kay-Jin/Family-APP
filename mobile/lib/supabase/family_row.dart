class FamilyRow {
  FamilyRow({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String inviteCode;
  final DateTime createdAt;

  factory FamilyRow.fromJson(Map<String, dynamic> json) {
    return FamilyRow(
      id: json['id'].toString(),
      name: (json['name'] ?? '') as String,
      inviteCode: (json['invite_code'] ?? '') as String,
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

