import 'package:chorely/main.dart' as app;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/wait_for.dart';

// Run after household_test against the SAME emulator process.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Fresh native process reads household created in the previous process',
    (tester) async {
      await app.main();
      await FirebaseAuth.instance.signOut();
      await tester.pumpAndSettle();
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
      await ensureReady(tester, find.widgetWithText(FilledButton, 'Sign in'));
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await waitFor(tester, find.text('Your homes'));
      await waitFor(tester, find.text('Native fictional home'));
      expect(find.text('Native fictional home'), findsOneWidget);
      await tester.tap(find.text('Native fictional home'));
      await waitFor(tester, find.text('Alex'));
      expect(find.text('Alex'), findsOneWidget);
      expect(
        find.textContaining('Household time · Asia/Manila'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
