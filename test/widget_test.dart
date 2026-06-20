import 'package:flutter_test/flutter_test.dart';
import 'package:drive_t/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
    );
  });

  testWidgets('Drive Tutor app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const DriveTApp());

    // Verify that the splash screen is displayed
    expect(find.text('DRIVE TUTOR'), findsOneWidget);
  });
}
