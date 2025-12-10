import 'package:flutter_test/flutter_test.dart';
import 'package:drive_t/main.dart';

void main() {
  testWidgets('Drive T app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const DriveTApp());

    // Verify that the splash screen is displayed
    expect(find.text('Drive T'), findsOneWidget);
  });
}
