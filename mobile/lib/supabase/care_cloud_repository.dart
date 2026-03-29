import 'dart:typed_data';

import 'package:family_mobile/care/quick_status_code.dart';
import 'package:family_mobile/supabase/cloud_family_birthday_reminder.dart';
import 'package:family_mobile/supabase/cloud_family_status_post.dart';
import 'package:family_mobile/supabase/cloud_family_voice_message.dart';
import 'package:family_mobile/supabase/cloud_medical_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CareCloudRepository {
  CareCloudRepository({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  static const _voiceBucket = 'family_voice_messages';
  static const signedVoiceUrlExpirySeconds = 3600;

  String _displayNameForCurrentUser() {
    final user = _client.auth.currentUser;
    if (user == null) return 'Member';
    final metaName = user.userMetadata?['name'] ?? user.userMetadata?['full_name'];
    if (metaName is String && metaName.isNotEmpty) return metaName;
    if (user.email != null && user.email!.isNotEmpty) return user.email!.split('@').first;
    return 'Member';
  }

  Future<List<CloudFamilyStatusPost>> listStatusPosts(String familyId, {int limit = 40}) async {
    final rows = await _client
        .from('family_status_posts')
        .select()
        .eq('family_id', familyId)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List<dynamic>)
        .map((e) => CloudFamilyStatusPost.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> postQuickStatus({
    required String familyId,
    required String statusCode,
    String? note,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('error_not_signed_in');
    if (!QuickStatusCode.isValid(statusCode)) throw Exception('error_generic');
    await _client.from('family_status_posts').insert({
      'family_id': familyId,
      'user_id': user.id,
      'author_display_name': _displayNameForCurrentUser(),
      'status_code': statusCode,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
  }

  Future<DateTime?> lastStatusPostAt(String familyId) async {
    final rows = await _client
        .from('family_status_posts')
        .select('created_at')
        .eq('family_id', familyId)
        .order('created_at', ascending: false)
        .limit(1);
    final list = rows as List<dynamic>;
    if (list.isEmpty) return null;
    final ts = (list.first as Map)['created_at'] as String?;
    if (ts == null) return null;
    return DateTime.tryParse(ts);
  }

  Future<DateTime?> lastAnswerInFamily(String familyId) async {
    final qrows = await _client.from('daily_questions').select('id').eq('family_id', familyId);
    final ids = (qrows as List<dynamic>).map((e) => (e as Map)['id'] as String).toList();
    return _lastAnswerWithQuestionIds(ids);
  }

  Future<DateTime?> _lastAnswerWithQuestionIds(List<String> questionIds) async {
    if (questionIds.isEmpty) return null;
    final arows = await _client
        .from('daily_answers')
        .select('created_at')
        .inFilter('question_id', questionIds)
        .order('created_at', ascending: false)
        .limit(1);
    final list = arows as List<dynamic>;
    if (list.isEmpty) return null;
    final ts = (list.first as Map)['created_at'] as String?;
    if (ts == null) return null;
    return DateTime.tryParse(ts);
  }

  Future<bool> recentFamilyContentHasMoodKeyword(String familyId) async {
    final posts = await _client
        .from('family_status_posts')
        .select('note')
        .eq('family_id', familyId)
        .order('created_at', ascending: false)
        .limit(20);
    for (final row in posts as List<dynamic>) {
      final n = (row as Map)['note'] as String?;
      if (n != null && _rawHasMoodKeyword(n)) return true;
    }
    final qrows = await _client.from('daily_questions').select('id').eq('family_id', familyId);
    final ids = (qrows as List<dynamic>).map((e) => (e as Map)['id'] as String).toList();
    if (ids.isEmpty) return false;
    final answers = await _client
        .from('daily_answers')
        .select('answer_text')
        .inFilter('question_id', ids)
        .order('created_at', ascending: false)
        .limit(30);
    for (final row in answers as List<dynamic>) {
      final t = (row as Map)['answer_text'] as String?;
      if (t != null && _rawHasMoodKeyword(t)) return true;
    }
    return false;
  }

  bool _rawHasMoodKeyword(String text) {
    const keys = ['情绪低落', '难受', '想哭', '好累', '睡不着', '不想活了'];
    for (final k in keys) {
      if (text.contains(k)) return true;
    }
    return false;
  }

  Future<List<CloudFamilyVoiceMessage>> listVoiceMessages(String familyId) async {
    final rows = await _client
        .from('family_voice_messages')
        .select()
        .eq('family_id', familyId)
        .order('created_at', ascending: false);
    return (rows as List<dynamic>)
        .map((e) => CloudFamilyVoiceMessage.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<String> signedVoiceUrl(String storagePath) async {
    return _client.storage.from(_voiceBucket).createSignedUrl(storagePath, signedVoiceUrlExpirySeconds);
  }

  Future<void> uploadVoiceMessage({
    required String familyId,
    required String title,
    required Uint8List audioBytes,
    required String fileExtension,
    int? durationSeconds,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('error_not_signed_in');
    final ext = fileExtension.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final safeExt = ext.isEmpty ? 'm4a' : ext;
    final path = '$familyId/${user.id}/${DateTime.now().millisecondsSinceEpoch}.$safeExt';
    await _client.storage.from(_voiceBucket).uploadBinary(
          path,
          audioBytes,
          fileOptions: FileOptions(
            contentType: safeExt == 'm4a' || safeExt == 'mp4' ? 'audio/mp4' : 'audio/mpeg',
            upsert: false,
          ),
        );
    await _client.from('family_voice_messages').insert({
      'family_id': familyId,
      'user_id': user.id,
      'author_display_name': _displayNameForCurrentUser(),
      'title': title.trim(),
      'storage_path': path,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
    });
  }

  Future<void> deleteVoiceMessage(String messageId, String storagePath) async {
    await _client.storage.from(_voiceBucket).remove([storagePath]);
    await _client.from('family_voice_messages').delete().eq('id', messageId);
  }

  Future<void> updateVoiceTitle(String messageId, String newTitle) async {
    await _client.from('family_voice_messages').update({'title': newTitle.trim()}).eq('id', messageId);
  }

  Future<CloudMedicalCard?> getMedicalCard(String familyId, String userId) async {
    final row = await _client
        .from('family_medical_cards')
        .select()
        .eq('family_id', familyId)
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return null;
    return CloudMedicalCard.fromJson(Map<String, dynamic>.from(row as Map));
  }

  Future<List<CloudMedicalCard>> listMedicalCardsForFamily(String familyId) async {
    final rows = await _client.from('family_medical_cards').select().eq('family_id', familyId);
    return (rows as List<dynamic>)
        .map((e) => CloudMedicalCard.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> upsertMyMedicalCard({
    required String familyId,
    required String displayName,
    required String allergies,
    required String medications,
    required String hospitals,
    required String emergencyContactName,
    required String emergencyContactPhone,
    required String accompanimentNote,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('error_not_signed_in');
    String? nz(String s) {
      final t = s.trim();
      return t.isEmpty ? null : t;
    }
    await _client.from('family_medical_cards').upsert({
      'family_id': familyId,
      'user_id': user.id,
      'display_name': nz(displayName),
      'allergies': nz(allergies),
      'medications': nz(medications),
      'hospitals': nz(hospitals),
      'emergency_contact_name': nz(emergencyContactName),
      'emergency_contact_phone': nz(emergencyContactPhone),
      'accompaniment_note': nz(accompanimentNote),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<List<CloudFamilyBirthdayReminder>> listBirthdayReminders(String familyId) async {
    final rows = await _client.from('family_birthday_reminders').select().eq('family_id', familyId);
    return (rows as List<dynamic>)
        .map((e) => CloudFamilyBirthdayReminder.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> addBirthdayReminder({
    required String familyId,
    required String personName,
    required int month,
    required int day,
    int notifyDaysBefore = 3,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('error_not_signed_in');
    await _client.from('family_birthday_reminders').insert({
      'family_id': familyId,
      'created_by': user.id,
      'person_name': personName.trim(),
      'month': month,
      'day': day,
      'notify_days_before': notifyDaysBefore,
    });
  }

  Future<void> deleteBirthdayReminder(String id) async {
    await _client.from('family_birthday_reminders').delete().eq('id', id);
  }

  Future<({bool gentleRadar, bool sharePresence})> getMyCarePreferences(String familyId) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('error_not_signed_in');
    final row = await _client
        .from('family_care_preferences')
        .select()
        .eq('family_id', familyId)
        .eq('user_id', user.id)
        .maybeSingle();
    if (row == null) return (gentleRadar: false, sharePresence: false);
    final m = Map<String, dynamic>.from(row as Map);
    return (
      gentleRadar: m['gentle_radar_enabled'] as bool? ?? false,
      sharePresence: m['share_care_presence'] as bool? ?? false,
    );
  }

  Future<void> saveMyCarePreferences({
    required String familyId,
    required bool gentleRadarEnabled,
    required bool shareCarePresence,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('error_not_signed_in');
    await _client.from('family_care_preferences').upsert({
      'user_id': user.id,
      'family_id': familyId,
      'gentle_radar_enabled': gentleRadarEnabled,
      'share_care_presence': shareCarePresence,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
    if (shareCarePresence) {
      await touchCarePresence(familyId);
    } else {
      await _client.from('family_care_presence').delete().eq('family_id', familyId).eq('user_id', user.id);
    }
  }

  Future<void> touchCarePresence(String familyId) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('error_not_signed_in');
    final prefs = await getMyCarePreferences(familyId);
    if (!prefs.sharePresence) return;
    final now = DateTime.now().toUtc().toIso8601String();
    await _client.from('family_care_presence').upsert({
      'family_id': familyId,
      'user_id': user.id,
      'last_care_tab_at': now,
    });
  }

  Future<Map<String, DateTime>> listCarePresenceForFamily(String familyId) async {
    final rows = await _client.from('family_care_presence').select('user_id, last_care_tab_at').eq('family_id', familyId);
    final out = <String, DateTime>{};
    for (final row in rows as List<dynamic>) {
      final m = row as Map;
      final uid = m['user_id'] as String;
      final ts = m['last_care_tab_at'] as String?;
      if (ts != null) {
        final d = DateTime.tryParse(ts);
        if (d != null) out[uid] = d;
      }
    }
    return out;
  }
}
