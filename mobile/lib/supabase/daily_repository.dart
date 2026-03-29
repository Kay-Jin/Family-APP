import 'dart:typed_data';

import 'package:family_mobile/supabase/cloud_daily_answer.dart';
import 'package:family_mobile/supabase/cloud_daily_question.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DailyRepository {
  DailyRepository({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _answerImageBucket = 'family_answer_images';

  static const signedAnswerImageUrlExpirySeconds = 3600;

  Future<String> signedAnswerImageUrl(String storagePath) async {
    return _client.storage.from(_answerImageBucket).createSignedUrl(storagePath, signedAnswerImageUrlExpirySeconds);
  }

  /// One signed URL per distinct path; failed paths are omitted.
  Future<Map<String, String>> signedAnswerImageUrls(Iterable<String?> paths) async {
    final out = <String, String>{};
    for (final p in paths.toSet()) {
      if (p == null || p.isEmpty) continue;
      try {
        out[p] = await signedAnswerImageUrl(p);
      } catch (_) {}
    }
    return out;
  }

  Future<List<CloudDailyQuestion>> listQuestions(String familyId) async {
    final rows = await _client
        .from('daily_questions')
        .select()
        .eq('family_id', familyId)
        .order('created_at', ascending: false);
    return (rows as List<dynamic>).map((e) => CloudDailyQuestion.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<CloudDailyQuestion> createQuestion({
    required String familyId,
    required String questionDate,
    required String questionText,
  }) async {
    final row = await _client.from('daily_questions').insert({
      'family_id': familyId,
      'question_date': questionDate,
      'question_text': questionText,
    }).select().single();
    return CloudDailyQuestion.fromJson(Map<String, dynamic>.from(row as Map));
  }

  Future<List<CloudDailyAnswer>> listAnswers(String questionId) async {
    final rows = await _client
        .from('daily_answers')
        .select()
        .eq('question_id', questionId)
        .order('created_at', ascending: false);
    return (rows as List<dynamic>).map((e) => CloudDailyAnswer.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  String _contentTypeForExtension(String ext) {
    switch (ext.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'heic':
      case 'heif':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }

  Future<void> createAnswer({
    required String familyId,
    required String questionId,
    required String answerText,
    Uint8List? imageBytes,
    String? imageExtension,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not signed in');
    final trimmed = answerText.trim();
    if (trimmed.isEmpty && (imageBytes == null || imageBytes.isEmpty)) {
      throw Exception('answer_text_or_image_required');
    }

    final metaName = user.userMetadata?['name'] ?? user.userMetadata?['full_name'];
    final name = metaName is String && metaName.isNotEmpty
        ? metaName
        : (user.email != null && user.email!.isNotEmpty ? user.email!.split('@').first : 'Member');

    String? imagePath;
    if (imageBytes != null && imageBytes.isNotEmpty) {
      var ext = (imageExtension ?? 'jpg').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (ext.isEmpty) ext = 'jpg';
      imagePath = '$familyId/${user.id}/${DateTime.now().millisecondsSinceEpoch}.$ext';
      await _client.storage.from(_answerImageBucket).uploadBinary(
            imagePath,
            imageBytes,
            fileOptions: FileOptions(
              contentType: _contentTypeForExtension(ext),
              upsert: false,
            ),
          );
    }

    await _client.from('daily_answers').insert({
      'question_id': questionId,
      'user_id': user.id,
      'author_display_name': name,
      'answer_text': trimmed.isEmpty ? ' ' : trimmed,
      if (imagePath != null) 'image_path': imagePath,
    });
  }
}
