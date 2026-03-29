import 'dart:typed_data';

import 'package:family_mobile/supabase/cloud_album_comment.dart';
import 'package:family_mobile/supabase/cloud_album_photo.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AlbumRepository {
  AlbumRepository({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  static const _bucket = 'family_album_images';

  /// Private bucket: short-lived URL for [Image.network] / full-screen viewer.
  static const signedAlbumUrlExpirySeconds = 3600;

  Future<String> signedAlbumImageUrl(String storagePath) async {
    return _client.storage.from(_bucket).createSignedUrl(storagePath, signedAlbumUrlExpirySeconds);
  }

  /// One round-trip per distinct path; failures for a path are omitted from the map.
  Future<Map<String, String>> signedAlbumImageUrls(Iterable<String> paths) async {
    final out = <String, String>{};
    for (final path in paths.toSet()) {
      if (path.isEmpty) continue;
      try {
        out[path] = await signedAlbumImageUrl(path);
      } catch (_) {
        // Leave missing so UI can show error placeholder.
      }
    }
    return out;
  }

  Future<List<CloudAlbumPhoto>> listPhotos(String familyId) async {
    final rows = await _client
        .from('family_photos_with_counts')
        .select()
        .eq('family_id', familyId)
        .order('created_at', ascending: false);
    return (rows as List<dynamic>)
        .map((e) => CloudAlbumPhoto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
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

  Future<CloudAlbumPhoto> uploadPhoto({
    required String familyId,
    required Uint8List bytes,
    required String imageExtension,
    String caption = '',
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not signed in');
    if (bytes.isEmpty) throw Exception('empty_image');

    var ext = imageExtension.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (ext.isEmpty) ext = 'jpg';
    final path = '$familyId/${user.id}/${DateTime.now().millisecondsSinceEpoch}.$ext';

    await _client.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: _contentTypeForExtension(ext),
            upsert: false,
          ),
        );

    final row = await _client.from('family_photos').insert({
      'family_id': familyId,
      'user_id': user.id,
      'caption': caption.trim(),
      'image_path': path,
      'uploader_display_name': _displayNameFor(user),
    }).select().single();

    return CloudAlbumPhoto.fromJson(Map<String, dynamic>.from(row as Map));
  }

  String _displayNameFor(User user) {
    final metaName = user.userMetadata?['name'] ?? user.userMetadata?['full_name'];
    if (metaName is String && metaName.isNotEmpty) return metaName;
    if (user.email != null && user.email!.isNotEmpty) return user.email!.split('@').first;
    return 'Member';
  }

  /// Like count and whether the current user liked this photo (one `select` on `family_photo_likes`).
  Future<({int count, bool likedByMe})> getLikeState(String photoId) async {
    final user = _client.auth.currentUser;
    if (user == null) return (count: 0, likedByMe: false);
    final rows = await _client.from('family_photo_likes').select('user_id').eq('photo_id', photoId);
    final list = rows as List<dynamic>;
    var liked = false;
    for (final r in list) {
      final m = Map<String, dynamic>.from(r as Map);
      if (m['user_id'].toString() == user.id) liked = true;
    }
    return (count: list.length, likedByMe: liked);
  }

  Future<void> likePhoto(String photoId) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not signed in');
    try {
      await _client.from('family_photo_likes').insert({
        'photo_id': photoId,
        'user_id': user.id,
      });
    } catch (e) {
      final s = e.toString().toLowerCase();
      if (s.contains('23505') || s.contains('duplicate') || s.contains('unique')) return;
      rethrow;
    }
  }

  Future<void> unlikePhoto(String photoId) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not signed in');
    await _client.from('family_photo_likes').delete().eq('photo_id', photoId).eq('user_id', user.id);
  }

  Future<List<CloudAlbumComment>> listComments(String photoId) async {
    final rows = await _client
        .from('family_photo_comments')
        .select()
        .eq('photo_id', photoId)
        .order('created_at', ascending: true);
    return (rows as List<dynamic>)
        .map((e) => CloudAlbumComment.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<CloudAlbumComment> addComment(String photoId, String body) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not signed in');
    final trimmed = body.trim();
    if (trimmed.isEmpty) throw Exception('album_comment_required');
    final row = await _client.from('family_photo_comments').insert({
      'photo_id': photoId,
      'user_id': user.id,
      'body': trimmed,
      'author_display_name': _displayNameFor(user),
    }).select().single();
    return CloudAlbumComment.fromJson(Map<String, dynamic>.from(row as Map));
  }

  Future<void> deleteComment(String commentId) async {
    await _client.from('family_photo_comments').delete().eq('id', commentId);
  }

  Future<CloudAlbumPhoto> updateCaption({
    required String photoId,
    required String caption,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not signed in');
    await _client
        .from('family_photos')
        .update({'caption': caption.trim()})
        .eq('id', photoId)
        .eq('user_id', user.id);
    final row = await _client.from('family_photos_with_counts').select().eq('id', photoId).single();
    return CloudAlbumPhoto.fromJson(Map<String, dynamic>.from(row as Map));
  }

  Future<void> deletePhoto(CloudAlbumPhoto photo) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not signed in');
    if (user.id != photo.userId) throw Exception('error_no_access');

    await _client.from('family_photos').delete().eq('id', photo.id);
    try {
      await _client.storage.from(_bucket).remove([photo.imagePath]);
    } catch (_) {
      // Row is gone; orphan object in bucket is acceptable.
    }
  }
}
