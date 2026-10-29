import 'package:chorely/features/notifications/data/sqlite_reminder_ledger.dart';
import 'package:chorely/features/notifications/domain/device_reminders.dart';
import 'package:chorely/features/notifications/domain/notifications_repository.dart';
import 'package:chorely/main.dart' as app;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/wait_for.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'A fresh process resolves an opaque notification using persisted auth and current server access',
    (tester) async {
      await app.main();
      const unavailable = bool.fromEnvironment('CHORELY_TEST_UNAVAILABLE');
      if (unavailable) {
        await waitFor(tester, find.text('Your homes'));
        await waitFor(
          tester,
          find.textContaining('This update is unavailable for this session.'),
        );
        expect(find.text('Chore details'), findsNothing);
      } else {
        await waitFor(tester, find.text('Chore details'));
        await waitFor(tester, find.text('Feed pets'));
        await waitFor(tester, find.text('Mark done'));
        expect(
          FirebaseAuth.instance.currentUser?.uid,
          'native-fictional-guardian',
        );
        await waitFor(tester, find.text('Chore activity'));
        debugPrint('Chorely M11 native cold route ready');
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(seconds: 3)),
        );
      }
      const payload = String.fromEnvironment('CHORELY_TEST_NOTIFICATION');
      final homeId = NotificationLink.parse(payload)!.householdId;
      final instant = DateTime.now().toUtc();
      final claim = await SqliteReminderLedger().claim(
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
      expect(
        claim.attempt,
        false,
        reason:
            'SQLite must preserve the uncertain attempt after a fresh process',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
