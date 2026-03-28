import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Copy recording into app documents so it survives OS temp cleanup after restart.
Future<String?> materializeVoiceFileForRetry(String sourcePath) async {
  final src = File(sourcePath);
  if (!await src.exists()) return null;

  final dir = await getApplicationDocumentsDirectory();
  final dot = sourcePath.lastIndexOf('.');
  final ext = dot >= 0 ? sourcePath.substring(dot) : '.m4a';
  final dest = File('${dir.path}/pending_voice_upload$ext');

  await dest.writeAsBytes(await src.readAsBytes(), flush: true);
  return dest.path;
}

Future<void> removeMaterializedVoiceFile(String? path) async {
  if (path == null || path.isEmpty) return;
  try {
    final f = File(path);
    if (await f.exists()) {
      await f.delete();
    }
  } catch (_) {}
}

Future<bool> pendingVoiceFileStillPresent(String? path) async {
  if (path == null || path.isEmpty) return false;
  return File(path).exists();
}
