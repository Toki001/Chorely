import 'package:chorely/main.dart' as app;
import 'package:chorely/features/sync/data/sqlite_chore_command_store.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/wait_for.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'An unavailable command endpoint leaves a durable pending request without showing completion',
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
      const title = String.fromEnvironment(
        'CHORELY_OFFLINE_TITLE',
        defaultValue: 'Feed pets',
      );
      await ensureReady(tester, find.text(title));
      await tester.tap(find.text(title));
      await waitFor(tester, find.text('Mark done'));
      // Real loopback connection failure for commands; Firestore remains online
      // so the test can prove actual saved status has not changed.
      FirebaseFunctions.instance.useFunctionsEmulator('127.0.0.1', 5999);
      await ensureReady(tester, find.text('Mark done'));
      await tester.tap(find.text('Mark done'));
      await waitFor(
        tester,
        find.text('Saved on this device. Waiting for server confirmation.'),
      );
      expect(find.text('Done'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Mark done'),
            )
            .onPressed,
        isNull,
      );
      final rows = await SqliteChoreCommandStore().read(
        'native-fictional-guardian',
      );
      expect(rows.where((r) => r.pending).length, 1);
      expect(rows.where((r) => r.pending).single.command.baseVersion, 1);
      debugPrint('Chorely M12 durable pending request ready');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 3)),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
