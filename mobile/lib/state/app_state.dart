import 'package:family_mobile/api/api_client.dart';
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
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppState extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient(baseUrl: _resolveBaseUrl());

  static const _pendingVoiceUploadKey = 'pending_voice_upload_v1';
  static const _pendingVoiceUploadErrorKey = 'pending_voice_upload_error_v1';

  bool isLoading = true;
  bool isBusy = false;
  String? error;

  String? token;
  int? userId;
  String? localeCode;
  Family? family;
  List<DailyQuestion> dailyQuestions = [];
  List<Photo> photos = [];
  List<BirthdayReminder> birthdayReminders = [];
  List<ActivityItem> activities = [];
  List<StatusUpdate> statusUpdates = [];
  List<VoiceMessage> voiceMessages = [];
  List<EmergencyContact> emergencyContacts = [];
  List<CareReminder> careReminders = [];
  Map<int, List<PhotoComment>> photoComments = {};
  Map<int, List<DailyAnswer>> dailyAnswers = {};
  Map<String, dynamic>? pendingVoiceUpload;
  String? voiceUploadError;

  bool get isLoggedIn => token != null;
  bool get hasPendingVoiceUpload => pendingVoiceUpload != null;

  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token');
    userId = prefs.getInt('user_id');
    localeCode = prefs.getString('locale_code');

    final pendingJson = prefs.getString(_pendingVoiceUploadKey);
    if (pendingJson != null && pendingJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(pendingJson);
        if (decoded is Map<String, dynamic>) {
          pendingVoiceUpload = decoded;
        } else if (decoded is Map) {
          pendingVoiceUpload = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        pendingVoiceUpload = null;
      }
    }
    voiceUploadError = prefs.getString(_pendingVoiceUploadErrorKey);

    final familyId = prefs.getInt('family_id');
    if (token != null && familyId != null) {
      try {
        family = await _apiClient.getFamily(token: token!, familyId: familyId);
      } catch (_) {
        family = null;
      }
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> _persistPendingVoiceUpload() async {
    if (pendingVoiceUpload == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingVoiceUploadKey, jsonEncode(pendingVoiceUpload));
    if (voiceUploadError == null || voiceUploadError!.isEmpty) {
      await prefs.remove(_pendingVoiceUploadErrorKey);
    } else {
      await prefs.setString(_pendingVoiceUploadErrorKey, voiceUploadError!);
    }
  }

  Future<void> _clearPendingVoiceUploadPersisted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingVoiceUploadKey);
    await prefs.remove(_pendingVoiceUploadErrorKey);
  }

  Future<void> login(String wechatCode, String displayName) async {
    await _runBusy(() async {
      final data = await _apiClient.loginWithMockWechat(code: wechatCode, displayName: displayName);
      token = data['token'] as String;
      userId = data['user_id'] as int;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token!);
      await prefs.setInt('user_id', userId!);
    });
  }

  Future<void> createFamily(String familyName) async {
    if (token == null) return;
    await _runBusy(() async {
      family = await _apiClient.createFamily(token: token!, familyName: familyName);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('family_id', family!.id);
      await _refreshHomeDataInternal();
    });
  }

  Future<void> joinFamily(String inviteCode) async {
    if (token == null) return;
    await _runBusy(() async {
      family = await _apiClient.joinFamily(token: token!, inviteCode: inviteCode);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('family_id', family!.id);
      await _refreshHomeDataInternal();
    });
  }

  Future<void> refreshHomeData() async {
    if (token == null || family == null) return;
    await _runBusy(() async {
      await _refreshHomeDataInternal();
    });
  }

  Future<void> togglePhotoLike({
    required int photoId,
    required bool hasLiked,
  }) async {
    if (token == null || family == null) return;
    await _runBusy(() async {
      if (hasLiked) {
        await _apiClient.unlikePhoto(token: token!, photoId: photoId);
      } else {
        await _apiClient.likePhoto(token: token!, photoId: photoId);
      }
      await _refreshHomeDataInternal();
    });
  }

  Future<void> commentPhoto({
    required int photoId,
    required String content,
  }) async {
    if (token == null || family == null) return;
    await _runBusy(() async {
      await _apiClient.commentPhoto(token: token!, photoId: photoId, content: content);
      await refreshPhotoComments(photoId);
      await _refreshHomeDataInternal();
    });
  }

  Future<void> deletePhoto(int photoId) async {
    if (token == null || family == null) return;
    await _runBusy(() async {
      await _apiClient.deletePhoto(token: token!, photoId: photoId);
      photoComments.remove(photoId);
      await _refreshHomeDataInternal();
    });
  }

  Future<void> updatePhotoCaption({
    required int photoId,
    required String caption,
  }) async {
    if (token == null || family == null) return;
    await _runBusy(() async {
      await _apiClient.updatePhotoCaption(
        token: token!,
        photoId: photoId,
        caption: caption,
      );
      await _refreshHomeDataInternal();
    });
  }

  Future<void> refreshPhotoComments(int photoId) async {
    if (token == null || family == null) return;
    final comments = await _apiClient.getPhotoComments(token: token!, photoId: photoId);
    photoComments[photoId] = comments;
    notifyListeners();
  }

  Future<void> addDailyQuestion({
    required String questionDate,
    required String questionText,
  }) async {
    if (token == null || family == null) return;
    await _runBusy(() async {
      await _apiClient.createDailyQuestion(
        token: token!,
        familyId: family!.id,
        questionDate: questionDate,
        questionText: questionText,
      );
      await _refreshHomeDataInternal();
    });
  }

  Future<void> addDailyAnswer({
    required int questionId,
    required String answerText,
  }) async {
    if (token == null || family == null) return;
    await _runBusy(() async {
      await _apiClient.createDailyAnswer(
        token: token!,
        questionId: questionId,
        answerText: answerText,
      );
      await refreshDailyAnswers(questionId);
    });
  }

  Future<void> refreshDailyAnswers(int questionId) async {
    if (token == null || family == null) return;
    final answers = await _apiClient.getDailyAnswers(token: token!, questionId: questionId);
    dailyAnswers[questionId] = answers;
    notifyListeners();
  }

  Future<void> addPhoto({
    required String imageUrl,
    required String caption,
  }) async {
    if (token == null || family == null) return;
    await _runBusy(() async {
      await _apiClient.createPhoto(
        token: token!,
        familyId: family!.id,
        imageUrl: imageUrl,
        caption: caption,
      );
      await _refreshHomeDataInternal();
    });
  }

  Future<void> addPhotoFromFile({
    required String filePath,
    required String caption,
  }) async {
    if (token == null || family == null) return;
    await _runBusy(() async {
      await _apiClient.uploadPhoto(
        token: token!,
        familyId: family!.id,
        filePath: filePath,
        caption: caption,
      );
      await _refreshHomeDataInternal();
    });
  }

  Future<void> addBirthdayReminder({
    required String birthday,
    required int notifyDaysBefore,
  }) async {
    if (token == null || family == null) return;
    await _runBusy(() async {
      await _apiClient.createBirthdayReminder(
        token: token!,
        familyId: family!.id,
        birthday: birthday,
        notifyDaysBefore: notifyDaysBefore,
      );
      await _refreshHomeDataInternal();
    });
  }

  Future<void> updateBirthdayReminder({
    required int reminderId,
    required String birthday,
    required int notifyDaysBefore,
    required bool enabled,
  }) async {
    if (token == null || family == null) return;
    await _runBusy(() async {
      await _apiClient.updateBirthdayReminder(
        token: token!,
        reminderId: reminderId,
        birthday: birthday,
        notifyDaysBefore: notifyDaysBefore,
        enabled: enabled,
      );
      await _refreshHomeDataInternal();
    });
  }

  Future<void> deleteBirthdayReminder(int reminderId) async {
    if (token == null || family == null) return;
    await _runBusy(() async {
      await _apiClient.deleteBirthdayReminder(
        token: token!,
        reminderId: reminderId,
      );
      await _refreshHomeDataInternal();
    });
  }

  Future<void> logout() async {
    token = null;
    userId = null;
    family = null;
    dailyQuestions = [];
    photos = [];
    birthdayReminders = [];
    activities = [];
    statusUpdates = [];
    voiceMessages = [];
    emergencyContacts = [];
    careReminders = [];
    photoComments = {};
    dailyAnswers = {};
    pendingVoiceUpload = null;
    voiceUploadError = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user_id');
    await prefs.remove('family_id');
    await prefs.remove(_pendingVoiceUploadKey);
    await prefs.remove(_pendingVoiceUploadErrorKey);
    notifyListeners();
  }

  Future<void> setLocaleCode(String? code) async {
    localeCode = code;
    final prefs = await SharedPreferences.getInstance();
    if (code == null || code.isEmpty) {
      await prefs.remove('locale_code');
    } else {
      await prefs.setString('locale_code', code);
    }
    notifyListeners();
  }

  Future<void> _runBusy(Future<void> Function() job) async {
    isBusy = true;
    error = null;
    notifyListeners();
    try {
      await job();
    } catch (e) {
      error = e.toString();
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> _refreshHomeDataInternal() async {
    dailyQuestions = await _apiClient.getDailyQuestions(token: token!, familyId: family!.id);
    photos = await _apiClient.getPhotos(token: token!, familyId: family!.id);
    birthdayReminders = await _apiClient.getBirthdayReminders(token: token!, familyId: family!.id);
    activities = await _apiClient.getActivities(token: token!, familyId: family!.id);
    statusUpdates = await _apiClient.getStatusUpdates(token: token!, familyId: family!.id);
    voiceMessages = await _apiClient.getVoiceMessages(token: token!, familyId: family!.id);
    emergencyContacts = await _apiClient.getEmergencyContacts(token: token!, familyId: family!.id);
    careReminders = await _apiClient.getCareReminders(token: token!, familyId: family!.id);
  }

  Future<void> addStatusUpdate({
    required String statusCode,
    required String note,
  }) async {
    if (token == null || family == null) return;
    await _runBusy(() async {
      await _apiClient.createStatusUpdate(
        token: token!,
        familyId: family!.id,
        statusCode: statusCode,
        note: note,
      );
      await _refreshHomeDataInternal();
    });
  }

  Future<void> addVoiceMessage({
    required String title,
    required String audioUrl,
    required int durationSeconds,
  }) async {
    if (token == null || family == null) return;
    await _runBusy(() async {
      await _apiClient.createVoiceMessage(
        token: token!,
        familyId: family!.id,
        title: title,
        audioUrl: audioUrl,
        durationSeconds: durationSeconds,
      );
      await _refreshHomeDataInternal();
    });
  }

  Future<void> addVoiceMessageFromFile({
    required String title,
    required String filePath,
    required int durationSeconds,
  }) async {
    if (token == null || family == null) return;
    await _runBusy(() async {
      Exception? lastError;
      var waitMs = 500;
      for (var i = 0; i < 3; i++) {
        try {
          await _apiClient.uploadVoiceMessage(
            token: token!,
            familyId: family!.id,
            title: title,
            filePath: filePath,
            durationSeconds: durationSeconds,
          );
          lastError = null;
          break;
        } catch (e) {
          lastError = Exception(e.toString());
          if (i < 2) {
            await Future.delayed(Duration(milliseconds: waitMs));
            waitMs *= 2;
          }
        }
      }
      if (lastError != null) {
        pendingVoiceUpload = {
          'title': title,
          'file_path': filePath,
          'duration_seconds': durationSeconds,
        };
        voiceUploadError = lastError.toString();
        await _persistPendingVoiceUpload();
        throw lastError;
      }
      pendingVoiceUpload = null;
      voiceUploadError = null;
      await _clearPendingVoiceUploadPersisted();
      await _refreshHomeDataInternal();
    });
  }

  Future<void> retryPendingVoiceUpload() async {
    if (pendingVoiceUpload == null) return;
    final payload = pendingVoiceUpload!;
    await addVoiceMessageFromFile(
      title: payload['title'] as String,
      filePath: payload['file_path'] as String,
      durationSeconds: payload['duration_seconds'] as int,
    );
  }

  Future<void> renameVoiceMessage({
    required int messageId,
    required String title,
  }) async {
    if (token == null || family == null) return;
    await _runBusy(() async {
      await _apiClient.updateVoiceMessageTitle(
        token: token!,
        messageId: messageId,
        title: title,
      );
      await _refreshHomeDataInternal();
    });
  }

  Future<void> removeVoiceMessage(int messageId) async {
    if (token == null || family == null) return;
    await _runBusy(() async {
      await _apiClient.deleteVoiceMessage(
        token: token!,
        messageId: messageId,
      );
      await _refreshHomeDataInternal();
    });
  }

  Future<void> addEmergencyContact({
    required String contactName,
    required String relation,
    required String phone,
    required String city,
    required String medicalNotes,
    required bool isPrimary,
  }) async {
    if (token == null || family == null) return;
    await _runBusy(() async {
      await _apiClient.createEmergencyContact(
        token: token!,
        familyId: family!.id,
        contactName: contactName,
        relation: relation,
        phone: phone,
        city: city,
        medicalNotes: medicalNotes,
        isPrimary: isPrimary,
      );
      await _refreshHomeDataInternal();
    });
  }

  static String _resolveBaseUrl() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      // Android emulator maps host loopback to 10.0.2.2.
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }
}
