// Basic smoke test for the Spendly app.

import 'package:flutter_test/flutter_test.dart';
import 'package:spendly/main.dart';

void main() {
  testWidgets('App launches and shows splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SpendlyApp());

    // Verify branding elements are present on the splash screen.
    expect(find.text('Spendly'), findsOneWidget);
    expect(find.text('Smart Expense Tracking'), findsOneWidget);
  });
}
