import 'dart:convert';
import 'dart:typed_data';

import 'package:family_mobile/crypto/family_e2ee_policy.dart';
import 'package:family_mobile/crypto/family_e2ee_session.dart';
import 'package:family_mobile/crypto/family_passphrase_crypto.dart';
import 'package:family_mobile/supabase/cloud_daily_answer.dart';
import 'package:family_mobile/supabase/cloud_daily_question.dart';
import 'package:http/http.dart' as http;
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

  Future<CloudDailyAnswer> _normalizeAnswer(String familyId, Map<String, dynamic> json) async {
    final base = CloudDailyAnswer.fromJson(json);
    final key = FamilyE2eeSession.keyFor(familyId);
    final textV = base.answerEncryptionVersion;
    final imgV = base.answerImageEncryptionVersion;
    var text = base.answerText;
    var textLocked = false;
    if (textV >= 1 && base.answerCipherPayload != null && base.answerCipherPayload!.trim().isNotEmpty) {
      if (key == null) {
        text = '';
        textLocked = true;
      } else {
        try {
          text = await FamilyPassphraseCrypto.openUtf8String(
            payloadJson: base.answerCipherPayload!,
            keyBytes: key,
          );
        } catch (_) {
          text = '';
          textLocked = true;
        }
      }
    }
    final imageLocked = imgV >= 1 && key == null && base.imagePath != null && base.imagePath!.isNotEmpty;
    return CloudDailyAnswer(
      id: base.id,
      questionId: base.questionId,
      userId: base.userId,
      userDisplayName: base.userDisplayName,
      answerText: text,
      imagePath: base.imagePath,
      createdAt: base.createdAt,
      answerEncryptionVersion: textV,
      answerCipherPayload: base.answerCipherPayload,
      answerImageEncryptionVersion: imgV,
      answerTextLocked: textLocked,
      answerImageLocked: imageLocked,
    );
  }

  Future<List<CloudDailyAnswer>> listAnswers(String familyId, String questionId) async {
    final rows = await _client
        .from('daily_answers')
        .select()
        .eq('question_id', questionId)
        .order('created_at', ascending: false);
    final out = <CloudDailyAnswer>[];
    for (final e in rows as List<dynamic>) {
      out.add(await _normalizeAnswer(familyId, Map<String, dynamic>.from(e as Map)));
    }
    return out;
  }

  Future<Uint8List?> loadDecryptedAnswerImageBytes({
    required String familyId,
    required CloudDailyAnswer answer,
  }) async {
    if (answer.answerImageEncryptionVersion < 1) return null;
    final path = answer.imagePath;
    if (path == null || path.isEmpty) return null;
    final key = FamilyE2eeSession.keyFor(familyId);
    if (key == null) return null;
    final url = await signedAnswerImageUrl(path);
    final r = await http.get(Uri.parse(url));
    if (r.statusCode != 200) return null;
    try {
      final payload = utf8.decode(r.bodyBytes);
      return await FamilyPassphraseCrypto.openBytes(payloadJson: payload, keyBytes: key);
    } catch (_) {
      return null;
    }
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

    await FamilyE2eePolicy.assertWriteAllowed(_client, familyId);
    final uses = await FamilyE2eePolicy.familyUsesCloudEncryption(_client, familyId);

    final metaName = user.userMetadata?['name'] ?? user.userMetadata?['full_name'];
    final name = metaName is String && metaName.isNotEmpty
        ? metaName
        : (user.email != null && user.email!.isNotEmpty ? user.email!.split('@').first : 'Member');

    String? imagePath;
    var imgEncVer = 0;
    if (imageBytes != null && imageBytes.isNotEmpty) {
      var ext = (imageExtension ?? 'jpg').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (ext.isEmpty) ext = 'jpg';
      var pathExt = ext;
      var uploadBytes = imageBytes;
      var contentType = _contentTypeForExtension(ext);
      if (uses) {
        final key = FamilyE2eeSession.keyFor(familyId)!;
        final sealed = await FamilyPassphraseCrypto.sealBytes(plaintext: imageBytes, keyBytes: key);
        uploadBytes = Uint8List.fromList(utf8.encode(sealed));
        contentType = 'application/octet-stream';
        pathExt = 'e2ee';
        imgEncVer = 1;
      }
      imagePath = '$familyId/${user.id}/${DateTime.now().millisecondsSinceEpoch}.$pathExt';
      await _client.storage.from(_answerImageBucket).uploadBinary(
            imagePath,
            uploadBytes,
            fileOptions: FileOptions(
              contentType: contentType,
              upsert: false,
            ),
          );
    }

    final row = <String, dynamic>{
      'question_id': questionId,
      'user_id': user.id,
      'author_display_name': name,
      'answer_encryption_version': 0,
      'answer_cipher_payload': null,
      'answer_image_encryption_version': imgEncVer,
      if (imagePath != null) 'image_path': imagePath,
    };

    if (uses && trimmed.isNotEmpty) {
      final key = FamilyE2eeSession.keyFor(familyId)!;
      row['answer_cipher_payload'] = await FamilyPassphraseCrypto.sealUtf8String(plaintext: trimmed, keyBytes: key);
      row['answer_encryption_version'] = 1;
      row['answer_text'] = ' ';
    } else {
      row['answer_text'] = trimmed.isEmpty ? ' ' : trimmed;
    }

    await _client.from('daily_answers').insert(row);
  }
}
