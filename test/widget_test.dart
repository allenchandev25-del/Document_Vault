import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vault/main.dart';

void main() {
  testWidgets('Vault App loads showing shield icon', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MainApp());

    // Verify that the shield loading indicator is present on launch
    expect(find.byIcon(Icons.shield), findsOneWidget);
  });
}
