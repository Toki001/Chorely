import 'package:chorely/main.dart' as app;
import 'package:chorely/features/sync/data/sqlite_chore_command_store.dart';
import 'package:chorely/features/sync/data/sqlite_read_cache_store.dart';
import 'package:chorely/features/sync/domain/chore_command_outbox.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Native SQLite purges fence queued identity and household writes',
    (tester) async {
      await app.initializeDevelopmentBackend();
      final cache = SqliteReadCacheStore();
      final commands = SqliteChoreCommandStore();
      const oldUid = 'fictional-storage-old', newUid = 'fictional-storage-new';
      await cache.retainIdentity(oldUid);
      final writes = [
        for (var i = 0; i < 8; i++)
          cache.write(oldUid, 'storage-home', 'late-$i', {
            'version': 1,
          }, DateTime.now()),
      ];
      await cache.retainIdentity(newUid);
      await Future.wait(writes);
      for (var i = 0; i < 8; i++) {
        expect(await cache.read(oldUid, 'storage-home', 'late-$i'), isNull);
      }
      await cache.write(newUid, 'storage-home', 'confirmed', {
        'version': 2,
      }, DateTime.now());
      final late = cache.write(newUid, 'storage-home', 'late', {
        'version': 1,
      }, DateTime.now());
      await cache.purgeHousehold(newUid, 'storage-home');
      await late;
      expect(await cache.read(newUid, 'storage-home', 'confirmed'), isNull);
      expect(await cache.read(newUid, 'storage-home', 'late'), isNull);
      await cache.write(newUid, 'storage-home', 'fresh', {
        'version': 3,
      }, DateTime.now());
      expect((await cache.read(newUid, 'storage-home', 'fresh'))!.value, {
        'version': 3,
      });
      await cache.retainIdentity(null);
      expect(await cache.read(newUid, 'storage-home', 'fresh'), isNull);

      ChoreCommand command(String id) => ChoreCommand(
        id: id,
        uid: newUid,
        householdId: 'storage-home',
        occurrenceId: id,
        action: 'complete',
        baseVersion: 1,
      );
      await commands.retainIdentity(newUid);
      final queued = commands.enqueue(command('late-command'));
      final rejected = expectLater(queued, throwsA(isA<OutboxFailure>()));
      await commands.purgeHousehold(newUid, 'storage-home');
      await rejected;
      expect(await commands.read(newUid), isEmpty);
      await commands.enqueue(command('fresh-command'));
      expect((await commands.read(newUid)).single.command.id, 'fresh-command');
      final logoutWrite = commands.enqueue(command('logout-command'));
      final logoutRejected = expectLater(
        logoutWrite,
        throwsA(isA<OutboxFailure>()),
      );
      await commands.retainIdentity(null);
      await logoutRejected;
      expect(await commands.read(newUid), isEmpty);
    },
  );
}
