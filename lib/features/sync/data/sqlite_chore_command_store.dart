import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'package:sqflite/sqflite.dart';

import '../domain/chore_command_outbox.dart';

class SqliteChoreCommandStore implements ChoreCommandStore {
  Future<Database>? _database;
  int _identityEpoch = 0;
  final _householdEpochs = <String, int>{};
  Future<Database> get _db =>
      _database ??= _open().catchError((Object error, StackTrace stack) {
        _database = null;
        Error.throwWithStackTrace(error, stack);
      });
  Future<Database> _open() async {
    final base = await getDatabasesPath();
    final directory = Directory('$base/chorely_private');
    await directory.create(recursive: true);
    if (Platform.isIOS) {
      await const MethodChannel('chorely/local_store')
          .invokeMethod<void>('prepareStoreDirectory', directory.path);
    }
    return openDatabase(
      '${directory.path}/chorely_sync.db',
      version: 1,
      onConfigure: (db) async {
        await db.rawQuery('PRAGMA journal_mode = DELETE');
        final protection = await db.rawQuery('PRAGMA secure_delete = ON');
        if (protection.isEmpty || protection.first.values.single != 1) {
          throw StateError('Local deletion protection unavailable');
        }
        await db.execute('PRAGMA synchronous = FULL');
      },
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE commands (seq INTEGER PRIMARY KEY AUTOINCREMENT, uid TEXT NOT NULL, id TEXT UNIQUE NOT NULL, household_id TEXT NOT NULL, occurrence_id TEXT NOT NULL, payload TEXT NOT NULL, state TEXT NOT NULL, attempts INTEGER NOT NULL, next_ms INTEGER NOT NULL, message TEXT)',
        );
        await db.execute(
          "CREATE UNIQUE INDEX active_occurrence ON commands(uid,household_id,occurrence_id) WHERE state IN ('pending','conflict','rejected')",
        );
      },
    );
  }

  @override
  Future<void> retainIdentity(String? uid) async {
    _identityEpoch++;
    _householdEpochs.clear();
    final db = await _db;
    if (uid == null) {
      await db.delete('commands');
    } else {
      await db.delete('commands', where: 'uid != ?', whereArgs: [uid]);
    }
  }

  @override
  Future<void> enqueue(ChoreCommand command) async {
    final identityEpoch = _identityEpoch;
    final scope = '${command.uid}/${command.householdId}';
    final householdEpoch = _householdEpochs[scope] ?? 0;
    void checkScope() {
      if (identityEpoch != _identityEpoch ||
          householdEpoch != (_householdEpochs[scope] ?? 0)) {
        throw const OutboxFailure(
          'Your access changed before this request was saved.',
        );
      }
    }

    await (await _db).transaction((tx) async {
      checkScope();
      final same = await tx.query(
        'commands',
        where: 'id = ?',
        whereArgs: [command.id],
      );
      if (same.isNotEmpty) {
        if (same.single['payload'] != command.canonical) {
          throw const OutboxFailure(
            'This saved request has different details. Review its current state first.',
          );
        }
        return;
      }
      final active = await tx.query(
        'commands',
        where: "uid = ? AND household_id = ? AND occurrence_id = ? AND state IN ('pending','conflict','rejected')",
        whereArgs: [command.uid, command.householdId, command.occurrenceId],
        limit: 1,
      );
      if (active.isNotEmpty) {
        throw const OutboxFailure(
          'This chore already has a saved request. Confirm or review it first.',
        );
      }
      final count =
          Sqflite.firstIntValue(
            await tx.rawQuery(
              "SELECT COUNT(*) FROM commands WHERE uid = ? AND state != 'accepted'",
              [command.uid],
            ),
          ) ??
          0;
      if (count >= 100) {
        throw const OutboxFailure(
          'Your device has 100 pending requests. Reconnect to confirm them before adding more.',
        );
      }
      checkScope();
      await tx.insert('commands', {
        'uid': command.uid,
        'id': command.id,
        'household_id': command.householdId,
        'occurrence_id': command.occurrenceId,
        'payload': command.canonical,
        'state': 'pending',
        'attempts': 0,
        'next_ms': DateTime.now().millisecondsSinceEpoch,
      });
      // Accepted receipts need only a short UI fence while the server stream catches up.
      await tx.rawDelete(
        "DELETE FROM commands WHERE state = 'accepted' AND seq NOT IN (SELECT seq FROM commands WHERE state = 'accepted' ORDER BY seq DESC LIMIT 50)",
      );
    });
  }

  @override
  Future<List<StoredChoreCommand>> read(String uid) async =>
      (await (await _db).query(
            'commands',
            where: 'uid = ?',
            whereArgs: [uid],
            orderBy: 'seq ASC',
          ))
          .map(
            (r) => StoredChoreCommand(
              command: ChoreCommand.fromMap(
                Map<String, dynamic>.from(
                  jsonDecode(r['payload'] as String) as Map,
                ),
              ),
              state: r['state'] as String,
              attempts: r['attempts'] as int,
              nextAttempt: DateTime.fromMillisecondsSinceEpoch(
                r['next_ms'] as int,
              ),
              message: r['message'] as String?,
            ),
          )
          .toList();
  @override
  Future<void> update(
    String uid,
    String id, {
    required String state,
    required int attempts,
    required DateTime nextAttempt,
    String? message,
  }) async {
    await (await _db).update(
      'commands',
      {
        'state': state,
        'attempts': attempts,
        'next_ms': nextAttempt.millisecondsSinceEpoch,
        'message': message,
      },
      where: 'uid = ? AND id = ?',
      whereArgs: [uid, id],
    );
  }

  @override
  Future<void> remove(String uid, String id) async {
    await (await _db).delete(
      'commands',
      where: 'uid = ? AND id = ?',
      whereArgs: [uid, id],
    );
  }

  @override
  Future<void> purgeHousehold(String uid, String householdId) async {
    final scope = '$uid/$householdId';
    _householdEpochs[scope] = (_householdEpochs[scope] ?? 0) + 1;
    await (await _db).delete(
      'commands',
      where: 'uid = ? AND household_id = ?',
      whereArgs: [uid, householdId],
    );
  }
}
