/// Maps common Supabase / PostgREST / network failures to short, user-facing text.
/// [tr] returns a localized string for the given message key.
String apiErrorMessage(Object error, String Function(String key) tr) {
  final msg = error.toString();
  final lower = msg.toLowerCase();

  if (lower.contains('socketexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('network is unreachable') ||
      lower.contains('connection refused') ||
      lower.contains('connection reset') ||
      lower.contains('timed out') ||
      lower.contains('handshake exception')) {
    return tr('error_network');
  }
  if (lower.contains('jwt expired') ||
      lower.contains('invalid jwt') ||
      lower.contains('session expired') ||
      lower.contains('refresh_token')) {
    return tr('error_session_expired');
  }
  if (lower.contains('row-level security') ||
      lower.contains('new row violates row-level') ||
      lower.contains('permission denied') ||
      lower.contains('42501') ||
      lower.contains('insufficient_privilege')) {
    return tr('error_no_access');
  }
  if (lower.contains('foreign key') || lower.contains('23503')) {
    return tr('error_reference');
  }
  if (lower.contains('unique constraint') || lower.contains('23505') || lower.contains('duplicate key')) {
    return tr('error_duplicate');
  }
  if (lower.contains('not signed in') || lower.contains('not logged')) {
    return tr('error_not_signed_in');
  }

  return tr('error_generic');
}
