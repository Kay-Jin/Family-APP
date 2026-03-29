import 'dart:typed_data';

import 'package:family_mobile/supabase/cloud_album_photo.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AlbumRepository {
  AlbumRepository({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  static const _bucket = 'family_album_images';

  String publicUrl(String storagePath) {
    return _client.storage.from(_bucket).getPublicUrl(storagePath);
  }

  Future<List<CloudAlbumPhoto>> listPhotos(String familyId) async {
    final rows = await _client
        .from('family_photos')
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

    final metaName = user.userMetadata?['name'] ?? user.userMetadata?['full_name'];
    final name = metaName is String && metaName.isNotEmpty
        ? metaName
        : (user.email != null && user.email!.isNotEmpty ? user.email!.split('@').first : 'Member');

    final row = await _client.from('family_photos').insert({
      'family_id': familyId,
      'user_id': user.id,
      'caption': caption.trim(),
      'image_path': path,
      'uploader_display_name': name,
    }).select().single();

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
