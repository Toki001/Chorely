import 'package:chorely/features/notifications/data/sqlite_reminder_ledger.dart';
import 'package:chorely/features/notifications/domain/device_reminders.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chorely/main.dart' as app;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/wait_for.dart';
import 'support/hub.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Private assignment and review updates open authorized chores across child and guardian sessions',
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
        await waitFor(tester, find.text('Native fictional home'));
        await tester.tap(find.text('Native fictional home'));
        await waitFor(tester, find.text('Alex'));
      }

      await signIn();
      final homeId =
          (await FirebaseFirestore.instance
                  .collection('users/native-fictional-guardian/households')
                  .get())
              .docs
              .single
              .id;
      final ledger = SqliteReminderLedger();
      final instant = DateTime.now().toUtc();
      final claim = await ledger.claim(
        DeviceReminder(
          id: 'fictional-ledger-$homeId',
          at: instant,
          expires: instant.add(const Duration(hours: 1)),
          title: '',
          body: '',
          payload: '',
        ),
        instant,
      );
      expect(claim.attempt, true);
      expect(claim.id, greaterThan(0));
      await tester.tap(find.byTooltip('Your updates'));
      await waitFor(tester, find.text('A chore is ready for you.'));
      await ensureReady(tester, find.text('Notification preferences'));
      await tester.tap(find.text('Notification preferences'));
      await waitFor(tester, find.text('Household timezone: Asia/Manila'));
      await ensureReady(tester, find.text('Allow alerts on this device'));
      // Initialization never prompts. Device permission is opt-in; denial is
      // covered by the injected device boundary tests, not faked as native here.
      expect(find.textContaining('Device alerts are off.'), findsOneWidget);
      debugPrint('Chorely M11 guardian preferences ready');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 3)),
      );
      await waitFor(tester, find.byTooltip('Back'));
      await tester.pageBack();
      await tester.pumpAndSettle();
      await waitFor(tester, find.byTooltip('Back'));
      await tester.pageBack();
      await tester.pumpAndSettle();
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
      await tester.tap(find.byTooltip('Back to your homes'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Sign out'));
      await waitFor(tester, find.text('Link a child device'));
      await ensureReady(tester, find.text('Link a child device'));
      await tester.tap(find.text('Link a child device'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), code);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await ensureReady(tester, find.text('Link this device'));
      await tester.tap(find.text('Link this device'));
      await waitFor(tester, find.text('Hi, Fictional child.'));
      await tester.tap(find.byTooltip('Your updates'));
      await waitFor(tester, find.text('1 unread in recent updates'));
      await ensureReady(tester, find.text('Notification preferences'));
      await tester.tap(find.text('Notification preferences'));
      await waitFor(
        tester,
        find.textContaining('Your guardian manages these settings.'),
      );
      expect(find.text('Save preferences'), findsNothing);
      await waitFor(tester, find.byTooltip('Back'));
      await tester.pageBack();
      await tester.pumpAndSettle();
      await ensureReady(tester, find.text('A chore is ready for you.'));
      debugPrint('Chorely M11 child inbox ready');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 3)),
      );
      await tester.tap(find.text('A chore is ready for you.'));
      await waitFor(tester, find.text('Cook rice'));
      await waitFor(tester, find.text('Mark done'));
      expect(find.text('Approve chore'), findsNothing);
      await ensureReady(tester, find.text('Mark done'));
      await tester.tap(find.text('Mark done'));
      await waitFor(tester, find.text('Waiting for review'));
      await waitFor(tester, find.byTooltip('Back'));
      await tester.pageBack();
      await tester.pumpAndSettle();
      await waitFor(tester, find.byTooltip('Back'));
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tapHubControl(tester, find.text('Leave supervised mode'));
      await waitFor(tester, find.text('Adult email'));
      await signIn();
      await tester.tap(find.byTooltip('Your updates'));
      await waitFor(
        tester,
        find.text('A household chore is waiting for review.'),
      );
      await ensureReady(
        tester,
        find.text('A household chore is waiting for review.'),
      );
      debugPrint('Chorely M11 guardian review inbox ready');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 3)),
      );
      await tester.tap(find.text('A household chore is waiting for review.'));
      await waitFor(tester, find.text('Approve chore'));
      await ensureReady(tester, find.text('Approve chore'));
      await tester.tap(find.text('Approve chore'));
      await waitFor(tester, find.text('Approved'));
      expect(tester.takeException(), isNull);
    },
  );
}
