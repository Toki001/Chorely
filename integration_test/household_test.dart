import 'package:chorely/main.dart' as app;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/wait_for.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Adult signs in, creates household and sees persisted data after app recreation',
    (tester) async {
      await app.main();
      await FirebaseAuth.instance.signOut();
      await tester.pumpAndSettle();
      await tester.tap(find.text('I already have an account'));
      await tester.pumpAndSettle();
      Future<void> signIn() async {
        await tester.enterText(
          find.byType(TextFormField).at(0),
          'native-guardian@example.test',
        );
        await tester.enterText(
          find.byType(TextFormField).at(1),
          'fictional-only-password-42',
        );
        await tester.ensureVisible(
          find.widgetWithText(FilledButton, 'Sign in'),
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
        await waitFor(tester, find.text('Your homes'));
        expect(find.text('Your homes'), findsOneWidget);
      }

      await signIn();
      await tester.ensureVisible(find.text('Create a household'));
      await tester.tap(find.text('Create a household'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Native fictional home',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'Alex');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Create household'));
      await tester.tap(find.text('Create household'));
      await waitFor(tester, find.text('The home team'));
      await waitFor(tester, find.text('Alex'));
      expect(find.text('Native fictional home'), findsOneWidget);
      expect(find.text('Asia/Manila'), findsOneWidget);
      expect(find.text('Alex'), findsOneWidget);
      // Dispose the entire widget tree and its subscriptions, retaining only server data.
      await tester.pumpWidget(const SizedBox.shrink());
      await FirebaseAuth.instance.signOut();
      // main configures emulators once; a fresh app composition exercises new repositories.
      app.mountApplication();
      await tester.pumpAndSettle();
      await tester.tap(find.text('I already have an account'));
      await tester.pumpAndSettle();
      await signIn();
      await waitFor(tester, find.text('Native fictional home'));
      await tester.tap(find.text('Native fictional home'));
      await waitFor(tester, find.text('Alex'));
      expect(find.text('Alex'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
