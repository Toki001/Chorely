import 'package:chorely/main.dart' as app;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/wait_for.dart';
import 'support/hub.dart';

// Run with seed_family_fixture.mjs against fresh local demo emulators.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Child asks for help, completes and undoes; a separate guardian answers and approves',
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
      await openHubTab(tester, 0);
      await ensureReady(tester, find.text('Add a chore'));
      await tester.tap(find.text('Add a chore'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cook rice'));
      await tester.enterText(
        find.byKey(const ValueKey('chore-date')),
        DateTime.now()
            .toUtc()
            .add(const Duration(hours: 8))
            .toIso8601String()
            .substring(0, 10),
      );
      await tester.enterText(
        find.byKey(const ValueKey('chore-steps')),
        'Ask Alex for the household instructions.',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await ensureReady(tester, find.text('Add a teamwork illustration'));
      await tester.tap(find.text('Add a teamwork illustration'));
      await ensureReady(tester, find.text('Fictional child'));
      await tester.tap(find.text('Fictional child'));
      await ensureReady(tester, find.text('Guardian review'));
      await tester.tap(find.text('Guardian review'));
      await ensureReady(tester, find.text('Save chore'));
      await tester.tap(find.text('Save chore'));
      await waitUntilAbsent(tester, find.text('What needs doing?'));
      await waitFor(tester, find.text('Chores to share'));
      await waitFor(tester, find.text('Cook rice'));
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
      await waitFor(tester, find.text('Cook rice'));
      await ensureReady(tester, find.text('Cook rice'));
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
      await ensureReady(tester, find.text('Ask for help'));
      await tester.tap(find.text('Ask for help'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('task-action-note')),
        'Please show the household steps.',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await ensureReady(tester, find.text('Send help request'));
      await tester.tap(find.text('Send help request'));
      await waitFor(tester, find.text('Help requested'));
      await waitFor(tester, find.text('Please show the household steps.'));
      await ensureReady(tester, find.text('Mark done'));
      await tester.tap(find.text('Mark done'));
      await waitFor(tester, find.text('Waiting for review'));
      expect(find.text('Approve chore'), findsNothing);
      expect(find.text('Chore activity'), findsNothing);
      await ensureReady(tester, find.text('Undo my part'));
      await tester.tap(find.text('Undo my part'));
      await waitFor(tester, find.text('Mark done'));
      await ensureReady(tester, find.text('Mark done'));
      await tester.tap(find.text('Mark done'));
      await waitFor(tester, find.text('Waiting for review'));
      // Challenge the actual callable, not an invented child UI control.
      final claims =
          (await FirebaseAuth.instance.currentUser!.getIdTokenResult()).claims!;
      final hid = claims['householdId'] as String;
      final actorId = claims['actorId'] as String;
      final owned = await FirebaseFirestore.instance
          .collection('households/$hid/occurrences')
          .where('assignedActorIds', arrayContains: actorId)
          .get();
      expect(owned.docs.length, 1);
      await expectLater(
        FirebaseFunctions.instance
            .httpsCallable('actOnOccurrence')
            .call<Object?>({
              'householdId': hid,
              'occurrenceId': owned.docs.single.id,
              'commandId': const Uuid().v4(),
              'baseVersion': owned.docs.single.get('version'),
              'action': 'approve',
              'role': 'guardian',
            }),
        throwsA(
          isA<FirebaseFunctionsException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
      );
      await ensureReady(tester, find.text('Waiting for review'));
      await tester.pumpAndSettle();
      debugPrint('Chorely M09 child pending view ready');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 4)),
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await waitFor(tester, find.text('0 of 1 finished'));
      expect(find.textContaining('1 waiting for review'), findsOneWidget);
      await ensureReady(tester, find.text('Hi, Fictional child.'));
      await tester.pumpAndSettle();
      debugPrint('Chorely M10 child Today ready');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 4)),
      );
      await openHubTab(tester, 2);
      await waitFor(tester, find.text('Month'));
      await tapHubControl(tester, find.text('Month'));
      await waitFor(tester, find.text('Cook rice'));
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      await tapHubControl(tester, find.text('Day'));
      await ensureReady(tester, find.text('Cook rice'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cook rice'));
      await waitFor(tester, find.text('Chore details'));
      await tester.pumpAndSettle();
      await waitFor(tester, find.text('Waiting for review'));
      expect(find.text('Approve chore'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await openHubTab(tester, 3);
      await waitFor(tester, find.text('Alex'));
      expect(find.text('Invite an adult'), findsNothing);
      expect(find.text('Access controls'), findsNothing);
      await openHubTab(tester, 0);
      await tapHubControl(tester, find.text('Leave supervised mode'));
      await waitFor(tester, find.text('Adult email'));
      expect(find.text('Your homes'), findsNothing);
      await signIn();
      await ensureReady(tester, find.text('Cook rice'));
      await tester.tap(find.text('Cook rice'));
      await waitFor(tester, find.text('Approve chore'));
      await waitFor(tester, find.text('Please show the household steps.'));
      await ensureReady(tester, find.text('Mark request answered'));
      await tester.tap(find.text('Mark request answered'));
      await waitUntilAbsent(tester, find.text('Mark request answered'));
      await ensureReady(tester, find.text('Approve chore'));
      await tester.tap(find.text('Approve chore'));
      await waitFor(tester, find.text('Approved'));
      await waitFor(tester, find.text('Approved the chore'));
      expect(find.text('Undo my part'), findsNothing);
      await ensureReady(tester, find.text('Chore activity'));
      await tester.pumpAndSettle();
      debugPrint('Chorely M09 guardian activity view ready');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 4)),
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await waitFor(tester, find.text('1 of 1 finished'));
      await ensureReady(
        tester,
        find.text('A little teamwork,\na happier home.'),
      );
      await tester.pumpAndSettle();
      debugPrint('Chorely M10 guardian Today ready');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 4)),
      );
      await openHubTab(tester, 2);
      await waitFor(tester, find.text('Month'));
      await tapHubControl(tester, find.text('Month'));
      await waitFor(tester, find.text('Cook rice'));
      await ensureReady(tester, find.text('Month'));
      await tester.pumpAndSettle();
      debugPrint('Chorely M10 guardian Calendar ready');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 4)),
      );
      await tapHubControl(tester, find.byType(DropdownButtonFormField<String>));
      await tester.tap(find.text('Just me').last);
      await tester.pumpAndSettle();
      await waitFor(tester, find.text('0 of 0 finished'));
      expect(find.text('Cook rice'), findsNothing);
      await tapHubControl(tester, find.byType(DropdownButtonFormField<String>));
      await tester.tap(find.text('Everyone').last);
      await tester.pumpAndSettle();
      await waitFor(tester, find.text('1 of 1 finished'));
      await openHubTab(tester, 1);
      await waitFor(tester, find.text('Cook rice'));
      await openHubTab(tester, 3);
      await waitFor(tester, find.text('Fictional child'));
      expect(tester.takeException(), isNull);
    },
  );
}
