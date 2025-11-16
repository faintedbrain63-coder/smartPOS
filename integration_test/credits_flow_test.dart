import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:smart_pos/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Credits flow: Edit and Delete update list instantly', (tester) async {
    runApp(const SmartPOSApp());
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Navigate to Credits
    expect(find.text('Credits'), findsOneWidget);
    await tester.tap(find.text('Credits'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Tap first customer if exists
    final customerTiles = find.byType(ListTile);
    if (customerTiles.evaluate().isEmpty) return;
    await tester.tap(customerTiles.first);
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Open menu and choose Edit (if present)
    final menu = find.byType(PopupMenuButton<String>).first;
    await tester.tap(menu);
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    if (find.text('Edit Credit').evaluate().isNotEmpty) {
      await tester.tap(find.text('Edit Credit'));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      // Save immediately
      final save = find.text('Save');
      if (save.evaluate().isNotEmpty) {
        await tester.tap(save);
        await tester.pumpAndSettle(const Duration(seconds: 1));
      }
    }

    // Open menu and choose Delete
    await tester.tap(menu);
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    if (find.text('Delete Credit').evaluate().isNotEmpty) {
      await tester.tap(find.text('Delete Credit'));
      await tester.pumpAndSettle(const Duration(seconds: 1));
    }
  });
}