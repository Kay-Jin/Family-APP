import 'package:family_mobile/api/api_client.dart';
import 'package:family_mobile/models/daily_question.dart';
import 'package:family_mobile/models/family.dart';
import 'package:family_mobile/models/photo.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppState extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient(baseUrl: 'http://127.0.0.1:8000');

  bool isLoading = true;
  bool isBusy = false;
  String? error;

  String? token;
  int? userId;
  Family? family;
  List<DailyQuestion> dailyQuestions = [];
  List<Photo> photos = [];

  bool get isLoggedIn => token != null;

  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token');
    userId = prefs.getInt('user_id');
    isLoading = false;
    notifyListeners();
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
      await refreshHomeData();
    });
  }

  Future<void> joinFamily(String inviteCode) async {
    if (token == null) return;
    await _runBusy(() async {
      await _apiClient.joinFamily(token: token!, inviteCode: inviteCode);
    });
  }

  Future<void> refreshHomeData() async {
    if (token == null || family == null) return;
    await _runBusy(() async {
      dailyQuestions = await _apiClient.getDailyQuestions(token: token!, familyId: family!.id);
      photos = await _apiClient.getPhotos(token: token!, familyId: family!.id);
    });
  }

  Future<void> logout() async {
    token = null;
    userId = null;
    family = null;
    dailyQuestions = [];
    photos = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user_id');
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
}
