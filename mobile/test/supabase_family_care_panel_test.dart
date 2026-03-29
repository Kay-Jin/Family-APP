import 'package:family_mobile/l10n/app_strings.dart';
import 'package:family_mobile/screens/supabase_family_care_panel.dart';
import 'fake_care_family_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://test.supabase.co',
      anonKey: 'public-anon-key-for-widget-tests-only',
    );
  });

  testWidgets('SupabaseFamilyCarePanel shows smart care section', (WidgetTester tester) async {
    final fake = FakeCareFamilyRepository();
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
        home: Scaffold(
          body: SupabaseFamilyCarePanel(
            familyId: 'family-test-1',
            repository: fake,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Smart Care Reminders'), findsOneWidget);
    expect(fake.refreshTouchCount, 1);
  });

}
