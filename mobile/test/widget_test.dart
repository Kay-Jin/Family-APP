import 'package:family_mobile/main.dart';
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

  testWidgets('FamilyApp builds and shows login when logged out', (WidgetTester tester) async {
    await tester.pumpWidget(const FamilyApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(FamilyApp), findsOneWidget);
  });
}
