import 'package:family_mobile/care/quick_status_code.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('validates known status codes', () {
    expect(QuickStatusCode.isValid(QuickStatusCode.home), true);
    expect(QuickStatusCode.isValid(QuickStatusCode.needChat), true);
    expect(QuickStatusCode.isValid('invalid'), false);
  });

  test('l10n keys are stable', () {
    expect(QuickStatusCode.l10nKeyFor(QuickStatusCode.home), 'quick_status_home');
    expect(QuickStatusCode.l10nKeyFor(QuickStatusCode.onWay), 'quick_status_on_way');
    expect(QuickStatusCode.l10nKeyFor(QuickStatusCode.tired), 'quick_status_tired');
    expect(QuickStatusCode.l10nKeyFor(QuickStatusCode.needChat), 'quick_status_need_chat');
  });

  test('all codes map to l10n keys', () {
    for (final c in QuickStatusCode.all) {
      expect(QuickStatusCode.l10nKeyFor(c), isNot('status'));
    }
  });
}
