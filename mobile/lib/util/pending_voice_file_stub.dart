/// Web / non-IO: paths are used as-is; no local file lifecycle.
Future<String?> materializeVoiceFileForRetry(String sourcePath) async {
  return sourcePath;
}

Future<void> removeMaterializedVoiceFile(String? path) async {}

Future<bool> pendingVoiceFileStillPresent(String? path) async {
  return path != null && path.isNotEmpty;
}
