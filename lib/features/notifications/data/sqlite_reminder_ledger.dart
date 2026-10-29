import 'package:sqflite/sqflite.dart';

import '../domain/device_reminders.dart';

class SqliteReminderLedger implements ReminderLedger {
  Future<Database>? _database;
  Future<Database> get _db => _database ??= _open();
  Future<Database> _open() async {
    final directory = await getDatabasesPath();
    return openDatabase(
      '$directory/chorely_reminders.db',
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA synchronous = FULL');
      },
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE opt_in (scope TEXT PRIMARY KEY, enabled INTEGER NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE reminders (os_id INTEGER PRIMARY KEY AUTOINCREMENT, logical_id TEXT UNIQUE NOT NULL, at_ms INTEGER NOT NULL, attempted INTEGER NOT NULL, pending INTEGER NOT NULL)',
        );
      },
    );
  }

  @override
  Future<bool> optedIn(String scope) async =>
      (await (await _db).query(
        'opt_in',
        where: 'scope = ?',
        whereArgs: [scope],
      )).firstOrNull?['enabled'] ==
      1;
  @override
  Future<void> optIn(String scope, bool value) async {
    await (await _db).insert('opt_in', {
      'scope': scope,
      'enabled': value ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<({int id, bool attempt})> claim(
    DeviceReminder reminder,
    DateTime now,
  ) async => (await _db).transaction((tx) async {
    final rows = await tx.query(
      'reminders',
      where: 'logical_id = ?',
      whereArgs: [reminder.id],
    );
    final old = rows.firstOrNull;
    final past = !reminder.at.isAfter(now);
    final attempted =
        old != null &&
        (old['attempted'] == 1 ||
            (old['at_ms'] as int) <= now.millisecondsSinceEpoch);
    final fields = {
      'logical_id': reminder.id,
      'at_ms': reminder.at.millisecondsSinceEpoch,
      'attempted': attempted || past ? 1 : 0,
      'pending': 1,
    };
    final id = old == null
        ? await tx.insert('reminders', fields)
        : old['os_id'] as int;
    if (id > 2147483647) throw StateError('Reminder identifier limit');
    if (old != null) {
      await tx.update('reminders', fields, where: 'os_id = ?', whereArgs: [id]);
    }
    return (id: id, attempt: !attempted);
  });
  @override
  Future<Map<String, int>> pending() async => {
    for (final r in await (await _db).query('reminders', where: 'pending = 1'))
      r['logical_id'] as String: r['os_id'] as int,
  };
  @override
  Future<void> cancelled(String id) async {
    await (await _db).update(
      'reminders',
      {'pending': 0},
      where: 'logical_id = ?',
      whereArgs: [id],
    );
  }
}
