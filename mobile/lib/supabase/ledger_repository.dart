import 'package:supabase_flutter/supabase_flutter.dart';

import 'ledger_book_row.dart';
import 'ledger_transaction_row.dart';

class LedgerRepository {
  LedgerRepository({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<LedgerBookRow>> listBooks({
    required String familyId,
    bool includeArchived = false,
  }) async {
    final rows =
        await _client.from('ledger_books').select().eq('family_id', familyId).order('created_at', ascending: false);
    final list =
        (rows as List<dynamic>).map((e) => LedgerBookRow.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    if (includeArchived) return list;
    return list.where((b) => !b.isArchived).toList();
  }

  Future<String?> myRoleForLedger(String ledgerId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    final row = await _client
        .from('ledger_book_members')
        .select('role')
        .eq('ledger_id', ledgerId)
        .eq('user_id', uid)
        .maybeSingle();
    if (row == null) return null;
    return row['role'] as String?;
  }

  Future<LedgerBookRow> createBook({
    required String familyId,
    required String name,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not signed in');
    final row = await _client.from('ledger_books').insert({
      'family_id': familyId,
      'name': name.trim(),
      'created_by': uid,
    }).select().single();
    return LedgerBookRow.fromJson(Map<String, dynamic>.from(row as Map));
  }

  Future<void> setBookArchived({
    required String ledgerId,
    required bool archived,
  }) async {
    await _client.from('ledger_books').update({
      'archived_at': archived ? DateTime.now().toUtc().toIso8601String() : null,
    }).eq('id', ledgerId);
  }

  Future<void> deleteBook(String ledgerId) async {
    await _client.from('ledger_books').delete().eq('id', ledgerId);
  }

  Future<List<LedgerTransactionRow>> listTransactions(String ledgerId) async {
    final rows = await _client
        .from('ledger_transactions')
        .select()
        .eq('ledger_id', ledgerId)
        .order('occurred_on', ascending: false)
        .order('created_at', ascending: false);
    return (rows as List<dynamic>)
        .map((e) => LedgerTransactionRow.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<LedgerTransactionRow> createTransaction({
    required String ledgerId,
    required double signedAmount,
    required String occurredOn,
    required String category,
    String? note,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not signed in');
    final row = await _client.from('ledger_transactions').insert({
      'ledger_id': ledgerId,
      'amount': signedAmount,
      'occurred_on': occurredOn,
      'category': category,
      'created_by': uid,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    }).select().single();
    return LedgerTransactionRow.fromJson(Map<String, dynamic>.from(row as Map));
  }

  Future<void> deleteTransaction(String transactionId) async {
    await _client.from('ledger_transactions').delete().eq('id', transactionId);
  }

  /// Current user must be owner; [viewerUserId] must be in same family (enforced by RLS).
  Future<void> addViewer({
    required String ledgerId,
    required String viewerUserId,
  }) async {
    await _client.from('ledger_book_members').insert({
      'ledger_id': ledgerId,
      'user_id': viewerUserId,
      'role': 'viewer',
      'granted_by': _client.auth.currentUser?.id,
    });
  }
}
