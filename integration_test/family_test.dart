import 'package:chorely/main.dart' as app;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/wait_for.dart';
import 'support/hub.dart';

// Run after the M05 household processes against the SAME local emulators.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Guardian approves child profile/device; shared device requires adult credentials to return',
    (tester) async {
      await app.main();
      await FirebaseAuth.instance.signOut();
      await tester.pumpAndSettle();
      await ensureReady(tester, find.text('I already have an account'));
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
        await ensureReady(tester, find.widgetWithText(FilledButton, 'Sign in'));
        await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
        await waitFor(tester, find.text('Your homes'));
        await waitFor(tester, find.text('Native fictional home'));
        await tester.tap(find.text('Native fictional home'));
        await waitFor(tester, find.text('Alex'));
      }

      await signIn();
      await openHubTab(tester, 3);
      await ensureReady(tester, find.text('Add a child profile'));
      await tester.tap(find.text('Add a child profile'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Fictional child');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await ensureReady(tester, find.text('Save child profile'));
      await tester.tap(find.text('Save child profile'));
      await waitFor(tester, find.textContaining('Child profile saved.'));
      await ensureReady(tester, find.text('Back to the home team'));
      await tester.tap(find.text('Back to the home team'));
      await waitFor(tester, find.text('Fictional child'));
      await openHubTab(tester, 3);
      await ensureReady(tester, find.text('Link a device'));
      await tester.tap(find.text('Link a device'));
      await tester.pumpAndSettle();
      await ensureReady(tester, find.text('Approve and create code'));
      await tester.tap(find.text('Approve and create code'));
      await waitFor(tester, find.text('A little independence.'));
      final code = tester
          .widget<SelectableText>(find.byType(SelectableText))
          .data!;
      expect(code.length, 43);
      await tester.tap(find.byTooltip('Back to your homes'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Sign out'));
      await waitFor(tester, find.text('Link a child device'));
      await ensureReady(tester, find.text('Link a child device'));
      await tester.tap(find.text('Link a child device'));
      await tester.pumpAndSettle();
      expect(find.text('Adult email'), findsNothing);
      await tester.enterText(find.byType(TextFormField), code);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await ensureReady(tester, find.text('Link this device'));
      await tester.tap(find.text('Link this device'));
      await waitFor(tester, find.text('Hi, Fictional child.'));
      expect(find.text('Invite an adult'), findsNothing);
      expect(find.text('Add a child profile'), findsNothing);
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('app/assets/illustrations/assign.png'),
          tester.element(find.text('Hi, Fictional child.')),
        ),
      );
      await tester.pumpAndSettle();
      debugPrint('Chorely native child view ready');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 4)),
      );
      await ensureReady(tester, find.text('Leave supervised mode'));
      await tester.tap(find.text('Leave supervised mode'));
      await waitFor(tester, find.text('Adult email'));
      expect(find.text('Your homes'), findsNothing);
      await signIn();
      await openHubTab(tester, 3);
      await ensureReady(tester, find.text('Linked child device'));
      await tester.pumpAndSettle();
      debugPrint('Chorely native guardian view ready');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 4)),
      );
      await ensureReady(tester, find.text('Revoke access'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Revoke access'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Remove access'));
      await waitUntilAbsent(tester, find.text('Linked child device'));
      expect(tester.takeException(), isNull);
    },
  );
}
