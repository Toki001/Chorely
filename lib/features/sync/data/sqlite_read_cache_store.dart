import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import '../domain/read_cache.dart';

class SqliteReadCacheStore implements ReadCacheStore {
  Future<Database>? _database;
  int _identityEpoch = 0;
  final _householdEpochs = <String, int>{};
  Future<Database> get _db =>
      _database ??= _open().catchError((Object e, StackTrace s) {
        _database = null;
        Error.throwWithStackTrace(e, s);
      });
  Future<Database> _open() async {
    final base = await getDatabasesPath(),
        directory = Directory('$base/chorely_private');
    await directory.create(recursive: true);
    if (Platform.isIOS) {
      await const MethodChannel('chorely/local_store')
          .invokeMethod<void>('prepareStoreDirectory', directory.path);
    }
    return openDatabase(
      '${directory.path}/chorely_cache.db',
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
          'CREATE TABLE reads (uid TEXT NOT NULL, household_id TEXT NOT NULL, cache_key TEXT NOT NULL, payload TEXT NOT NULL, confirmed_ms INTEGER NOT NULL, PRIMARY KEY(uid,household_id,cache_key))',
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
      await db.delete('reads');
    } else {
      await db.delete('reads', where: 'uid != ?', whereArgs: [uid]);
    }
  }

  @override
  Future<SavedRead?> read(String uid, String householdId, String key) async {
    final db = await _db,
        rows = await db.query(
          'reads',
          where: 'uid = ? AND household_id = ? AND cache_key = ?',
          whereArgs: [uid, householdId, key],
        );
    if (rows.isEmpty) return null;
    final row = rows.single,
        at = DateTime.fromMillisecondsSinceEpoch(
          row['confirmed_ms'] as int,
          isUtc: true,
        );
    if (DateTime.now().difference(at) > const Duration(days: 7) ||
        at.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
      await db.delete(
        'reads',
        where: 'uid = ? AND household_id = ? AND cache_key = ?',
        whereArgs: [uid, householdId, key],
      );
      return null;
    }
    return SavedRead(jsonDecode(row['payload'] as String), at);
  }

  @override
  Future<void> write(
    String uid,
    String householdId,
    String key,
    Object? value,
    DateTime confirmedAt,
  ) async {
    final identityEpoch = _identityEpoch, scope = '$uid/$householdId';
    final householdEpoch = _householdEpochs[scope] ?? 0;
    final payload = jsonEncode(value), db = await _db;
    await db.transaction((tx) async {
      if (identityEpoch != _identityEpoch ||
          householdEpoch != (_householdEpochs[scope] ?? 0)) {
        return;
      }
      if (utf8.encode(payload).length > 2000000) {
        await tx.delete(
          'reads',
          where: 'uid = ? AND household_id = ? AND cache_key = ?',
          whereArgs: [uid, householdId, key],
        );
        return;
      }
      await tx.insert('reads', {
        'uid': uid,
        'household_id': householdId,
        'cache_key': key,
        'payload': payload,
        'confirmed_ms': confirmedAt.millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await tx.rawDelete(
        'DELETE FROM reads WHERE uid = ? AND rowid NOT IN (SELECT rowid FROM reads WHERE uid = ? ORDER BY confirmed_ms DESC LIMIT 300)',
        [uid, uid],
      );
    });
  }

  @override
  Future<void> purgeHousehold(String uid, String householdId) async {
    final scope = '$uid/$householdId';
    _householdEpochs[scope] = (_householdEpochs[scope] ?? 0) + 1;
    await (await _db).delete(
      'reads',
      where: 'uid = ? AND household_id = ?',
      whereArgs: [uid, householdId],
    );
  }
}
