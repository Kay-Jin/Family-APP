class LedgerBookRow {
  LedgerBookRow({
    required this.id,
    required this.familyId,
    required this.name,
    required this.createdBy,
    this.currency = 'CNY',
    this.archivedAt,
    required this.createdAt,
  });

  final String id;
  final String familyId;
  final String name;
  final String createdBy;
  final String currency;
  final String? archivedAt;
  final String createdAt;

  bool get isArchived => archivedAt != null && archivedAt!.isNotEmpty;

  factory LedgerBookRow.fromJson(Map<String, dynamic> json) {
    return LedgerBookRow(
      id: json['id'].toString(),
      familyId: json['family_id'].toString(),
      name: (json['name'] ?? '') as String,
      createdBy: json['created_by'].toString(),
      currency: (json['currency'] ?? 'CNY') as String,
      archivedAt: json['archived_at'] as String?,
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }
}
