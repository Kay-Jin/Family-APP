class LedgerTransactionRow {
  LedgerTransactionRow({
    required this.id,
    required this.ledgerId,
    required this.amount,
    required this.occurredOn,
    required this.category,
    this.note,
    required this.createdBy,
    required this.createdAt,
  });

  final String id;
  final String ledgerId;
  /// Positive = income, negative = expense (matches DB single numeric column).
  final double amount;
  final String occurredOn;
  final String category;
  final String? note;
  final String createdBy;
  final String createdAt;

  bool get isExpense => amount < 0;
  bool get isIncome => amount > 0;

  factory LedgerTransactionRow.fromJson(Map<String, dynamic> json) {
    final raw = json['amount'];
    double a;
    if (raw is num) {
      a = raw.toDouble();
    } else {
      a = double.tryParse(raw.toString()) ?? 0;
    }
    return LedgerTransactionRow(
      id: json['id'].toString(),
      ledgerId: json['ledger_id'].toString(),
      amount: a,
      occurredOn: (json['occurred_on'] ?? '').toString().split('T').first,
      category: (json['category'] ?? 'other') as String,
      note: json['note'] as String?,
      createdBy: json['created_by'].toString(),
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }
}
