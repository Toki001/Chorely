import 'package:chorely/main.dart' as app;
import 'package:chorely/features/sync/data/sqlite_read_cache_store.dart';
import 'package:chorely/features/sync/data/sqlite_chore_command_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/wait_for.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'A fully disconnected data session reads its own confirmed cache and keeps completion pending',
    (tester) async {
      await app.main();
      await waitFor(tester, find.text('Native fictional home'));
      await tester.tap(find.text('Native fictional home'));
      await waitFor(
        tester,
        find.text(
          'Showing saved household data. Waiting for a connection check.',
        ),
      );
      await ensureReady(tester, find.text('Sweep floor'));
      await tester.tap(find.text('Sweep floor'));
      await waitFor(tester, find.text('Chore details'));
      await waitFor(tester, find.text('Updated on another fictional device'));
      await ensureReady(tester, find.text('Mark done'));
      await tester.tap(find.text('Mark done'));
      await waitFor(
        tester,
        find.text('Saved on this device. Waiting for server confirmation.'),
      );
      expect(find.text('Done'), findsNothing);
      final rows = await SqliteChoreCommandStore().read(
        'native-fictional-guardian',
      );
      expect(rows.where((r) => r.pending).single.command.baseVersion, 2);
      expect(
        await SqliteReadCacheStore().read(
          'native-fictional-guardian',
          'foreign-home',
          'people',
        ),
        isNull,
      );
      debugPrint('Chorely M12 cached offline detail ready');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 3)),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
