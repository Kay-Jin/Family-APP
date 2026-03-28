import 'package:family_mobile/supabase/cloud_daily_answer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromJson with image_path', () {
    final a = CloudDailyAnswer.fromJson({
      'id': 'a1',
      'question_id': 'q1',
      'user_id': 'u1',
      'author_display_name': 'Bob',
      'answer_text': 'Hi',
      'image_path': 'fam/u1/x.jpg',
      'created_at': '2026-01-01T00:00:00Z',
    });
    expect(a.imagePath, 'fam/u1/x.jpg');
    expect(a.answerText, 'Hi');
  });

  test('fromJson null image_path', () {
    final a = CloudDailyAnswer.fromJson({
      'id': 'a1',
      'question_id': 'q1',
      'user_id': 'u1',
      'author_display_name': 'Bob',
      'answer_text': 'Hi',
      'created_at': '2026-01-01T00:00:00Z',
    });
    expect(a.imagePath, isNull);
  });
}
