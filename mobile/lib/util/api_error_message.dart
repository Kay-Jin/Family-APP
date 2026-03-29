import 'package:gotrue/gotrue.dart' show AuthException;

/// Maps common Supabase / PostgREST / network failures to short, user-facing text.
/// [tr] returns a localized string for the given message key.
String apiErrorMessage(Object error, String Function(String key) tr) {
  if (error is AuthException) {
    final code = (error.code ?? '').toLowerCase();
    final em = error.message.toLowerCase();
    if (code == 'invalid_credentials' || em.contains('invalid login')) {
      return tr('error_auth_invalid_login');
    }
    if (code == 'email_not_confirmed' || em.contains('email not confirmed')) {
      return tr('error_auth_email_not_confirmed');
    }
    if (code == 'signup_disabled' || em.contains('signups not allowed')) {
      return tr('error_auth_signup_disabled');
    }
    if (code.contains('already_registered') || em.contains('user already registered')) {
      return tr('error_duplicate');
    }
    if (code == 'weak_password' || em.contains('password is')) {
      return tr('error_auth_weak_password');
    }
    if (em.isNotEmpty) {
      return tr('error_auth_detail').replaceAll('{msg}', error.message);
    }
  }

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
  if (lower.contains('care_e2ee_unlock_required')) {
    return tr('care_e2ee_unlock_required');
  }
  if (lower.contains('answer_text_or_image_required')) {
    return tr('answer_text_or_image_required');
  }
  if (lower.contains('album_comment_required')) {
    return tr('album_comment_required');
  }
  if (lower.contains('wechat_not_configured')) {
    return tr('error_wechat_not_configured');
  }
  if (lower.contains('wechat_not_installed')) {
    return tr('error_wechat_not_installed');
  }
  if (lower.contains('wechat_not_supported_on_web')) {
    return tr('error_wechat_not_supported_web');
  }
  if (lower.contains('wechat_auth_launch_failed')) {
    return tr('error_wechat_launch_failed');
  }
  if (lower.contains('wechat_auth_timeout')) {
    return tr('error_wechat_timeout');
  }
  if (lower.contains('wechat_auth_cancelled')) {
    return tr('error_wechat_cancelled');
  }

  return tr('error_generic');
}
