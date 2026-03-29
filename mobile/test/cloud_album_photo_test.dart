import 'package:family_mobile/supabase/cloud_album_photo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromJson parses counts from view row', () {
    final p = CloudAlbumPhoto.fromJson({
      'id': 'a1',
      'family_id': 'f1',
      'user_id': 'u1',
      'caption': 'hi',
      'image_path': 'p/x.jpg',
      'uploader_display_name': 'Mom',
      'created_at': '2026-03-30T00:00:00Z',
      'like_count': 3,
      'comment_count': 7,
    });
    expect(p.likeCount, 3);
    expect(p.commentCount, 7);
  });

  test('fromJson defaults counts when absent (plain family_photos row)', () {
    final p = CloudAlbumPhoto.fromJson({
      'id': 'a1',
      'family_id': 'f1',
      'user_id': 'u1',
      'caption': '',
      'image_path': 'p/x.jpg',
      'uploader_display_name': 'Dad',
      'created_at': '2026-03-30T00:00:00Z',
    });
    expect(p.likeCount, 0);
    expect(p.commentCount, 0);
  });
}
