import 'package:family_mobile/util/api_error_message.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gotrue/gotrue.dart';

void main() {
  String tr(String k) => k;

  group('apiErrorMessage', () {
    test('maps network errors', () {
      expect(apiErrorMessage(Exception('SocketException: failed'), tr), 'error_network');
      expect(apiErrorMessage('Failed host lookup', tr), 'error_network');
      expect(apiErrorMessage('Connection refused', tr), 'error_network');
    });

    test('maps auth session errors', () {
      expect(apiErrorMessage('JWT expired', tr), 'error_session_expired');
      expect(apiErrorMessage('invalid jwt token', tr), 'error_session_expired');
    });

    test('maps RLS / permission', () {
      expect(apiErrorMessage('new row violates row-level security', tr), 'error_no_access');
      expect(apiErrorMessage('PostgresException code 42501', tr), 'error_no_access');
    });

    test('maps wechat', () {
      expect(apiErrorMessage(StateError('wechat_not_installed'), tr), 'error_wechat_not_installed');
      expect(apiErrorMessage(Exception('wechat_auth_cancelled'), tr), 'error_wechat_cancelled');
    });

    test('maps Supabase AuthException', () {
      expect(
        apiErrorMessage(
          AuthApiException('Invalid login credentials', statusCode: '400', code: 'invalid_credentials'),
          tr,
        ),
        'error_auth_invalid_login',
      );
      expect(
        apiErrorMessage(
          AuthApiException('Email not confirmed', statusCode: '400', code: 'email_not_confirmed'),
          tr,
        ),
        'error_auth_email_not_confirmed',
      );
    });

    test('fallback generic', () {
      expect(apiErrorMessage('something unknown', tr), 'error_generic');
    });
  });
}
