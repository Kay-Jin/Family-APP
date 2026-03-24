import 'dart:convert';

import 'package:family_mobile/models/daily_question.dart';
import 'package:family_mobile/models/family.dart';
import 'package:family_mobile/models/photo.dart';
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

  Future<void> joinFamily({
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
