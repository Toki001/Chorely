import 'package:chorely/main.dart' as app;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/wait_for.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Fresh process reads stored chore edit and cancels without deleting history',
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
      await waitFor(tester, find.text('Cook rice'));
      await tester.ensureVisible(find.text('Cook rice'));
      await tester.tap(find.text('Cook rice'));
      await waitFor(
        tester,
        find.text('1. Updated household instructions from Alex.'),
      );
      await tester.ensureVisible(find.text('Cancel chore'));
      await tester.tap(find.text('Cancel chore'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel assignment'));
      await waitFor(tester, find.text('This assignment was cancelled.'));
      expect(find.text('Edit chore'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
