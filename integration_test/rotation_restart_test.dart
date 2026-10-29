import 'package:chorely/main.dart' as app;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/wait_for.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Fresh process loads real turn order and applies a future pause without erasing history',
    (tester) async {
      await app.main();
      await FirebaseAuth.instance.signOut();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('I already have an account'));
      await tester.tap(find.text('I already have an account'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'native-guardian@example.test',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'fictional-only-password-42',
      );
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await waitFor(tester, find.text('Native fictional home'));
      await tester.tap(find.text('Native fictional home'));
      await waitFor(tester, find.text('Chores to share'));
      await tester.pumpAndSettle();
      final assigned = find.ancestor(
        of: find.textContaining('\nAssigned').first,
        matching: find.byType(ListTile),
      );
      await waitFor(tester, assigned);
      await tester.ensureVisible(assigned);
      await tester.tap(assigned);
      await waitFor(tester, find.text('Repeat settings'));
      await tester.ensureVisible(find.text('Repeat settings'));
      await tester.tap(find.text('Repeat settings'));
      await tester.pumpAndSettle();
      expect(find.text('1. Alex'), findsOneWidget);
      expect(find.text('2. Fictional Sam'), findsOneWidget);
      expect(find.text('3. Fictional Lee'), findsOneWidget);
      final start = tester
          .widget<TextFormField>(find.byKey(const ValueKey('repeat-start')))
          .controller!
          .text;
      final effective = DateTime.parse('${start}T00:00:00Z')
          .add(const Duration(days: 2))
          .toIso8601String()
          .substring(0, 10);
      await tester.enterText(
        find.byKey(const ValueKey('repeat-effective')),
        effective,
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Pause from the effective date'));
      await tester.tap(find.text('Pause from the effective date'));
      await tester.ensureVisible(find.text('Preview next 14 days'));
      await tester.tap(find.text('Preview next 14 days'));
      await waitFor(
        tester,
        find.text('No turns from this version while it is paused.'),
      );
      await tester.ensureVisible(find.text('Save repeat settings'));
      await tester.tap(find.text('Save repeat settings'));
      await waitUntilAbsent(tester, find.text('A rhythm for your home.'));
      await waitFor(tester, find.text('Chores to share'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
