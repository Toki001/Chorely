import 'package:chorely/main.dart' as app;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/wait_for.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Fresh process reads the approved occurrence and accepted-only history',
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
      await waitFor(tester, find.text('Approved'));
      await waitFor(tester, find.text('Approved the chore'));
      expect(find.text('Approve chore'), findsNothing);
      expect(find.text('Undo my part'), findsNothing);
      expect(find.text('Marked done · Waiting for review'), findsNWidgets(2));
      expect(find.text('Undid their part'), findsOneWidget);
      expect(find.text('Marked a help request answered'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
