import 'package:chorely/main.dart' as app;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/wait_for.dart';

// Run with seed_family_fixture.mjs against fresh local demo emulators.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Guardian saves Cook rice; paired child reads its stored instructions',
    (tester) async {
      await app.main();
      await FirebaseAuth.instance.signOut();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('I already have an account'));
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
        await waitFor(tester, find.text('Native fictional home'));
        await tester.tap(find.text('Native fictional home'));
        await waitFor(tester, find.text('Alex'));
      }

      await signIn();
      await tester.ensureVisible(find.text('Add a child profile'));
      await tester.tap(find.text('Add a child profile'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Fictional child');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save child profile'));
      await tester.tap(find.text('Save child profile'));
      await waitFor(tester, find.textContaining('Child profile saved.'));
      await tester.ensureVisible(find.text('Back to the home team'));
      await tester.tap(find.text('Back to the home team'));
      await waitFor(tester, find.text('Fictional child'));
      await tester.ensureVisible(find.text('Add a chore'));
      await tester.tap(find.text('Add a chore'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cook rice'));
      await tester.enterText(
        find.byKey(const ValueKey('chore-date')),
        '2026-10-30',
      );
      await tester.enterText(
        find.byKey(const ValueKey('chore-steps')),
        'Ask Alex for the household instructions.',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Add a teamwork illustration'));
      await tester.tap(find.text('Add a teamwork illustration'));
      await tester.ensureVisible(find.text('Fictional child'));
      await tester.tap(find.text('Fictional child'));
      await tester.ensureVisible(find.text('Guardian review'));
      await tester.tap(find.text('Guardian review'));
      await tester.ensureVisible(find.text('Save chore'));
      await tester.tap(find.text('Save chore'));
      await waitUntilAbsent(tester, find.text('What needs doing?'));
      await waitFor(tester, find.text('Chores to share'));
      await waitFor(tester, find.text('Cook rice'));
      await tester.ensureVisible(find.text('Link a device'));
      await tester.tap(find.text('Link a device'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Approve and create code'));
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
      await tester.ensureVisible(find.text('Link a child device'));
      await tester.tap(find.text('Link a child device'));
      await tester.pumpAndSettle();
      expect(find.text('Adult email'), findsNothing);
      await tester.enterText(find.byType(TextFormField), code);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Link this device'));
      await tester.tap(find.text('Link this device'));
      await waitFor(tester, find.text('Hi, Fictional child.'));
      expect(find.text('Invite an adult'), findsNothing);
      expect(find.text('Add a child profile'), findsNothing);
      await waitFor(tester, find.text('Cook rice'));
      await tester.ensureVisible(find.text('Cook rice'));
      await tester.tap(find.text('Cook rice'));
      await waitFor(tester, find.text('Step by step'));
      expect(
        find.text('1. Ask Alex for the household instructions.'),
        findsOneWidget,
      );
      expect(
        find.text('A separate guardian reviews this chore.'),
        findsOneWidget,
      );
      expect(find.text('Edit chore'), findsNothing);
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('app/assets/illustrations/assign.png'),
          tester.element(find.text('Step by step')),
        ),
      );
      await tester.pumpAndSettle();
      debugPrint('Chorely M07 child detail ready');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 4)),
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Leave supervised mode'));
      await tester.tap(find.text('Leave supervised mode'));
      await waitFor(tester, find.text('Adult email'));
      expect(find.text('Your homes'), findsNothing);
      await signIn();
      await tester.ensureVisible(find.text('Cook rice'));
      await tester.tap(find.text('Cook rice'));
      await waitFor(tester, find.text('Edit chore'));
      await tester.ensureVisible(find.text('Edit chore'));
      await tester.tap(find.text('Edit chore'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('chore-steps')),
        'Updated household instructions from Alex.',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save chore'));
      await tester.tap(find.text('Save chore'));
      await waitUntilAbsent(tester, find.text('Make it clear.'));
      await waitFor(tester, find.text('Chore details'));
      await waitFor(
        tester,
        find.text('1. Updated household instructions from Alex.'),
      );
      debugPrint('Chorely M07 guardian detail ready');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 4)),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
