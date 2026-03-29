import 'dart:convert';

import 'package:family_mobile/models/daily_question.dart';
import 'package:family_mobile/models/daily_answer.dart';
import 'package:family_mobile/models/activity_item.dart';
import 'package:family_mobile/models/family.dart';
import 'package:family_mobile/models/photo.dart';
import 'package:family_mobile/models/birthday_reminder.dart';
import 'package:family_mobile/models/photo_comment.dart';
import 'package:family_mobile/models/status_update.dart';
import 'package:family_mobile/models/voice_message.dart';
import 'package:family_mobile/models/emergency_contact.dart';
import 'package:family_mobile/models/care_reminder.dart';
import 'package:family_mobile/models/family_task.dart';
import 'package:family_mobile/models/family_brief.dart';
import 'package:family_mobile/models/medical_card.dart';
import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient({required this.baseUrl});

  final String baseUrl;

  Future<Map<String, dynamic>> loginWithMockWechat({
    required String code,
    required String displayName,
  }) async {
    final uri = Uri.parse('$baseUrl/auth/wechat-login');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'code': code, 'display_name': displayName}),
    );
    _ensureSuccess(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// WeChat SDK `code` → Supabase session (backend must run; see `/auth/wechat-supabase`).
  /// Use code `demo_wechat` when WeChat app credentials are not configured.
  Future<Map<String, dynamic>> loginWechatSupabase({required String code}) async {
    final uri = Uri.parse('$baseUrl/auth/wechat-supabase');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'code': code}),
    );
    _ensureSuccess(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Links this Flask user to [supabaseUserId] (`auth.users.id`) for server-triggered FCM to other family members.
  Future<void> patchMeSupabaseUserId({
    required String token,
    required String supabaseUserId,
  }) async {
    final uri = Uri.parse('$baseUrl/users/me');
    final response = await http.patch(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode({'supabase_user_id': supabaseUserId}),
    );
    _ensureSuccess(response);
  }

  Future<Family> createFamily({
    required String token,
    required String familyName,
  }) async {
    final uri = Uri.parse('$baseUrl/families');
    final response = await http.post(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode({'name': familyName}),
    );
    _ensureSuccess(response);
    return Family.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<Family> joinFamily({
    required String token,
    required String inviteCode,
  }) async {
    final uri = Uri.parse('$baseUrl/families/join');
    final response = await http.post(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode({'invite_code': inviteCode}),
    );
    _ensureSuccess(response);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final familyJson = data['family'] as Map<String, dynamic>;
    return Family.fromJson(familyJson);
  }

  Future<Family> getFamily({
    required String token,
    required int familyId,
  }) async {
    final uri = Uri.parse('$baseUrl/families/$familyId');
    final response = await http.get(uri, headers: _authHeaders(token));
    _ensureSuccess(response);
    return Family.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> patchMyFamilyMemberRole({
    required String token,
    required int familyId,
    required String role,
  }) async {
    final uri = Uri.parse('$baseUrl/families/$familyId/members/me');
    final response = await http.patch(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode({'role': role}),
    );
    _ensureSuccess(response);
  }

  Future<void> createDailyQuestion({
    required String token,
    required int familyId,
    required String questionDate,
    required String questionText,
  }) async {
    final uri = Uri.parse('$baseUrl/daily-questions');
    final response = await http.post(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode({
        'family_id': familyId,
        'question_date': questionDate,
        'question_text': questionText,
      }),
    );
    _ensureSuccess(response);
  }

  Future<void> createDailyAnswer({
    required String token,
    required int questionId,
    required String answerText,
  }) async {
    final uri = Uri.parse('$baseUrl/daily-answers');
    final response = await http.post(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode({
        'question_id': questionId,
        'answer_text': answerText,
      }),
    );
    _ensureSuccess(response);
  }

  Future<List<DailyAnswer>> getDailyAnswers({
    required String token,
    required int questionId,
  }) async {
    final uri = Uri.parse('$baseUrl/daily-questions/$questionId/answers');
    final response = await http.get(uri, headers: _authHeaders(token));
    _ensureSuccess(response);
    final data = jsonDecode(response.body) as List<dynamic>;
    return data.map((e) => DailyAnswer.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> createPhoto({
    required String token,
    required int familyId,
    required String imageUrl,
    required String caption,
  }) async {
    final uri = Uri.parse('$baseUrl/photos');
    final response = await http.post(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode({
        'family_id': familyId,
        'image_url': imageUrl,
        'caption': caption,
      }),
    );
    _ensureSuccess(response);
  }

  Future<void> uploadPhoto({
    required String token,
    required int familyId,
    required String filePath,
    required String caption,
  }) async {
    final uri = Uri.parse('$baseUrl/photos/upload');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll({'Authorization': 'Bearer $token'});
    request.fields['family_id'] = '$familyId';
    request.fields['caption'] = caption;
    request.files.add(await http.MultipartFile.fromPath('file', filePath));
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    _ensureSuccess(response);
  }

  Future<void> createBirthdayReminder({
    required String token,
    required int familyId,
    required String birthday,
    required int notifyDaysBefore,
  }) async {
    final uri = Uri.parse('$baseUrl/birthday-reminders');
    final response = await http.post(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode({
        'family_id': familyId,
        'birthday': birthday,
        'notify_days_before': notifyDaysBefore,
      }),
    );
    _ensureSuccess(response);
  }

  Future<List<BirthdayReminder>> getBirthdayReminders({
    required String token,
    required int familyId,
  }) async {
    final uri = Uri.parse('$baseUrl/families/$familyId/birthday-reminders');
    final response = await http.get(uri, headers: _authHeaders(token));
    _ensureSuccess(response);
    final data = jsonDecode(response.body) as List<dynamic>;
    return data.map((e) => BirthdayReminder.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> updateBirthdayReminder({
    required String token,
    required int reminderId,
    required String birthday,
    required int notifyDaysBefore,
    required bool enabled,
  }) async {
    final uri = Uri.parse('$baseUrl/birthday-reminders/$reminderId');
    final response = await http.patch(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode({
        'birthday': birthday,
        'notify_days_before': notifyDaysBefore,
        'enabled': enabled,
      }),
    );
    _ensureSuccess(response);
  }

  Future<void> deleteBirthdayReminder({
    required String token,
    required int reminderId,
  }) async {
    final uri = Uri.parse('$baseUrl/birthday-reminders/$reminderId');
    final response = await http.delete(uri, headers: _authHeaders(token));
    _ensureSuccess(response);
  }

  Future<void> createStatusUpdate({
    required String token,
    required int familyId,
    required String statusCode,
    required String note,
  }) async {
    final uri = Uri.parse('$baseUrl/families/$familyId/status-updates');
    final response = await http.post(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode({'status_code': statusCode, 'note': note}),
    );
    _ensureSuccess(response);
  }

  Future<List<StatusUpdate>> getStatusUpdates({
    required String token,
    required int familyId,
  }) async {
    final uri = Uri.parse('$baseUrl/families/$familyId/status-updates');
    final response = await http.get(uri, headers: _authHeaders(token));
    _ensureSuccess(response);
    final data = jsonDecode(response.body) as List<dynamic>;
    return data.map((e) => StatusUpdate.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> createVoiceMessage({
    required String token,
    required int familyId,
    required String title,
    required String audioUrl,
    required int durationSeconds,
  }) async {
    final uri = Uri.parse('$baseUrl/families/$familyId/voice-messages');
    final response = await http.post(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode({
        'title': title,
        'audio_url': audioUrl,
        'duration_seconds': durationSeconds,
      }),
    );
    _ensureSuccess(response);
  }

  Future<void> uploadVoiceMessage({
    required String token,
    required int familyId,
    required String title,
    required String filePath,
    required int durationSeconds,
  }) async {
    final uri = Uri.parse('$baseUrl/families/$familyId/voice-messages/upload');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll({'Authorization': 'Bearer $token'});
    request.fields['title'] = title;
    request.fields['duration_seconds'] = '$durationSeconds';
    request.files.add(await http.MultipartFile.fromPath('file', filePath));
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    _ensureSuccess(response);
  }

  Future<List<VoiceMessage>> getVoiceMessages({
    required String token,
    required int familyId,
  }) async {
    final uri = Uri.parse('$baseUrl/families/$familyId/voice-messages');
    final response = await http.get(uri, headers: _authHeaders(token));
    _ensureSuccess(response);
    final data = jsonDecode(response.body) as List<dynamic>;
    return data.map((e) {
      final json = Map<String, dynamic>.from(e as Map<String, dynamic>);
      json['audio_url'] = _resolveImageUrl(json['audio_url'] as String);
      return VoiceMessage.fromJson(json);
    }).toList();
  }

  Future<void> updateVoiceMessageTitle({
    required String token,
    required int messageId,
    required String title,
  }) async {
    final uri = Uri.parse('$baseUrl/voice-messages/$messageId');
    final response = await http.patch(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode({'title': title}),
    );
    _ensureSuccess(response);
  }

  Future<void> deleteVoiceMessage({
    required String token,
    required int messageId,
  }) async {
    final uri = Uri.parse('$baseUrl/voice-messages/$messageId');
    final response = await http.delete(uri, headers: _authHeaders(token));
    _ensureSuccess(response);
  }

  Future<void> createEmergencyContact({
    required String token,
    required int familyId,
    required String contactName,
    required String relation,
    required String phone,
    required String city,
    required String medicalNotes,
    required bool isPrimary,
  }) async {
    final uri = Uri.parse('$baseUrl/families/$familyId/emergency-contacts');
    final response = await http.post(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode({
        'contact_name': contactName,
        'relation': relation,
        'phone': phone,
        'city': city,
        'medical_notes': medicalNotes,
        'is_primary': isPrimary,
      }),
    );
    _ensureSuccess(response);
  }

  Future<List<EmergencyContact>> getEmergencyContacts({
    required String token,
    required int familyId,
  }) async {
    final uri = Uri.parse('$baseUrl/families/$familyId/emergency-contacts');
    final response = await http.get(uri, headers: _authHeaders(token));
    _ensureSuccess(response);
    final data = jsonDecode(response.body) as List<dynamic>;
    return data.map((e) => EmergencyContact.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> updateEmergencyContact({
    required String token,
    required int contactId,
    required String contactName,
    required String relation,
    required String phone,
    required String city,
    required String medicalNotes,
    required bool isPrimary,
  }) async {
    final uri = Uri.parse('$baseUrl/emergency-contacts/$contactId');
    final response = await http.patch(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode({
        'contact_name': contactName,
        'relation': relation,
        'phone': phone,
        'city': city,
        'medical_notes': medicalNotes,
        'is_primary': isPrimary,
      }),
    );
    _ensureSuccess(response);
  }

  Future<void> deleteEmergencyContact({
    required String token,
    required int contactId,
  }) async {
    final uri = Uri.parse('$baseUrl/emergency-contacts/$contactId');
    final response = await http.delete(uri, headers: _authHeaders(token));
    _ensureSuccess(response);
  }

  Future<List<CareReminder>> getCareReminders({
    required String token,
    required int familyId,
  }) async {
    final uri = Uri.parse('$baseUrl/families/$familyId/care-reminders');
    final response = await http.get(uri, headers: _authHeaders(token));
    _ensureSuccess(response);
    final data = jsonDecode(response.body) as List<dynamic>;
    return data.map((e) => CareReminder.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<MedicalCard> getMedicalCard({
    required String token,
    required int familyId,
  }) async {
    final uri = Uri.parse('$baseUrl/families/$familyId/medical-card');
    final response = await http.get(uri, headers: _authHeaders(token));
    _ensureSuccess(response);
    return MedicalCard.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> upsertMedicalCard({
    required String token,
    required int familyId,
    required String allergies,
    required String medications,
    required String hospitals,
    required String otherNotes,
    required bool accompanimentRequested,
    required String accompanimentNote,
  }) async {
    final uri = Uri.parse('$baseUrl/families/$familyId/medical-card');
    final response = await http.put(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode({
        'allergies': allergies,
        'medications': medications,
        'hospitals': hospitals,
        'other_notes': otherNotes,
        'accompaniment_requested': accompanimentRequested,
        'accompaniment_note': accompanimentNote,
      }),
    );
    _ensureSuccess(response);
  }

  Future<List<DailyQuestion>> getDailyQuestions({
    required String token,
    required int familyId,
  }) async {
    final uri = Uri.parse('$baseUrl/families/$familyId/daily-questions');
    final response = await http.get(uri, headers: _authHeaders(token));
    _ensureSuccess(response);
    final data = jsonDecode(response.body) as List<dynamic>;
    return data.map((e) => DailyQuestion.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<FamilyTask>> getFamilyTasks({
    required String token,
    required int familyId,
  }) async {
    final uri = Uri.parse('$baseUrl/families/$familyId/family-tasks');
    final response = await http.get(uri, headers: _authHeaders(token));
    _ensureSuccess(response);
    final data = jsonDecode(response.body) as List<dynamic>;
    return data.map((e) => FamilyTask.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<FamilyTask> createFamilyTask({
    required String token,
    required int familyId,
    required String title,
    String? assigneeLabel,
    String? dueDate,
  }) async {
    final uri = Uri.parse('$baseUrl/family-tasks');
    final body = <String, dynamic>{
      'family_id': familyId,
      'title': title,
      if (assigneeLabel != null && assigneeLabel.isNotEmpty) 'assignee_label': assigneeLabel,
      if (dueDate != null && dueDate.isNotEmpty) 'due_date': dueDate,
    };
    final response = await http.post(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode(body),
    );
    _ensureSuccess(response);
    return FamilyTask.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<FamilyTask> updateFamilyTask({
    required String token,
    required int taskId,
    required Map<String, dynamic> fields,
  }) async {
    if (fields.isEmpty) {
      throw Exception('no_task_update_fields');
    }
    final uri = Uri.parse('$baseUrl/family-tasks/$taskId');
    final response = await http.patch(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode(fields),
    );
    _ensureSuccess(response);
    return FamilyTask.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteFamilyTask({
    required String token,
    required int taskId,
  }) async {
    final uri = Uri.parse('$baseUrl/family-tasks/$taskId');
    final response = await http.delete(uri, headers: _authHeaders(token));
    _ensureSuccess(response);
  }

  Future<List<ActivityItem>> getActivities({
    required String token,
    required int familyId,
  }) async {
    final uri = Uri.parse('$baseUrl/families/$familyId/activities');
    final response = await http.get(uri, headers: _authHeaders(token));
    _ensureSuccess(response);
    final data = jsonDecode(response.body) as List<dynamic>;
    return data.map((e) => ActivityItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  FamilyBrief _familyBriefFromJson(Map<String, dynamic> raw) {
    final m = Map<String, dynamic>.from(raw);
    final reply = m['reply'];
    if (reply is Map) {
      final r = Map<String, dynamic>.from(reply);
      final au = r['audio_url'];
      if (au is String && au.isNotEmpty) {
        r['audio_url'] = _resolveImageUrl(au);
      }
      m['reply'] = r;
    }
    return FamilyBrief.fromJson(m);
  }

  Future<List<FamilyBrief>> listFamilyBriefs({
    required String token,
    required int familyId,
  }) async {
    final uri = Uri.parse('$baseUrl/families/$familyId/family-briefs');
    final response = await http.get(uri, headers: _authHeaders(token));
    _ensureSuccess(response);
    final data = jsonDecode(response.body) as List<dynamic>;
    return data.map((e) => _familyBriefFromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<FamilyBrief?> getPendingFamilyBrief({
    required String token,
    required int familyId,
  }) async {
    final uri = Uri.parse('$baseUrl/families/$familyId/family-briefs/pending');
    final response = await http.get(uri, headers: _authHeaders(token));
    _ensureSuccess(response);
    final map = jsonDecode(response.body) as Map<String, dynamic>;
    final b = map['brief'];
    if (b == null) return null;
    return _familyBriefFromJson(Map<String, dynamic>.from(b as Map));
  }

  Future<List<FamilyBrief>> listPendingFamilyBriefs({
    required String token,
    required int familyId,
  }) async {
    final uri = Uri.parse('$baseUrl/families/$familyId/family-briefs/pending-list');
    final response = await http.get(uri, headers: _authHeaders(token));
    _ensureSuccess(response);
    final map = jsonDecode(response.body) as Map<String, dynamic>;
    final raw = map['briefs'];
    if (raw is! List<dynamic>) return [];
    return raw
        .map((e) => _familyBriefFromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<FamilyBrief> getFamilyBrief({
    required String token,
    required int briefId,
  }) async {
    final uri = Uri.parse('$baseUrl/family-briefs/$briefId');
    final response = await http.get(uri, headers: _authHeaders(token));
    _ensureSuccess(response);
    return _familyBriefFromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<FamilyBrief> createFamilyBrief({
    required String token,
    required int familyId,
    required String childStatusText,
    String? contactNote,
    required String questionText,
    bool parentsOnly = false,
  }) async {
    final uri = Uri.parse('$baseUrl/families/$familyId/family-briefs');
    final response = await http.post(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode({
        'child_status_text': childStatusText,
        'contact_note': contactNote,
        'question_text': questionText,
        'parents_only': parentsOnly,
      }),
    );
    _ensureSuccess(response);
    return _familyBriefFromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<FamilyBrief> replyFamilyBriefQuick({
    required String token,
    required int briefId,
    required String quickText,
  }) async {
    final uri = Uri.parse('$baseUrl/family-briefs/$briefId/replies');
    final response = await http.post(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode({
        'reply_kind': 'quick',
        'quick_text': quickText,
      }),
    );
    _ensureSuccess(response);
    return _familyBriefFromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<FamilyBrief> uploadFamilyBriefReplyVoice({
    required String token,
    required int briefId,
    required String filePath,
    required int durationSeconds,
  }) async {
    final uri = Uri.parse('$baseUrl/family-briefs/$briefId/replies/upload');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll({'Authorization': 'Bearer $token'});
    request.fields['duration_seconds'] = '$durationSeconds';
    request.files.add(await http.MultipartFile.fromPath('file', filePath));
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    _ensureSuccess(response);
    return _familyBriefFromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<Photo>> getPhotos({
    required String token,
    required int familyId,
  }) async {
    final uri = Uri.parse('$baseUrl/families/$familyId/photos');
    final response = await http.get(uri, headers: _authHeaders(token));
    _ensureSuccess(response);
    final data = jsonDecode(response.body) as List<dynamic>;
    return data.map((e) {
      final json = Map<String, dynamic>.from(e as Map<String, dynamic>);
      json['image_url'] = _resolveImageUrl(json['image_url'] as String);
      return Photo.fromJson(json);
    }).toList();
  }

  Future<void> likePhoto({
    required String token,
    required int photoId,
  }) async {
    final uri = Uri.parse('$baseUrl/photos/$photoId/likes');
    final response = await http.post(
      uri,
      headers: _authHeaders(token),
      body: '{}',
    );
    _ensureSuccess(response);
  }

  Future<void> unlikePhoto({
    required String token,
    required int photoId,
  }) async {
    final uri = Uri.parse('$baseUrl/photos/$photoId/likes');
    final response = await http.delete(uri, headers: _authHeaders(token));
    _ensureSuccess(response);
  }

  Future<void> commentPhoto({
    required String token,
    required int photoId,
    required String content,
  }) async {
    final uri = Uri.parse('$baseUrl/photos/$photoId/comments');
    final response = await http.post(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode({'content': content}),
    );
    _ensureSuccess(response);
  }

  Future<void> deletePhoto({
    required String token,
    required int photoId,
  }) async {
    final uri = Uri.parse('$baseUrl/photos/$photoId');
    final response = await http.delete(uri, headers: _authHeaders(token));
    _ensureSuccess(response);
  }

  Future<void> updatePhotoCaption({
    required String token,
    required int photoId,
    required String caption,
  }) async {
    final uri = Uri.parse('$baseUrl/photos/$photoId');
    final response = await http.patch(
      uri,
      headers: _authHeaders(token),
      body: jsonEncode({'caption': caption}),
    );
    _ensureSuccess(response);
  }

  Future<List<PhotoComment>> getPhotoComments({
    required String token,
    required int photoId,
  }) async {
    final uri = Uri.parse('$baseUrl/photos/$photoId/comments');
    final response = await http.get(uri, headers: _authHeaders(token));
    _ensureSuccess(response);
    final data = jsonDecode(response.body) as List<dynamic>;
    return data.map((e) => PhotoComment.fromJson(e as Map<String, dynamic>)).toList();
  }

  Map<String, String> _authHeaders(String token) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    throw Exception('API ${response.statusCode}: ${response.body}');
  }

  String _resolveImageUrl(String imageUrl) {
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return imageUrl;
    }
    if (imageUrl.startsWith('/')) {
      return '$baseUrl$imageUrl';
    }
    return '$baseUrl/$imageUrl';
  }
}
