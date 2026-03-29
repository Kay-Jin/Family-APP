import 'package:family_mobile/l10n/app_strings.dart';
import 'package:family_mobile/screens/companion_room_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CompanionRoomScreen calls photos callback after pop', (WidgetTester tester) async {
    var jumped = false;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: CompanionRoomScreen(onOpenPhotosTogether: () => jumped = true),
      ),
    );
    await tester.pump();

    expect(find.text('Open family Photos tab (together)'), findsOneWidget);
    await tester.tap(find.text('Open family Photos tab (together)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(jumped, true);
  });
}
