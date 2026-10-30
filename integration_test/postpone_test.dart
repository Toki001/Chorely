import 'package:chorely/main.dart' as app;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/wait_for.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'A guardian changes only this occurrence to a later stored deadline',
    (tester) async {
      await app.main();
      await FirebaseAuth.instance.signOut();
      await tester.pumpAndSettle();
      await ensureReady(tester, find.text('I already have an account'));
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
      await waitFor(tester, find.text('Native fictional home'));
      await tester.tap(find.text('Native fictional home'));
      await ensureReady(tester, find.text('Cook rice'));
      await tester.tap(find.text('Cook rice'));
      await ensureReady(tester, find.text('Postpone this occurrence'));
      await tester.tap(find.text('Postpone this occurrence'));
      await waitFor(tester, find.byKey(const ValueKey('postpone-date')));
      const date = String.fromEnvironment('CHORELY_POSTPONE_DATE');
      await tester.enterText(find.byKey(const ValueKey('postpone-date')), date);
      await tester.enterText(
        find.byKey(const ValueKey('postpone-time')),
        '19:30',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await ensureReady(tester, find.text('Confirm later deadline'));
      debugPrint('Chorely M13 postpone form ready');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 3)),
      );
      await tester.tap(find.text('Confirm later deadline'));
      await waitFor(
        tester,
        find.text(
          'This occurrence was postponed. Other turns keep their schedule.',
        ),
      );
      await waitFor(tester, find.text('$date · By 19:30'));
      expect(find.text('Done'), findsNothing);
      await ensureReady(tester, find.text('$date · By 19:30'));
      debugPrint('Chorely M13 stored deadline ready');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 3)),
      );
      await ensureReady(tester, find.text('Postponed this occurrence'));
      expect(tester.takeException(), isNull);
    },
  );
}
