import 'package:flutter/foundation.dart';
import 'package:chorely/main.dart' as app;
import 'package:chorely/features/sync/data/sqlite_read_cache_store.dart';
import 'package:chorely/features/sync/data/sqlite_chore_command_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/wait_for.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'A confirmed membership removal purges cached household data and local commands',
    (tester) async {
      await app.main();
      await waitFor(tester, find.text('Your homes'));
      await waitFor(
        tester,
        find.text(
          'Your household starts here. Choose a name and invite everyone in when you’re ready.',
        ),
      );
      await waitUntilAbsent(tester, find.text('Native fictional home'));
      const hid = String.fromEnvironment('CHORELY_REVOKED_HOME');
      final cache = SqliteReadCacheStore();
      expect(
        await cache.read('native-fictional-guardian', hid, 'home'),
        isNull,
      );
      expect(
        await cache.read('native-fictional-guardian', hid, 'people'),
        isNull,
      );
      final rows = await SqliteChoreCommandStore().read(
        'native-fictional-guardian',
      );
      expect(rows.where((r) => r.command.householdId == hid), isEmpty);
      expect(find.text('Mark done'), findsNothing);
      debugPrint('Chorely M12 revoked cache purged ready');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 3)),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
