import 'dart:convert';

import 'package:family_mobile/models/daily_question.dart';
import 'package:family_mobile/models/family.dart';
import 'package:family_mobile/models/photo.dart';
import 'package:family_mobile/models/birthday_reminder.dart';
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

  Future<List<Photo>> getPhotos({
    required String token,
    required int familyId,
  }) async {
    final uri = Uri.parse('$baseUrl/families/$familyId/photos');
    final response = await http.get(uri, headers: _authHeaders(token));
    _ensureSuccess(response);
    final data = jsonDecode(response.body) as List<dynamic>;
    return data.map((e) => Photo.fromJson(e as Map<String, dynamic>)).toList();
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
}
