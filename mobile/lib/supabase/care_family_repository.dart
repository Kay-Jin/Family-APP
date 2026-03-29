import 'dart:typed_data';

import 'package:family_mobile/supabase/cloud_family_birthday_reminder.dart';
import 'package:family_mobile/supabase/cloud_family_status_post.dart';
import 'package:family_mobile/supabase/cloud_family_voice_message.dart';
import 'package:family_mobile/supabase/cloud_medical_card.dart';

/// Contract for cloud care features (SupabaseFamilyCarePanel + tests).
abstract class CareFamilyRepository {
  Future<void> touchCarePresence(String familyId);

  Future<List<CloudFamilyStatusPost>> listStatusPosts(String familyId, {int limit = 40});

  Future<void> postQuickStatus({
    required String familyId,
    required String statusCode,
    String? note,
  });

  Future<DateTime?> lastStatusPostAt(String familyId);

  Future<DateTime?> lastAnswerInFamily(String familyId);

  Future<bool> recentFamilyContentHasMoodKeyword(String familyId);

  Future<List<CloudFamilyVoiceMessage>> listVoiceMessages(String familyId);

  Future<String> signedVoiceUrl(String storagePath);

  Future<void> uploadVoiceMessage({
    required String familyId,
    required String title,
    required Uint8List audioBytes,
    required String fileExtension,
    int? durationSeconds,
  });

  Future<void> deleteVoiceMessage(String messageId, String storagePath);

  Future<void> updateVoiceTitle(String messageId, String newTitle);

  Future<CloudMedicalCard?> getMedicalCard(String familyId, String userId);

  Future<List<CloudMedicalCard>> listMedicalCardsForFamily(String familyId);

  Future<void> upsertMyMedicalCard({
    required String familyId,
    required String displayName,
    required String allergies,
    required String medications,
    required String hospitals,
    required String emergencyContactName,
    required String emergencyContactPhone,
    required String accompanimentNote,
  });

  Future<List<CloudFamilyBirthdayReminder>> listBirthdayReminders(String familyId);

  Future<void> addBirthdayReminder({
    required String familyId,
    required String personName,
    required int month,
    required int day,
    int notifyDaysBefore = 3,
  });

  Future<void> deleteBirthdayReminder(String id);

  Future<({bool gentleRadar, bool sharePresence})> getMyCarePreferences(String familyId);

  Future<void> saveMyCarePreferences({
    required String familyId,
    required bool gentleRadarEnabled,
    required bool shareCarePresence,
  });

  Future<Map<String, DateTime>> listCarePresenceForFamily(String familyId);
}
