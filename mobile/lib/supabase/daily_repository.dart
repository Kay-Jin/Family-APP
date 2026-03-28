import 'package:family_mobile/supabase/cloud_daily_answer.dart';
import 'package:family_mobile/supabase/cloud_daily_question.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DailyRepository {
  DailyRepository({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

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

  Future<void> createAnswer({
    required String questionId,
    required String answerText,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not signed in');
    final metaName = user.userMetadata?['name'] ?? user.userMetadata?['full_name'];
    final name = metaName is String && metaName.isNotEmpty
        ? metaName
        : (user.email != null && user.email!.isNotEmpty ? user.email!.split('@').first : 'Member');
    await _client.from('daily_answers').insert({
      'question_id': questionId,
      'user_id': user.id,
      'author_display_name': name,
      'answer_text': answerText,
    });
  }
}
