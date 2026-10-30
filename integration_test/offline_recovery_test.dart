import 'package:chorely/main.dart' as app;
import 'package:chorely/features/sync/data/sqlite_chore_command_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/wait_for.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'A fresh process restores the frozen request and shows only the server result',
    (tester) async {
      await app.main();
      await waitFor(tester, find.text('Native fictional home'));
      await tester.tap(find.text('Native fictional home'));
      const conflict = bool.fromEnvironment('CHORELY_OFFLINE_CONFLICT');
      const requestedTitle = String.fromEnvironment(
        'CHORELY_OFFLINE_TITLE',
        defaultValue: 'Feed pets',
      );
      final title = conflict ? 'Sweep floor' : requestedTitle;
      await ensureReady(tester, find.text(title));
      await tester.tap(find.text(title));
      if (conflict) {
        await waitFor(
          tester,
          find.text('This saved request needs your review.'),
        );
        await waitUntilAbsent(tester, find.text('Done'));
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Mark done'),
              )
              .onPressed,
          isNull,
        );
        final before = await SqliteChoreCommandStore().read(
          'native-fictional-guardian',
        );
        expect(before.where((r) => r.state == 'conflict').length, 1);
        expect(
          before.where((r) => r.state == 'conflict').single.command.baseVersion,
          1,
        );
        await ensureReady(tester, find.text('Review current chore'));
        await tester.tap(find.text('Review current chore'));
        await waitUntilAbsent(
          tester,
          find.text('This saved request needs your review.'),
        );
        expect(find.text('Done'), findsNothing);
        final after = await SqliteChoreCommandStore().read(
          'native-fictional-guardian',
        );
        expect(after.where((r) => r.pending || r.blocked), isEmpty);
        debugPrint('Chorely M12 explicit conflict review ready');
      } else {
        await waitFor(tester, find.text('Done'));
        expect(
          find.text('Saved on this device. Waiting for server confirmation.'),
          findsNothing,
        );
        final rows = await SqliteChoreCommandStore().read(
          'native-fictional-guardian',
        );
        expect(rows.where((r) => r.pending || r.blocked), isEmpty);
        expect(rows.where((r) => r.state == 'accepted').length, 1);
        debugPrint('Chorely M12 server-confirmed recovery ready');
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 3)),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
