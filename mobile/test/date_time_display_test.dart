import 'package:family_mobile/l10n/app_strings.dart';
import 'package:family_mobile/util/date_time_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('formatIsoDateTimeLocal parses UTC and uses locale', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en', 'US'),
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppStrings.supportedLocales,
        home: const Scaffold(
          body: SizedBox(key: Key('probe')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final ctx = tester.element(find.byKey(const Key('probe')));

    final out = formatIsoDateTimeLocal(ctx, '2026-03-28T05:27:50.67733+00:00');
    expect(out, isNot(contains('T')));
    expect(out, isNotEmpty);
  });

  testWidgets('formatIsoDateTimeLocal returns raw on bad input', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppStrings.supportedLocales,
        home: const Scaffold(
          body: SizedBox(key: Key('probe2')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final ctx = tester.element(find.byKey(const Key('probe2')));

    expect(formatIsoDateTimeLocal(ctx, 'not-a-date'), 'not-a-date');
  });
}
