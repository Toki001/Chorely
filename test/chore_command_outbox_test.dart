import 'dart:async';

import 'package:chorely/features/chores/domain/chore_repository.dart';
import 'package:chorely/features/sync/domain/chore_command_outbox.dart';
import 'package:flutter_test/flutter_test.dart';

class CommandMemoryStore implements ChoreCommandStore {
  CommandMemoryStore(this.now);
  final DateTime Function() now;
  final values = <String, StoredChoreCommand>{};
  bool fail = false;
  int writes = 0;
  @override
  Future<void> retainIdentity(String? uid) async {
    values.removeWhere((_, r) => r.command.uid != uid);
  }

  @override
  Future<void> enqueue(ChoreCommand command) async {
    if (fail) throw StateError('disk full');
    final same = values[command.id];
    if (same != null) {
      if (same.command.canonical != command.canonical) {
        throw const OutboxFailure('Changed payload');
      }
      return;
    }
    if (values.values.any(
      (r) =>
          (r.pending || r.blocked) &&
          r.command.uid == command.uid &&
          r.command.householdId == command.householdId &&
          r.command.occurrenceId == command.occurrenceId,
    )) {
      throw const OutboxFailure('Pending request exists');
    }
    writes++;
    values[command.id] = StoredChoreCommand(
      command: command,
      state: 'pending',
      attempts: 0,
      nextAttempt: now(),
    );
  }

  @override
  Future<List<StoredChoreCommand>> read(String uid) async =>
      values.values.where((r) => r.command.uid == uid).toList();
  @override
  Future<void> update(
    String uid,
    String id, {
    required String state,
    required int attempts,
    required DateTime nextAttempt,
    String? message,
  }) async {
    final row = values[id];
    if (row == null || row.command.uid != uid) return;
    values[id] = StoredChoreCommand(
      command: row.command,
      state: state,
      attempts: attempts,
      nextAttempt: nextAttempt,
      message: message,
    );
  }

  @override
  Future<void> remove(String uid, String id) async {
    if (values[id]?.command.uid == uid) values.remove(id);
  }

  @override
  Future<void> purgeHousehold(String uid, String householdId) async {
    values.removeWhere(
      (_, r) => r.command.uid == uid && r.command.householdId == householdId,
    );
  }
}

ChoreCommand command({
  String id = 'command',
  String oid = 'occurrence',
  String uid = 'device',
  int version = 1,
  String note = '',
}) => ChoreCommand(
  id: id,
  uid: uid,
  householdId: 'home',
  occurrenceId: oid,
  action: 'complete',
  baseVersion: version,
  note: note,
);
void main() {
  late DateTime clock;
  late CommandMemoryStore store;
  late ChoreCommandOutbox outbox;
  late List<ChoreCommand> sent;
  late Future<void> Function(ChoreCommand) send;
  setUp(() {
    clock = DateTime.utc(2026, 10, 29);
    store = CommandMemoryStore(() => clock);
    sent = [];
    send = (c) async {
      sent.add(c);
    };
    outbox = ChoreCommandOutbox(
      store,
      (c) => send(c),
      now: () => clock,
      automatic: false,
    );
    outbox.identity('device');
  });
  tearDown(() => outbox.dispose());
  test('Persists an immutable request before sending and fences old snapshots after server acknowledgement', () async {
    await outbox.enqueue(command());
    expect(store.writes, 1);
    expect(sent, isEmpty);
    expect(outbox.forOccurrence('home', 'occurrence', 1)?.pending, true);
    await outbox.drain();
    expect(sent.single.id, 'command');
    expect(outbox.rows.single.state, 'accepted');
    expect(outbox.forOccurrence('home', 'occurrence', 1)?.state, 'accepted');
    expect(outbox.forOccurrence('home', 'occurrence', 2), isNull);
  });
  test('Storage failure never sends and does not claim local saving', () async {
    store.fail = true;
    await expectLater(outbox.enqueue(command()), throwsA(isA<OutboxFailure>()));
    await outbox.drain();
    expect(sent, isEmpty);
    expect(outbox.storageError, isNotNull);
  });
  test('Unknown response retries the same UUID/base/note after process restoration', () async {
    send = (c) async {
      sent.add(c);
      throw const ChoreFailure('unknown');
    };
    await outbox.enqueue(command(note: 'Original note'));
    await outbox.drain();
    expect(outbox.rows.single.pending, true);
    await outbox.drain();
    expect(sent.length, 1, reason: 'Backoff must prevent a hot retry loop');
    outbox.dispose();
    outbox = ChoreCommandOutbox(
      store,
      (c) async {
        sent.add(c);
      },
      now: () => clock,
      automatic: false,
    );
    outbox.identity('device');
    clock = clock.add(const Duration(seconds: 10));
    await outbox.drain();
    expect(sent.length, 2);
    expect(sent[0].canonical, sent[1].canonical);
    expect(outbox.rows.single.state, 'accepted');
  });
  test('Server commit followed by lost response contributes only once when its receipt is replayed', () async {
    final receipts = <String>{};
    int contributions = 0;
    send = (c) async {
      sent.add(c);
      if (receipts.add(c.id)) {
        contributions++;
        throw const ChoreFailure('Lost ack');
      }
    };
    await outbox.enqueue(command());
    await outbox.drain();
    await outbox.retry('command');
    expect(contributions, 1);
    expect(sent.length, 2);
    expect(outbox.rows.single.state, 'accepted');
  });
  test('Conflict freezes the base and blocks replay until explicit current-state review', () async {
    send = (c) async {
      sent.add(c);
      throw const ChoreFailure(
        'Version changed',
        conflict: true,
        retryable: false,
      );
    };
    await outbox.enqueue(command(version: 4));
    await outbox.drain();
    expect(outbox.rows.single.state, 'conflict');
    await outbox.retry('command');
    await outbox.drain();
    expect(sent.length, 1);
    await expectLater(
      outbox.enqueue(command(id: 'replacement', version: 5)),
      throwsA(isA<OutboxFailure>()),
    );
    await outbox.resolve('command');
    expect(outbox.rows, isEmpty);
    send = (c) async {
      sent.add(c);
    };
    await outbox.enqueue(command(id: 'replacement', version: 5));
    await outbox.drain();
    expect(sent.last.baseVersion, 5);
  });
  test('A rejected stale/undo/permission action never auto-retries', () async {
    send = (c) async {
      sent.add(c);
      throw const ChoreFailure('No longer permitted', retryable: false);
    };
    await outbox.enqueue(command());
    await outbox.drain();
    await outbox.retry('command');
    clock = clock.add(const Duration(days: 1));
    await outbox.drain();
    expect(sent.length, 1);
    expect(outbox.rows.single.state, 'rejected');
  });
  test('Auth restoration suspension preserves durable requests until the real identity arrives', () async {
    await outbox.enqueue(command());
    outbox.suspend();
    await outbox.drain();
    expect(store.values.length, 1);
    expect(sent, isEmpty);
    outbox.identity('device');
    await outbox.drain();
    expect(sent.length, 1);
  });
  test('Actual logout clears old requests and an identity switch cannot send them as a new actor', () async {
    await outbox.enqueue(command());
    outbox.identity(null);
    await outbox.drain();
    expect(store.values, isEmpty);
    expect(sent, isEmpty);
    outbox.identity('someone-else');
    await expectLater(outbox.enqueue(command()), throwsA(isA<OutboxFailure>()));
  });
  test(
    'Late acknowledgements after logout cannot restore a purged row or old UI',
    () async {
      final reply = Completer<void>();
      send = (c) async {
        sent.add(c);
        await reply.future;
      };
      await outbox.enqueue(command());
      final running = outbox.drain();
      await Future<void>.delayed(Duration.zero);
      expect(sent.length, 1);
      outbox.identity(null);
      reply.complete();
      await running;
      await outbox.drain();
      expect(outbox.rows, isEmpty);
      expect(store.values, isEmpty);
    },
  );
  test('Concurrent drain signals never send duplicate calls, and a failed item does not starve another chore', () async {
    send = (c) async {
      sent.add(c);
      if (c.id == 'first') throw const ChoreFailure('offline');
    };
    await outbox.enqueue(command(id: 'first'));
    await outbox.enqueue(command(id: 'second', oid: 'other'));
    await Future.wait([outbox.drain(), outbox.drain(), outbox.drain()]);
    expect(sent.map((c) => c.id), ['first', 'second']);
    expect(outbox.rows.last.state, 'accepted');
  });
  test('Reusing a saved ID with changed contents is rejected before network access', () async {
    await outbox.enqueue(command());
    await expectLater(
      outbox.enqueue(command(version: 2)),
      throwsA(isA<OutboxFailure>()),
    );
    expect(sent, isEmpty);
  });
  test('Known household removal blocks new requests as well as purging the old queue', () async {
    await outbox.enqueue(command());
    await outbox.purgeHousehold('home');
    expect(outbox.rows, isEmpty);
    expect(store.values, isEmpty);
    await expectLater(
      outbox.enqueue(command(id: 'late-tap')),
      throwsA(isA<OutboxFailure>()),
    );
    await outbox.drain();
    expect(sent, isEmpty);
  });
}
