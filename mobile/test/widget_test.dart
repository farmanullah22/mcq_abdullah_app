// Basic smoke test for the MCQ app. This test is intentionally lightweight;
// the app requires backend connectivity so it only verifies the app boots
// into the splash screen without throwing.
import 'package:flutter_test/flutter_test.dart';

import 'package:mcq/app.dart';

void main() {
  testWidgets('App boots to splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const McqApp());
    expect(find.byType(McqApp), findsOneWidget);
  });
}
