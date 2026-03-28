import 'package:family_mobile/supabase/family_row.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FamilyRepository {
  FamilyRepository({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<FamilyRow>> listFamilies() async {
    final rows = await _client.from('families').select().order('created_at', ascending: false);
    return (rows as List<dynamic>).map((e) => FamilyRow.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<FamilyRow> createFamily({
    required String name,
  }) async {
    final row = await _client.from('families').insert({'name': name}).select().single();
    return FamilyRow.fromJson(Map<String, dynamic>.from(row as Map));
  }

  Future<FamilyRow> updateFamily({
    required String id,
    required String name,
  }) async {
    final row = await _client.from('families').update({'name': name}).eq('id', id).select().single();
    return FamilyRow.fromJson(Map<String, dynamic>.from(row as Map));
  }

  Future<void> deleteFamily(String id) async {
    await _client.from('families').delete().eq('id', id);
  }

  /// Requires SQL function `join_family_by_code` from `supabase/schema.sql`.
  Future<void> joinFamilyByCode(String code) async {
    await _client.rpc('join_family_by_code', params: {'p_code': code.trim()});
  }
}

