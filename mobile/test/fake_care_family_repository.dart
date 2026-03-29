import 'dart:typed_data';

import 'package:family_mobile/supabase/care_family_repository.dart';
import 'package:family_mobile/supabase/cloud_family_birthday_reminder.dart';
import 'package:family_mobile/supabase/cloud_family_status_post.dart';
import 'package:family_mobile/supabase/cloud_family_voice_message.dart';
import 'package:family_mobile/supabase/cloud_medical_card.dart';

/// In-memory stub for widget tests (no Supabase).
class FakeCareFamilyRepository implements CareFamilyRepository {
  int refreshTouchCount = 0;

  @override
  Future<void> touchCarePresence(String familyId) async {
    refreshTouchCount++;
  }

  @override
  Future<List<CloudFamilyStatusPost>> listStatusPosts(String familyId, {int limit = 40}) async => [];

  @override
  Future<void> postQuickStatus({
    required String familyId,
    required String statusCode,
    String? note,
  }) async {}

  @override
  Future<DateTime?> lastStatusPostAt(String familyId) async => null;

  @override
  Future<DateTime?> lastAnswerInFamily(String familyId) async => null;

  @override
  Future<bool> recentFamilyContentHasMoodKeyword(String familyId) async => false;

  @override
  Future<List<CloudFamilyVoiceMessage>> listVoiceMessages(String familyId) async => [];

  @override
  Future<String> signedVoiceUrl(String storagePath) async => 'https://example.com/audio';

  @override
  Future<void> uploadVoiceMessage({
    required String familyId,
    required String title,
    required Uint8List audioBytes,
    required String fileExtension,
    int? durationSeconds,
  }) async {}

  @override
  Future<void> deleteVoiceMessage(String messageId, String storagePath) async {}

  @override
  Future<CloudMedicalCard?> getMedicalCard(String familyId, String userId) async => null;

  @override
  Future<List<CloudMedicalCard>> listMedicalCardsForFamily(String familyId) async => [];

  @override
  Future<void> upsertMyMedicalCard({
    required String familyId,
    required String displayName,
    required String allergies,
    required String medications,
    required String hospitals,
    required String emergencyContactName,
    required String emergencyContactPhone,
    required String accompanimentNote,
  }) async {}

  @override
  Future<List<CloudFamilyBirthdayReminder>> listBirthdayReminders(String familyId) async => [];

  @override
  Future<void> addBirthdayReminder({
    required String familyId,
    required String personName,
    required int month,
    required int day,
    int notifyDaysBefore = 3,
  }) async {}

  @override
  Future<void> deleteBirthdayReminder(String id) async {}

  @override
  Future<({bool gentleRadar, bool sharePresence})> getMyCarePreferences(String familyId) async =>
      (gentleRadar: false, sharePresence: false);

  @override
  Future<void> saveMyCarePreferences({
    required String familyId,
    required bool gentleRadarEnabled,
    required bool shareCarePresence,
  }) async {}

  @override
  Future<Map<String, DateTime>> listCarePresenceForFamily(String familyId) async => {};
}
